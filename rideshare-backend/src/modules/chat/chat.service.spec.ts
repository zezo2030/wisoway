import { Test, TestingModule } from '@nestjs/testing';
import { getModelToken } from '@nestjs/mongoose';
import { ChatService } from './chat.service';
import { ChatRoom, ChatRoomDocument } from './schemas/chat-room.schema';
import { Message, MessageDocument } from './schemas/message.schema';
import { Trip, TripDocument } from '../trips/schemas/trip.schema';
import { Booking, BookingDocument } from '../bookings/schemas/booking.schema';
import { User, UserDocument } from '../users/schemas/user.schema';
import { PaymentsService } from '../payments/payments.service';
import { ForbiddenException, NotFoundException } from '@nestjs/common';

describe('ChatService', () => {
  let service: ChatService;
  let chatRoomModel: any;
  let messageModel: any;
  let tripModel: any;
  let bookingModel: any;
  let userModel: any;
  let paymentsService: any;

  const validObjectId = '507f1f77bcf86cd799439011';
  const userId = validObjectId;
  const driverId = '507f1f77bcf86cd799439012';
  const tripId = '507f1f77bcf86cd799439013';
  const bookingId = '507f1f77bcf86cd799439014';
  const roomId = '507f1f77bcf86cd799439015';

  const mockChatRoom = {
    _id: roomId,
    tripId: tripId,
    participants: [
      { userId: userId, joinedAt: new Date() },
      { userId: driverId, joinedAt: new Date() },
    ],
    lastMessage: 'Hello',
    lastMessageTime: new Date(),
    lastMessageSenderId: userId,
    save: jest.fn().mockResolvedValue(this),
  };

  const mockMessage = {
    _id: '507f1f77bcf86cd799439020',
    chatRoomId: roomId,
    senderId: userId,
    senderName: 'Test User',
    text: 'Hello',
    createdAt: new Date(),
    save: jest.fn().mockResolvedValue(this),
  };

  const mockTrip = {
    _id: tripId,
    driverId: driverId,
    driverName: 'Driver Name',
    status: 'active',
    from: { name: 'Cairo' },
    to: { name: 'Alex' },
  };

  const mockBooking = {
    _id: bookingId,
    tripId: tripId,
    userId: userId,
    status: 'confirmed',
  };

  const mockUser = {
    _id: userId,
    name: 'Test User',
    photoUrl: null,
  };

  const MockChatRoomModel = jest.fn().mockImplementation((dto) => ({
    ...dto,
    _id: roomId,
    save: jest.fn().mockResolvedValue({ _id: roomId, ...dto }),
  }));

  MockChatRoomModel.find = jest.fn().mockReturnThis();
  MockChatRoomModel.findOne = jest.fn().mockReturnThis();
  MockChatRoomModel.findById = jest.fn().mockReturnThis();
  MockChatRoomModel.exec = jest.fn();
  MockChatRoomModel.populate = jest.fn().mockReturnThis();
  MockChatRoomModel.skip = jest.fn().mockReturnThis();
  MockChatRoomModel.limit = jest.fn().mockReturnThis();
  MockChatRoomModel.sort = jest.fn().mockReturnThis();
  MockChatRoomModel.countDocuments = jest.fn();

  const mockChatRoomModel = MockChatRoomModel;

  const MockMessageModel = jest.fn().mockImplementation((dto) => ({
    ...dto,
    _id: '507f1f77bcf86cd799439021',
    save: jest
      .fn()
      .mockResolvedValue({ _id: '507f1f77bcf86cd799439021', ...dto }),
  }));

  MockMessageModel.find = jest.fn().mockReturnThis();
  MockMessageModel.findOne = jest.fn().mockReturnThis();
  MockMessageModel.findById = jest.fn().mockReturnThis();
  MockMessageModel.exec = jest.fn();
  MockMessageModel.populate = jest.fn().mockReturnThis();
  MockMessageModel.skip = jest.fn().mockReturnThis();
  MockMessageModel.limit = jest.fn().mockReturnThis();
  MockMessageModel.sort = jest.fn().mockReturnThis();
  MockMessageModel.countDocuments = jest.fn();
  MockMessageModel.create = jest.fn();

  const mockMessageModel = MockMessageModel;

  const mockTripModel = {
    find: jest.fn().mockReturnThis(),
    findOne: jest.fn().mockReturnThis(),
    findById: jest.fn().mockReturnThis(),
    exec: jest.fn(),
  };

  const mockBookingModel = {
    find: jest.fn().mockReturnThis(),
    findOne: jest.fn().mockReturnThis(),
    exec: jest.fn(),
  };

  const mockUserModel = {
    find: jest.fn().mockReturnThis(),
    findOne: jest.fn().mockReturnThis(),
    findById: jest.fn().mockReturnThis(),
    exec: jest.fn(),
  };

  const mockPaymentsService = {
    hasUserPaidCommunicationFee: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatService,
        {
          provide: getModelToken(ChatRoom.name),
          useValue: mockChatRoomModel,
        },
        {
          provide: getModelToken(Message.name),
          useValue: mockMessageModel,
        },
        {
          provide: getModelToken(Trip.name),
          useValue: mockTripModel,
        },
        {
          provide: getModelToken(Booking.name),
          useValue: mockBookingModel,
        },
        {
          provide: getModelToken(User.name),
          useValue: mockUserModel,
        },
        {
          provide: PaymentsService,
          useValue: mockPaymentsService,
        },
      ],
    }).compile();

    service = module.get<ChatService>(ChatService);
    chatRoomModel = module.get<any>(getModelToken(ChatRoom.name));
    messageModel = module.get<any>(getModelToken(Message.name));
    tripModel = module.get<any>(getModelToken(Trip.name));
    bookingModel = module.get<any>(getModelToken(Booking.name));
    userModel = module.get<any>(getModelToken(User.name));
    paymentsService = module.get<PaymentsService>(PaymentsService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getOrCreateRoom', () => {
    it('should return existing room for trip', async () => {
      mockChatRoomModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockChatRoom),
      });

      const result = await service.getOrCreateRoom(tripId, userId);

      expect(result._id).toBe(roomId);
    });

    it('should create new room if not exists', async () => {
      mockChatRoomModel.findOne
        .mockReturnValueOnce({
          exec: jest.fn().mockResolvedValue(null),
        })
        .mockReturnValueOnce({
          exec: jest.fn().mockResolvedValue(null),
        });

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockBookingModel.find.mockReturnValue({
        exec: jest.fn().mockResolvedValue([]),
      });

      await expect(
        service.getOrCreateRoom(tripId, '507f1f77bcf86cd799439099'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw ForbiddenException if user not a trip participant', async () => {
      mockChatRoomModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockBookingModel.find.mockReturnValue({
        exec: jest.fn().mockResolvedValue([]),
      });

      await expect(
        service.getOrCreateRoom(tripId, '507f1f77bcf86cd799439099'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw ForbiddenException if communication fee not paid', async () => {
      mockChatRoomModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockBookingModel.find.mockReturnValue({
        exec: jest.fn().mockResolvedValue([mockBooking]),
      });

      mockPaymentsService.hasUserPaidCommunicationFee.mockResolvedValue(false);

      await expect(service.getOrCreateRoom(tripId, userId)).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('addParticipant', () => {
    it('should add participant to room', async () => {
      const roomWithParticipant = {
        ...mockChatRoom,
        participants: [{ userId: driverId, joinedAt: new Date() }],
        save: jest.fn().mockResolvedValue(true),
      };

      mockChatRoomModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(roomWithParticipant),
      });

      mockUserModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockUser),
      });

      const result = await service.addParticipant(roomId, userId);

      expect(result.participants.length).toBe(2);
    });
  });

  describe('sendMessage', () => {
    it('should send message and update room', async () => {
      const roomForMessage = {
        ...mockChatRoom,
        participants: [
          { userId: userId, joinedAt: new Date() },
          { userId: driverId, joinedAt: new Date() },
        ],
        save: jest.fn().mockResolvedValue(true),
      };

      mockChatRoomModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(roomForMessage),
      });

      mockUserModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockUser),
      });

      mockMessageModel.create.mockResolvedValue(mockMessage);

      const result = await service.sendMessage(roomId, userId, 'Hello');

      expect(result.text).toBe('Hello');
      expect(roomForMessage.save).toHaveBeenCalled();
    });

    it('should throw NotFoundException if room not found', async () => {
      mockChatRoomModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(
        service.sendMessage(roomId, userId, 'Hello'),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('getMessages', () => {
    it('should return paginated messages', async () => {
      const messages = [mockMessage];

      mockChatRoomModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockChatRoom),
      });

      mockMessageModel.find.mockReturnValue({
        skip: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            sort: jest.fn().mockReturnValue({
              exec: jest.fn().mockResolvedValue(messages),
            }),
          }),
        }),
      });

      mockMessageModel.countDocuments.mockReturnValue({
        exec: jest.fn().mockResolvedValue(1),
      });

      const result = await service.getMessages(roomId, userId, {
        page: 1,
        limit: 50,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });
  });

  describe('getRoomsByUser', () => {
    it('should return paginated user rooms', async () => {
      const rooms = [mockChatRoom];

      mockChatRoomModel.find.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          populate: jest.fn().mockReturnValue({
            skip: jest.fn().mockReturnValue({
              limit: jest.fn().mockReturnValue({
                sort: jest.fn().mockReturnValue({
                  exec: jest.fn().mockResolvedValue(rooms),
                }),
              }),
            }),
          }),
        }),
      });

      mockChatRoomModel.countDocuments.mockReturnValue({
        exec: jest.fn().mockResolvedValue(1),
      });

      const result = await service.getRoomsByUser(userId, {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });
  });
});
