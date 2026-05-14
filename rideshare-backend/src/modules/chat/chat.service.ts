import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { ChatRoom, ChatRoomDocument } from './schemas/chat-room.schema';
import { Message, MessageDocument } from './schemas/message.schema';
import { Trip, TripDocument } from '../trips/schemas/trip.schema';
import { Booking, BookingDocument } from '../bookings/schemas/booking.schema';
import { User, UserDocument } from '../users/schemas/user.schema';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SendMessageDto } from './dto/send-message.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    @InjectModel(ChatRoom.name) private chatRoomModel: Model<ChatRoomDocument>,
    @InjectModel(Message.name) private messageModel: Model<MessageDocument>,
    @InjectModel(Trip.name) private tripModel: Model<TripDocument>,
    @InjectModel(Booking.name) private bookingModel: Model<BookingDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private paymentsService: PaymentsService,
    private notificationsService: NotificationsService,
  ) {}

  /**
   * Get or create a chat room for a trip
   */
  async getOrCreateRoom(
    tripId: string,
    userId: string,
  ): Promise<ChatRoomDocument | null> {
    // Check if room already exists
    let room: any = await this.chatRoomModel
      .findOne({ tripId: new Types.ObjectId(tripId) })
      .exec();

    if (room) {
      // Check if user is a participant
      const isParticipant = room.participants.some(
        (p: any) => p.userId.toString() === userId,
      );

      if (!isParticipant) {
        // Check if user is a trip participant (driver or passenger with an
        // active booking after communication is unlocked)
        await this.validateTripParticipation(tripId, userId);

        // Add user to room
        room = await this.addParticipant(room._id.toString(), userId);
      }

      return room;
    }

    // Validate user is a trip participant
    await this.validateTripParticipation(tripId, userId);

    // Create new room
    room = new this.chatRoomModel({
      tripId: new Types.ObjectId(tripId),
      participants: [
        { userId: new Types.ObjectId(userId), joinedAt: new Date() },
      ],
    });

    await room.save();

    this.logger.log(`Chat room created: ${room._id} for trip ${tripId}`);

    return room;
  }

  /**
   * Validate that user is a participant in the trip
   */
  private async validateTripParticipation(
    tripId: string,
    userId: string,
  ): Promise<void> {
    const trip = await this.tripModel.findById(tripId).exec();

    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    // Check if user is the driver
    const isDriver = trip.driverId.toString() === userId;

    if (!isDriver) {
      // Check if user has a pending or confirmed booking.
      const booking = await this.bookingModel
        .findOne({
          tripId: tripId,
          userId: userId,
          status: { $in: ['pending', 'confirmed'] },
        })
        .exec();

      if (!booking) {
        throw new ForbiddenException(
          'You must have a pending or confirmed booking to access this chat',
        );
      }

      // Check if driver has paid communication fee (for passenger to chat)
      const hasPaidFee = await this.paymentsService.hasUserPaidCommunicationFee(
        booking._id.toString(),
        trip.driverId.toString(),
      );

      if (!hasPaidFee && !(trip as any).driverWalletChargeApplied) {
        throw new ForbiddenException(
          'Driver has not paid the communication fee to unlock chat',
        );
      }
    }
  }

  /**
   * Add participant to a chat room
   */
  async addParticipant(roomId: string, userId: string): Promise<any> {
    const room: any = await this.chatRoomModel.findById(roomId).exec();

    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    // Check if already a participant
    const isParticipant = room.participants.some(
      (p) => p.userId.toString() === userId,
    );

    if (!isParticipant) {
      // Get user info
      const user = await this.userModel.findById(userId).exec();
      if (!user) {
        throw new NotFoundException('User not found');
      }

      room.participants.push({
        userId: new Types.ObjectId(userId),
        joinedAt: new Date(),
      });

      await room.save();
    }

    return room;
  }

  /**
   * Send a message to a chat room
   */
  async sendMessage(
    roomId: string,
    userId: string,
    text: string,
  ): Promise<MessageDocument> {
    const room = await this.chatRoomModel.findById(roomId).exec();

    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    // Verify user is a participant
    const isParticipant = room.participants.some(
      (p) => p.userId.toString() === userId,
    );

    if (!isParticipant) {
      throw new ForbiddenException(
        'You are not a participant in this chat room',
      );
    }

    // Get user info for sender name
    const user = await this.userModel.findById(userId).exec();
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Create message
    const message = new this.messageModel({
      chatRoomId: new Types.ObjectId(roomId),
      senderId: new Types.ObjectId(userId),
      senderName: user.name,
      text,
    });

    await message.save();

    // Update room with last message
    room.lastMessage = text.substring(0, 100);
    room.lastMessageTime = (message as any).createdAt || new Date();
    room.lastMessageSenderId = new Types.ObjectId(userId);
    await room.save();

    // Send notifications to other participants
    const tripId = room.tripId.toString();
    for (const participant of room.participants) {
      if (participant.userId.toString() !== userId) {
        await this.notificationsService.create({
          userId: participant.userId.toString(),
          type: 'chat_message',
          title: 'New Message',
          body: `${user.name}: ${text.substring(0, 50)}${text.length > 50 ? '...' : ''}`,
          data: { chatRoomId: roomId, tripId },
        });
      }
    }

    this.logger.log(`Message sent: ${message._id} to room ${roomId}`);

    return message;
  }

  /**
   * Get messages for a chat room (paginated)
   */
  async getMessages(
    roomId: string,
    userId: string,
    query: { page?: number; limit?: number },
  ): Promise<PaginatedResult<MessageDocument>> {
    const { page = 1, limit = 50 } = query;
    const skip = (page - 1) * limit;

    // Verify user is a participant
    const room = await this.chatRoomModel.findById(roomId).exec();

    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    const isParticipant = room.participants.some(
      (p) => p.userId.toString() === userId,
    );

    if (!isParticipant) {
      throw new ForbiddenException(
        'You are not a participant in this chat room',
      );
    }

    const [data, total] = await Promise.all([
      this.messageModel
        .find({ chatRoomId: new Types.ObjectId(roomId) })
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.messageModel
        .countDocuments({ chatRoomId: new Types.ObjectId(roomId) })
        .exec(),
    ]);

    return {
      data: data.reverse(), // Reverse to get oldest first
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get chat rooms for a user
   */
  async getRoomsByUser(
    userId: string,
    query: { page?: number; limit?: number },
  ): Promise<PaginatedResult<ChatRoomDocument>> {
    const { page = 1, limit = 20 } = query;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.chatRoomModel
        .find({ 'participants.userId': new Types.ObjectId(userId) })
        .populate('participants.userId', 'name photoUrl')
        .populate('tripId', 'from to departureTime driverName')
        .skip(skip)
        .limit(limit)
        .sort({ lastMessageTime: -1 })
        .exec(),
      this.chatRoomModel
        .countDocuments({ 'participants.userId': new Types.ObjectId(userId) })
        .exec(),
    ]);

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

  /**
   * Get room by trip ID
   */
  async getRoomByTripId(
    tripId: string,
    userId: string,
  ): Promise<ChatRoomDocument> {
    const room = await this.chatRoomModel
      .findOne({ tripId: new Types.ObjectId(tripId) })
      .exec();

    if (!room) {
      throw new NotFoundException('Chat room not found for this trip');
    }

    // Verify user is a participant
    const isParticipant = room.participants.some(
      (p) => p.userId.toString() === userId,
    );

    if (!isParticipant) {
      throw new ForbiddenException(
        'You are not a participant in this chat room',
      );
    }

    return room;
  }
}
