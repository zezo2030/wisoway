import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatRoomEntity } from '../../database/entities/chat-room.entity';
import { MessageEntity } from '../../database/entities/message.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';

@Injectable()
export class ChatPostgresService {
  private readonly logger = new Logger(ChatPostgresService.name);

  constructor(
    @InjectRepository(ChatRoomEntity)
    private chatRoomRepo: Repository<ChatRoomEntity>,
    @InjectRepository(MessageEntity)
    private messageRepo: Repository<MessageEntity>,
    @InjectRepository(TripEntity)
    private tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectRepository(UserEntity)
    private userRepo: Repository<UserEntity>,
    private paymentsService: PaymentsService,
    private notificationsService: NotificationsService,
  ) {}

  async getOrCreateRoom(
    tripId: string,
    userId: string,
  ): Promise<ChatRoomEntity | null> {
    let room = await this.chatRoomRepo.findOne({
      where: { tripId },
      relations: ['trip'],
    });

    if (room) {
      const isParticipant = (room.participants ?? []).some(
        (p: { userId: string }) => p.userId === userId,
      );
      if (!isParticipant) {
        await this.validateTripParticipation(tripId, userId);
        room = await this.addParticipant(room.id, userId);
      }
      return room;
    }

    await this.validateTripParticipation(tripId, userId);

    room = this.chatRoomRepo.create({
      tripId,
      participants: [{ userId, joinedAt: new Date() }],
    });
    room = await this.chatRoomRepo.save(room);
    this.logger.log(`Chat room created: ${room.id} for trip ${tripId}`);
    return room;
  }

  private async validateTripParticipation(
    tripId: string,
    userId: string,
  ): Promise<void> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    const isDriver = trip.driverId === userId;
    if (!isDriver) {
      const booking = await this.bookingRepo.findOne({
        where: { tripId, userId, status: 'confirmed' },
      });
      if (!booking) {
        throw new ForbiddenException(
          'You must have a confirmed booking to access this chat',
        );
      }
      const hasPaidFee =
        booking.hasDriverPaidToContact ??
        (await this.paymentsService.hasUserPaidCommunicationFee(
          booking.id,
          trip.driverId,
        ));
      if (!hasPaidFee) {
        throw new ForbiddenException(
          'Driver has not paid the communication fee to unlock chat',
        );
      }
    }
  }

  async addParticipant(roomId: string, userId: string): Promise<ChatRoomEntity> {
    const room = await this.chatRoomRepo.findOne({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    const participants = (room.participants ?? []) as { userId: string; joinedAt: Date }[];
    const isParticipant = participants.some((p) => p.userId === userId);
    if (!isParticipant) {
      const user = await this.userRepo.findOne({ where: { id: userId } });
      if (!user) {
        throw new NotFoundException('User not found');
      }
      participants.push({ userId, joinedAt: new Date() });
      room.participants = participants;
      await this.chatRoomRepo.save(room);
    }
    return room;
  }

  async sendMessage(
    roomId: string,
    userId: string,
    text: string,
  ): Promise<MessageEntity> {
    const room = await this.chatRoomRepo.findOne({
      where: { id: roomId },
      relations: ['trip'],
    });
    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    const isParticipant = (room.participants ?? []).some(
      (p: { userId: string }) => p.userId === userId,
    );
    if (!isParticipant) {
      throw new ForbiddenException(
        'You are not a participant in this chat room',
      );
    }

    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const message = this.messageRepo.create({
      chatRoomId: roomId,
      senderId: userId,
      senderName: user.name,
      text,
    });
    const saved = await this.messageRepo.save(message);

    room.lastMessage = text.substring(0, 100);
    room.lastMessageTime = saved.createdAt;
    room.lastMessageSenderId = userId;
    await this.chatRoomRepo.save(room);

    const tripId = room.tripId;
    const participants = (room.participants ?? []) as { userId: string }[];
    for (const p of participants) {
      if (p.userId !== userId) {
        await this.notificationsService.create({
          userId: p.userId,
          type: 'chat_message',
          title: 'New Message',
          body: `${user.name}: ${text.substring(0, 50)}${text.length > 50 ? '...' : ''}`,
          data: { chatRoomId: roomId, tripId },
        });
      }
    }

    this.logger.log(`Message sent: ${saved.id} to room ${roomId}`);
    return saved;
  }

  async getMessages(
    roomId: string,
    userId: string,
    query: { page?: number; limit?: number },
  ): Promise<PaginatedResult<MessageEntity>> {
    const { page = 1, limit = 50 } = query;
    const skip = (page - 1) * limit;

    const room = await this.chatRoomRepo.findOne({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    const isParticipant = (room.participants ?? []).some(
      (p: { userId: string }) => p.userId === userId,
    );
    if (!isParticipant) {
      throw new ForbiddenException(
        'You are not a participant in this chat room',
      );
    }

    const [data, total] = await this.messageRepo.findAndCount({
      where: { chatRoomId: roomId },
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    return {
      data: data.reverse(),
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getRoomsByUser(
    userId: string,
    query: { page?: number; limit?: number },
  ): Promise<PaginatedResult<ChatRoomEntity>> {
    const { page = 1, limit = 20 } = query;
    const skip = (page - 1) * limit;

    const qb = this.chatRoomRepo
      .createQueryBuilder('r')
      .leftJoinAndSelect('r.trip', 'trip')
      .where(
        "EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(r.participants, '[]'::jsonb)) elem WHERE elem->>'userId' = :userId)",
        { userId },
      )
      .orderBy('r.lastMessageTime', 'DESC', 'NULLS LAST')
      .addOrderBy('r.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    const [data, total] = await qb.getManyAndCount();

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getRoomById(roomId: string, userId: string): Promise<ChatRoomEntity> {
    const room = await this.chatRoomRepo.findOne({
      where: { id: roomId },
      relations: ['trip'],
    });
    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    const isParticipant = (room.participants ?? []).some(
      (p: { userId: string }) => p.userId === userId,
    );
    if (!isParticipant) {
      throw new ForbiddenException(
        'You are not a participant in this chat room',
      );
    }
    return room;
  }

  /** Get room by ID or by trip ID (create if not exists for trip) */
  async getRoomByIdOrTripId(
    idOrTripId: string,
    userId: string,
  ): Promise<ChatRoomEntity | null> {
    const byRoomId = await this.chatRoomRepo.findOne({
      where: { id: idOrTripId },
      relations: ['trip'],
    });
    if (byRoomId) {
      const isParticipant = (byRoomId.participants ?? []).some(
        (p: { userId: string }) => p.userId === userId,
      );
      if (isParticipant) {
        return byRoomId;
      }
      throw new ForbiddenException(
        'You are not a participant in this chat room',
      );
    }
    return this.getOrCreateRoom(idOrTripId, userId);
  }
}
