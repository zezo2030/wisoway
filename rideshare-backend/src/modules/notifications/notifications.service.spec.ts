import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { getQueueToken } from '@nestjs/bull';
import {
  NotificationsService,
  notificationSoundFor,
} from './notifications.service';
import { NotificationsGateway } from './notifications.gateway';
import { UsersService } from '../users/users.service';
import { AuditService } from '../../common/audit/audit.service';
import { NotificationEntity } from '../../database/entities/notification.entity';
import { DeviceTokenEntity } from '../../database/entities/device-token.entity';
import { NotificationChannel } from '../../database/entities/shared.enums';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let notificationRepo: {
    create: jest.Mock;
    save: jest.Mock;
    findOne: jest.Mock;
    count: jest.Mock;
    update: jest.Mock;
    remove: jest.Mock;
    createQueryBuilder: jest.Mock;
  };
  let deviceTokenRepo: { find: jest.Mock };
  let gateway: { emitToUser: jest.Mock };
  let qb: Record<string, jest.Mock>;

  const userId = 'user-1';
  const notificationId = 'notif-1';

  const mockNotification = () => ({
    id: notificationId,
    userId,
    type: 'booking_request',
    title: 'New booking',
    body: 'Someone booked your trip',
    isRead: false,
  });

  beforeEach(async () => {
    qb = {
      where: jest.fn(() => qb),
      andWhere: jest.fn(() => qb),
      orderBy: jest.fn(() => qb),
      skip: jest.fn(() => qb),
      take: jest.fn(() => qb),
      getMany: jest.fn().mockResolvedValue([mockNotification()]),
      getCount: jest.fn().mockResolvedValue(1),
    };

    notificationRepo = {
      create: jest.fn((data) => ({ id: notificationId, ...data })),
      save: jest.fn(async (entity) => entity),
      findOne: jest.fn(),
      count: jest.fn().mockResolvedValue(3),
      update: jest.fn().mockResolvedValue({ affected: 5 }),
      remove: jest.fn(async (entity) => entity),
      createQueryBuilder: jest.fn(() => qb),
    };
    deviceTokenRepo = { find: jest.fn().mockResolvedValue([]) };
    gateway = { emitToUser: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        {
          provide: getRepositoryToken(NotificationEntity),
          useValue: notificationRepo,
        },
        {
          provide: getRepositoryToken(DeviceTokenEntity),
          useValue: deviceTokenRepo,
        },
        { provide: UsersService, useValue: { findById: jest.fn() } },
        { provide: NotificationsGateway, useValue: gateway },
        { provide: AuditService, useValue: { record: jest.fn() } },
        { provide: getQueueToken('new-trip-fanout'), useValue: { add: jest.fn() } },
      ],
    }).compile();

    service = module.get<NotificationsService>(NotificationsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('persists the notification on the in-app channel', async () => {
      const dto = {
        userId,
        type: 'booking_request',
        title: 'New booking',
        body: 'Someone booked your trip',
      };

      const result = await service.create(dto as never);

      expect(notificationRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          userId,
          channel: NotificationChannel.IN_APP,
        }),
      );
      expect(notificationRepo.save).toHaveBeenCalledTimes(1);
      expect(result.id).toBe(notificationId);
    });

    it('pushes the saved notification down the socket', async () => {
      const dto = {
        userId,
        type: 'booking_request',
        title: 'New booking',
        body: 'Someone booked your trip',
      };

      await service.create(dto as never);

      expect(gateway.emitToUser).toHaveBeenCalledWith(
        userId,
        'newNotification',
        expect.objectContaining({ id: notificationId }),
      );
    });
  });

  describe('sendPush', () => {
    // Firebase is not configured under test, so the service short-circuits
    // rather than reaching for device tokens.
    it('reports no deliveries when Firebase is unavailable', async () => {
      const result = await service.sendPush(userId, {
        title: 'Hi',
        type: 'generic',
      });

      expect(result).toEqual({ successCount: 0, failureCount: 0 });
    });
  });

  describe('notificationSoundFor', () => {
    it('gives each ride event its own sound', () => {
      expect(notificationSoundFor('instant_matched')).toBe(
        'sound_ride_accepted',
      );
      expect(notificationSoundFor('instant_driver_arrived')).toBe(
        'sound_driver_arrived',
      );
      expect(notificationSoundFor('trip_started')).toBe('sound_ride_started');
      expect(notificationSoundFor('trip_completed')).toBe(
        'sound_ride_completed',
      );
      expect(notificationSoundFor('instant_driver_cancelled')).toBe(
        'sound_ride_cancelled',
      );
      expect(notificationSoundFor('chat_message')).toBe('sound_chat_message');
      expect(notificationSoundFor('wallet_credited')).toBe(
        'sound_payment_success',
      );
      expect(notificationSoundFor('ride_payment_failed')).toBe('sound_error');
    });

    it.each([
      ['driver_approved', 'sound_ride_accepted'],
      ['account_verified', 'sound_ride_accepted'],
      ['account_unbanned', 'sound_ride_accepted'],
      ['presence_prompt', 'sound_driver_arrived'],
      ['presence_driver_prompt', 'sound_driver_arrived'],
      ['presence_passenger_declared', 'sound_driver_arrived'],
      ['trip_awaiting_boarding', 'sound_driver_arrived'],
      ['ride_payment_cash_switch', 'sound_ride_completed'],
      ['refund_resolved', 'sound_payment_success'],
      ['refund_rejected', 'sound_error'],
      ['presence_marked_absent', 'sound_error'],
      ['passenger_reported_driver_absent', 'sound_error'],
    ])('rings %s with %s', (type, sound) => {
      expect(notificationSoundFor(type)).toBe(sound);
    });

    it('falls back to the general sound', () => {
      expect(notificationSoundFor('admin_broadcast')).toBe('sound_general');
    });
  });

  describe('findByUser', () => {
    it('returns a paginated envelope scoped to the user', async () => {
      const result = await service.findByUser(userId, { page: 1, limit: 20 });

      expect(qb.where).toHaveBeenCalledWith('n.userId = :userId', { userId });
      expect(qb.skip).toHaveBeenCalledWith(0);
      expect(qb.take).toHaveBeenCalledWith(20);
      expect(result.data).toHaveLength(1);
      expect(result.meta).toEqual({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
      });
    });

    it('filters by isRead when asked', async () => {
      await service.findByUser(userId, { page: 2, limit: 10, isRead: false });

      expect(qb.andWhere).toHaveBeenCalledWith('n.isRead = :isRead', {
        isRead: false,
      });
      expect(qb.skip).toHaveBeenCalledWith(10);
    });
  });

  describe('getUnreadCount', () => {
    it('counts only the unread rows', async () => {
      await expect(service.getUnreadCount(userId)).resolves.toBe(3);
      expect(notificationRepo.count).toHaveBeenCalledWith({
        where: { userId, isRead: false },
      });
    });
  });

  describe('markRead', () => {
    it('flips isRead for the owner', async () => {
      notificationRepo.findOne.mockResolvedValue(mockNotification());

      const result = await service.markRead(notificationId, userId);

      expect(result.isRead).toBe(true);
      expect(notificationRepo.save).toHaveBeenCalled();
    });

    it('throws when the notification is missing', async () => {
      notificationRepo.findOne.mockResolvedValue(null);

      await expect(service.markRead(notificationId, userId)).rejects.toThrow(
        'Notification not found',
      );
    });

    it('refuses a notification belonging to someone else', async () => {
      notificationRepo.findOne.mockResolvedValue({
        ...mockNotification(),
        userId: 'someone-else',
      });

      await expect(service.markRead(notificationId, userId)).rejects.toThrow(
        'Unauthorized',
      );
    });
  });

  describe('markAllRead', () => {
    it('returns how many rows were touched', async () => {
      await expect(service.markAllRead(userId)).resolves.toBe(5);
      expect(notificationRepo.update).toHaveBeenCalledWith(
        { userId, isRead: false },
        { isRead: true },
      );
    });
  });

  describe('delete', () => {
    it('removes the notification for its owner', async () => {
      const notification = mockNotification();
      notificationRepo.findOne.mockResolvedValue(notification);

      await service.delete(notificationId, userId);

      expect(notificationRepo.remove).toHaveBeenCalledWith(notification);
    });

    it('throws when the notification is missing', async () => {
      notificationRepo.findOne.mockResolvedValue(null);

      await expect(service.delete(notificationId, userId)).rejects.toThrow(
        'Notification not found',
      );
    });

    it('refuses a notification belonging to someone else', async () => {
      notificationRepo.findOne.mockResolvedValue({
        ...mockNotification(),
        userId: 'someone-else',
      });

      await expect(service.delete(notificationId, userId)).rejects.toThrow(
        'Unauthorized',
      );
      expect(notificationRepo.remove).not.toHaveBeenCalled();
    });
  });
});
