import { Test, TestingModule } from '@nestjs/testing';
import { getModelToken } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { NotificationsService } from './notifications.service';
import {
  Notification,
  NotificationDocument,
} from './schemas/notification.schema';
import { NotificationsGateway } from './notifications.gateway';
import { NotFoundException } from '@nestjs/common';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let notificationModel: Model<NotificationDocument>;

  const mockNotification = {
    _id: 'notification-id',
    userId: 'user-id',
    type: 'booking_new',
    title: 'New Booking',
    body: 'A passenger booked seat 0-1',
    data: { tripId: 'trip-id', bookingId: 'booking-id' },
    isRead: false,
    createdAt: new Date(),
    save: jest.fn().mockResolvedValue(this),
  };

  const MockNotificationModel = jest.fn().mockImplementation((dto) => ({
    ...dto,
    _id: 'new-notification-id',
    save: jest.fn().mockResolvedValue({ _id: 'new-notification-id', ...dto }),
  }));

  MockNotificationModel.find = jest.fn().mockReturnThis();
  MockNotificationModel.findOne = jest.fn().mockReturnThis();
  MockNotificationModel.findById = jest.fn().mockReturnThis();
  MockNotificationModel.exec = jest.fn();
  MockNotificationModel.create = jest.fn();
  MockNotificationModel.countDocuments = jest.fn();
  MockNotificationModel.updateOne = jest.fn();
  MockNotificationModel.updateMany = jest.fn();
  MockNotificationModel.populate = jest.fn().mockReturnThis();
  MockNotificationModel.skip = jest.fn().mockReturnThis();
  MockNotificationModel.limit = jest.fn().mockReturnThis();
  MockNotificationModel.sort = jest.fn().mockReturnThis();

  const mockNotificationModel = MockNotificationModel;

  const mockUserModel = {
    findById: jest.fn(),
  };

  const mockNotificationsGateway = {
    emitToUser: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        {
          provide: getModelToken(Notification.name),
          useValue: mockNotificationModel,
        },
        {
          provide: getModelToken('User'),
          useValue: mockUserModel,
        },
        {
          provide: NotificationsGateway,
          useValue: mockNotificationsGateway,
        },
      ],
    }).compile();

    service = module.get<NotificationsService>(NotificationsService);
    notificationModel = module.get<Model<NotificationDocument>>(
      getModelToken(Notification.name),
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('should create a notification', async () => {
      const createNotificationDto = {
        userId: 'user-id',
        type: 'booking_new',
        title: 'New Booking',
        body: 'A passenger booked seat 0-1',
        data: { tripId: 'trip-id' },
      };

      mockNotificationModel.create.mockResolvedValue({
        _id: 'new-notification-id',
        ...createNotificationDto,
        isRead: false,
      });

      const result = await service.create(createNotificationDto);

      expect(result).toBeDefined();
      expect(mockNotificationModel.create).toHaveBeenCalled();
    });
  });

  describe('sendPush', () => {
    it('should send push notification to user with FCM token', async () => {
      const mockUser = {
        _id: 'user-id',
        fcmToken: 'fcm-token',
      };

      mockUserModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockUser),
      });

      await service.sendPush('user-id', {
        title: 'Test Notification',
        body: 'Test body',
        type: 'booking_created',
      });

      expect(mockUserModel.findById).toHaveBeenCalledWith('user-id');
    });

    it('should not fail if user not found', async () => {
      mockUserModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(
        service.sendPush('non-existent', {
          title: 'Test',
          body: 'Test',
          type: 'booking_created',
        }),
      ).resolves.not.toThrow();
    });
  });

  describe('findByUser', () => {
    it('should return paginated notifications', async () => {
      const notifications = [mockNotification];

      mockNotificationModel.find.mockReturnValue({
        skip: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            sort: jest.fn().mockReturnValue({
              exec: jest.fn().mockResolvedValue(notifications),
            }),
          }),
        }),
      });

      mockNotificationModel.countDocuments.mockReturnValue({
        exec: jest.fn().mockResolvedValue(1),
      });

      const result = await service.findByUser('user-id', {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });

    it('should filter by isRead when provided', async () => {
      mockNotificationModel.find.mockReturnValue({
        skip: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            sort: jest.fn().mockReturnValue({
              exec: jest.fn().mockResolvedValue([]),
            }),
          }),
        }),
      });

      mockNotificationModel.countDocuments.mockReturnValue({
        exec: jest.fn().mockResolvedValue(0),
      });

      await service.findByUser('user-id', {
        page: 1,
        limit: 20,
        isRead: true,
      });

      expect(mockNotificationModel.find).toHaveBeenCalledWith({
        userId: 'user-id',
        isRead: true,
      });
    });
  });

  describe('getUnreadCount', () => {
    it('should return unread count', async () => {
      mockNotificationModel.countDocuments.mockReturnValue({
        exec: jest.fn().mockResolvedValue(5),
      });

      const result = await service.getUnreadCount('user-id');

      expect(result).toBe(5);
    });
  });

  describe('markRead', () => {
    it('should mark notification as read', async () => {
      mockNotificationModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          ...mockNotification,
          isRead: false,
          save: jest
            .fn()
            .mockResolvedValue({ ...mockNotification, isRead: true }),
        }),
      });

      const result = await service.markRead('notification-id', 'user-id');

      expect(result.isRead).toBe(true);
    });

    it('should throw NotFoundException if notification not found', async () => {
      mockNotificationModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(service.markRead('non-existent', 'user-id')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('markAllRead', () => {
    it('should mark all user notifications as read', async () => {
      mockNotificationModel.updateMany.mockReturnValue({
        exec: jest.fn().mockResolvedValue({ modifiedCount: 5 }),
      });

      const result = await service.markAllRead('user-id');

      expect(result).toBe(5);
    });
  });

  describe('delete', () => {
    it('should delete notification', async () => {
      mockNotificationModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockNotification),
      });

      mockNotificationModel.deleteOne = jest
        .fn()
        .mockResolvedValue({ deletedCount: 1 });

      await expect(
        service.delete('notification-id', 'user-id'),
      ).resolves.not.toThrow();
    });

    it('should throw NotFoundException if notification not found', async () => {
      mockNotificationModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(service.delete('non-existent', 'user-id')).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
