import { Test, TestingModule } from '@nestjs/testing';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DeviceTokenEntity } from '../../src/database/entities/device-token.entity';
import { UserEntity } from '../../src/database/entities/user.entity';
import { BookingEntity } from '../../src/database/entities/booking.entity';
import { TripEntity } from '../../src/database/entities/trip.entity';
import { NotificationsService } from '../../src/modules/notifications/notifications.service';
import { NotificationsGateway } from '../../src/modules/notifications/notifications.gateway';
import { UsersService } from '../../src/modules/users/users.service';
import { AuditService } from '../../src/common/audit/audit.service';
import * as bcrypt from 'bcrypt';

describe('Booking-trigger Notifications (Service Test)', () => {
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
    entities: [UserEntity, DeviceTokenEntity, BookingEntity, TripEntity],
    synchronize: true,
    dropSchema: true,
  };

  let driverId: string;
  let passengerId: string;
  let tripId: string;
  let bookingId: string;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot(testDbConfig),
        TypeOrmModule.forFeature([
          UserEntity,
          DeviceTokenEntity,
          BookingEntity,
          TripEntity,
        ]),
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

    // Seed driver
    const driver = userRepo.create({
      email: 'driver-trigger@example.com',
      name: 'Driver',
      passwordHash: await bcrypt.hash('Password123', 12),
      role: 'driver',
      isActive: true,
    });
    const savedDriver = await userRepo.save(driver);
    driverId = savedDriver.id;

    // Seed passenger
    const passenger = userRepo.create({
      email: 'passenger-trigger@example.com',
      name: 'Passenger',
      passwordHash: await bcrypt.hash('Password123', 12),
      role: 'passenger',
      isActive: true,
    });
    const savedPassenger = await userRepo.save(passenger);
    passengerId = savedPassenger.id;

    // Seed device tokens for both
    await deviceTokenRepo.save([
      deviceTokenRepo.create({
        userId: driverId,
        token: 'driver-device-1',
        platform: 'android',
        isActive: true,
      }),
      deviceTokenRepo.create({
        userId: passengerId,
        token: 'passenger-device-1',
        platform: 'ios',
        isActive: true,
      }),
    ]);
  });

  describe('Driver notified on booking-created', () => {
    it('should send notification to driver when booking is created', async () => {
      const sendSpy = jest
        .spyOn(service as any, 'sendPushToDevices')
        .mockResolvedValue(undefined);

      // This will FAIL until notifyDriverOfNewBooking is implemented
      await service.notifyDriverOfNewBooking('test-booking-id');

      expect(sendSpy).toHaveBeenCalled();
      const callArgs = sendSpy.mock.calls[0];
      expect(callArgs[0]).toContain(driverId);
    });
  });

  describe('Passenger notified on confirm/reject', () => {
    it('should send notification to passenger when booking is confirmed', async () => {
      const sendSpy = jest
        .spyOn(service as any, 'sendPushToDevices')
        .mockResolvedValue(undefined);

      await service.notifyPassengerOfBookingDecision(
        'test-booking-id',
        'confirmed',
      );

      expect(sendSpy).toHaveBeenCalled();
      const callArgs = sendSpy.mock.calls[0];
      expect(callArgs[0]).toContain(passengerId);
    });

    it('should send notification to passenger when booking is rejected', async () => {
      const sendSpy = jest
        .spyOn(service as any, 'sendPushToDevices')
        .mockResolvedValue(undefined);

      await service.notifyPassengerOfBookingDecision(
        'test-booking-id',
        'rejected',
      );

      expect(sendSpy).toHaveBeenCalled();
    });
  });

  describe('Driver notified on passenger-cancel', () => {
    it('should send notification to driver when passenger cancels', async () => {
      const sendSpy = jest
        .spyOn(service as any, 'sendPushToDevices')
        .mockResolvedValue(undefined);

      await service.notifyDriverOfBookingCancellation('test-booking-id');

      expect(sendSpy).toHaveBeenCalled();
      const callArgs = sendSpy.mock.calls[0];
      expect(callArgs[0]).toContain(driverId);
    });
  });

  describe('Dispatch failure does NOT throw into caller', () => {
    it('should swallow Firebase errors and not propagate', async () => {
      jest
        .spyOn(service as any, 'sendPushToDevices')
        .mockRejectedValue(new Error('Firebase down'));

      // Should NOT throw
      await expect(
        service.notifyDriverOfNewBooking('test-booking-id'),
      ).resolves.not.toThrow();
    });
  });
});
