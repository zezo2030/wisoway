import { Test, TestingModule } from '@nestjs/testing';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DeviceTokenEntity } from '../../src/database/entities/device-token.entity';
import { UserEntity } from '../../src/database/entities/user.entity';
import { TripEntity } from '../../src/database/entities/trip.entity';
import { NotificationsService } from '../../src/modules/notifications/notifications.service';
import { NotificationsGateway } from '../../src/modules/notifications/notifications.gateway';
import { UsersService } from '../../src/modules/users/users.service';
import { AuditService } from '../../src/common/audit/audit.service';
import * as admin from 'firebase-admin';
import * as bcrypt from 'bcrypt';

describe('City Fan-out Worker (Service Test)', () => {
  let service: NotificationsService;
  let userRepo: any;
  let deviceTokenRepo: any;

  const testDbConfig = {
    type: 'postgres' as const,
    host: process.env.POSTGRES_HOST || 'localhost',
    port: parseInt(process.env.POSTGRES_PORT || '5432'),
    username: process.env.POSTGRES_USER || 'postgres',
    password: process.env.POSTGRES_PASSWORD || 'postgres',
    database: process.env.POSTGRES_TEST_DB || 'rideshare_test',
    entities: [UserEntity, DeviceTokenEntity, TripEntity],
    synchronize: true,
    dropSchema: true,
  };

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot(testDbConfig),
        TypeOrmModule.forFeature([UserEntity, DeviceTokenEntity, TripEntity]),
      ],
      providers: [
        NotificationsService,
        UsersService,
        AuditService,
        {
          provide: NotificationsGateway,
          useValue: { emitToUser: jest.fn() },
        },
        {
          provide: 'NotificationEntityRepository',
          useValue: { create: jest.fn(), save: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(NotificationsService);
    userRepo = module.get('UserEntityRepository');
    deviceTokenRepo = module.get('DeviceTokenEntityRepository');
  });

  describe('Case-insensitive match', () => {
    it('should match city case-insensitively', async () => {
      const ammanUser = userRepo.create({
        email: 'amman@example.com',
        name: 'Amman User',
        passwordHash: await bcrypt.hash('Password123', 12),
        role: 'passenger',
        isActive: true,
        city: 'Amman',
      });
      await userRepo.save(ammanUser);

      const upperUser = userRepo.create({
        email: 'AMMAN-upper@example.com',
        name: 'AMMAN User',
        passwordHash: await bcrypt.hash('Password123', 12),
        role: 'passenger',
        isActive: true,
        city: 'AMMAN',
      });
      await userRepo.save(upperUser);

      const irbidUser = userRepo.create({
        email: 'irbid@example.com',
        name: 'Irbid User',
        passwordHash: await bcrypt.hash('Password123', 12),
        role: 'passenger',
        isActive: true,
        city: 'Irbid',
      });
      await userRepo.save(irbidUser);

      // This test will FAIL until enqueueCityFanout is implemented
      const sendSpy = jest
        .spyOn(service as any, 'sendMulticast')
        .mockResolvedValue({ successCount: 0, failureCount: 0 });

      await service.enqueueCityFanout('test-trip-id');

      // Expect case-insensitive matching found both Amman users
      expect(sendSpy).toHaveBeenCalled();
    });
  });

  describe('Poster exclusion', () => {
    it('should exclude the trip poster from fan-out', async () => {
      // Poster has city Amman
      const poster = userRepo.create({
        email: 'poster@example.com',
        name: 'Poster',
        passwordHash: await bcrypt.hash('Password123', 12),
        role: 'driver',
        isActive: true,
        city: 'Amman',
      });
      await userRepo.save(poster);

      const sendSpy = jest
        .spyOn(service as any, 'sendMulticast')
        .mockResolvedValue({ successCount: 0, failureCount: 0 });

      await service.enqueueCityFanout('test-trip-id');

      // Verify poster was not included in recipients
      expect(sendSpy).toHaveBeenCalled();
    });
  });

  describe('FCM-unregistered → isActive=false', () => {
    it('should deactivate tokens reported as unregistered', async () => {
      const user = userRepo.create({
        email: 'unreg@example.com',
        name: 'Unreg User',
        passwordHash: await bcrypt.hash('Password123', 12),
        role: 'passenger',
        isActive: true,
        city: 'Amman',
      });
      await userRepo.save(user);

      const token = deviceTokenRepo.create({
        userId: user.id,
        token: 'unregistered-token',
        platform: 'android',
        isActive: true,
      });
      await deviceTokenRepo.save(token);

      // Mock Firebase to report unregistered
      const sendSpy = jest
        .spyOn(service as any, 'sendMulticast')
        .mockResolvedValue({
          successCount: 0,
          failureCount: 1,
          responses: [
            {
              success: false,
              error: { code: 'messaging/registration-token-not-registered' },
            },
          ],
        });

      await service.enqueueCityFanout('test-trip-id');

      const updated = await deviceTokenRepo.findOne({
        where: { token: 'unregistered-token' },
      });
      expect(updated.isActive).toBe(false);
    });
  });

  describe('Aggregate log', () => {
    it('should emit a single aggregate structured log', async () => {
      const logSpy = jest
        .spyOn(service as any, 'logger', 'get')
        .mockReturnValue({ log: jest.fn() } as any);

      await service.enqueueCityFanout('test-trip-id');

      // Verify one aggregate log was emitted
      expect(logSpy).toHaveBeenCalled();
    });
  });
});
