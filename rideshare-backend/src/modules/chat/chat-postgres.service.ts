import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
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

  /** Get or create 1:1 room between driver and passenger for a trip */
  async getOrCreateRoomForDriverPassenger(
    tripId: string,
    driverId: string,
    passengerId: string,
  ): Promise<ChatRoomEntity> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('You are not the driver of this trip');
    }
    const booking = await this.bookingRepo.findOne({
      where: { tripId, userId: passengerId, status: 'confirmed' },
    });
    if (!booking) {
      throw new ForbiddenException(
        'Passenger must have a confirmed booking for this trip',
      );
    }
    // Phase 7 (US5): chat is gated on settlement — booking must be marked paid.
    if (!booking.settledAt) {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'BOOKING_NOT_SETTLED',
        message:
          'Chat is only available after the driver marks the booking as paid',
      });
    }

    let room = await this.chatRoomRepo.findOne({
      where: { tripId, passengerId },
      relations: ['trip'],
    });
    if (room) return room;

    room = this.chatRoomRepo.create({
      tripId,
      passengerId,
      participants: [
        { userId: driverId, joinedAt: new Date() },
        { userId: passengerId, joinedAt: new Date() },
      ],
    });
    room = await this.chatRoomRepo.save(room);
    this.logger.log(
      `1:1 Chat room created: ${room.id} for trip ${tripId}, passenger ${passengerId}`,
    );
    return room;
  }

  /** Get or create room - for passenger: 1:1 with driver. For backward compat. */
  async getOrCreateRoom(
    tripId: string,
    userId: string,
  ): Promise<ChatRoomEntity | null> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');

    const isDriver = trip.driverId === userId;
    if (isDriver) {
      throw new BadRequestException(
        'Driver must use trip+passenger endpoint to open 1:1 chat',
      );
    }

    await this.validateTripParticipation(tripId, userId);

    let room = await this.chatRoomRepo.findOne({
      where: { tripId, passengerId: userId },
      relations: ['trip'],
    });
    if (room) return room;

    room = this.chatRoomRepo.create({
      tripId,
      passengerId: userId,
      participants: [
        { userId: trip.driverId, joinedAt: new Date() },
        { userId, joinedAt: new Date() },
      ],
    });
    room = await this.chatRoomRepo.save(room);
    this.logger.log(
      `1:1 Chat room created: ${room.id} for trip ${tripId}, passenger ${userId}`,
    );
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
      // Phase 7 (US5): settlement gate — booking must be marked paid.
      if (!booking.settledAt) {
        throw new ForbiddenException({
          statusCode: 403,
          code: 'BOOKING_NOT_SETTLED',
          message:
            'Chat is only available after the driver marks the booking as paid',
        });
      }
    }
  }

  async addParticipant(
    roomId: string,
    userId: string,
  ): Promise<ChatRoomEntity> {
    const room = await this.chatRoomRepo.findOne({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    const participants = (room.participants ?? []) as {
      userId: string;
      joinedAt: Date;
    }[];
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

    // Phase 7 (US5): settlement gate — reject messages on unsettled rooms.
    if (room.passengerId) {
      const booking = await this.bookingRepo.findOne({
        where: {
          tripId: room.tripId,
          userId: room.passengerId,
          status: 'confirmed',
        },
      });
      if (booking && !booking.settledAt) {
        throw new ForbiddenException({
          statusCode: 403,
          code: 'BOOKING_NOT_SETTLED',
          message:
            'Chat is only available after the driver marks the booking as paid',
        });
      }
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

  /** Get room by ID or by trip ID (for passenger: 1:1 room with driver) */
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
