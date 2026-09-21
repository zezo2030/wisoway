import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { getQueueToken } from '@nestjs/bull';
import { TripEntity } from '../../../database/entities/trip.entity';
import {
  BookingEntity,
  BookingStatus,
} from '../../../database/entities/booking.entity';
import { TripStatus } from '../../../database/entities/shared.enums';
import { NotificationsService } from '../../notifications/notifications.service';
import { DriverTripFeeService } from '../../driver-trip-fee/driver-trip-fee.service';
import { TripAutoStartProcessor } from './trip-auto-start.processor';

describe('TripAutoStartProcessor — fee charging', () => {
  let processor: TripAutoStartProcessor;
  let trip: any;
  let driverTripFee: { chargeAtTripStart: jest.Mock };

  beforeEach(async () => {
    trip = {
      id: 'trip-1',
      driverId: 'driver-1',
      status: TripStatus.PUBLISHED,
      departureTime: new Date(),
      toName: 'الطفيلة',
      price: 4,
      totalSeats: 4,
    };
    driverTripFee = {
      chargeAtTripStart: jest.fn().mockResolvedValue({
        charged: 1.6,
        pendingRemainder: 0,
        applied: true,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TripAutoStartProcessor,
        {
          provide: getRepositoryToken(TripEntity),
          useValue: { findOne: async () => trip, save: async (t: any) => t },
        },
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: { find: async () => [], save: async (b: any) => b },
        },
        {
          provide: getQueueToken('trip-auto-complete'),
          useValue: { add: jest.fn() },
        },
        {
          provide: NotificationsService,
          useValue: { create: jest.fn().mockResolvedValue({}) },
        },
        { provide: DriverTripFeeService, useValue: driverTripFee },
      ],
    }).compile();

    processor = module.get(TripAutoStartProcessor);
  });

  it('charges the fee once the trip has started', async () => {
    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(trip.status).toBe(TripStatus.IN_PROGRESS);
    expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledTimes(1);
    expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledWith(trip);
  });

  it('still starts the trip when the fee charge throws', async () => {
    driverTripFee.chargeAtTripStart.mockRejectedValue(new Error('ledger down'));

    await expect(
      processor.handle({ data: { tripId: 'trip-1' } } as any),
    ).resolves.toBeUndefined();

    expect(trip.status).toBe(TripStatus.IN_PROGRESS);
  });

  it('does not charge a trip that was already in progress', async () => {
    trip.status = TripStatus.IN_PROGRESS;

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
  });

  it('does not charge a cancelled trip', async () => {
    trip.status = TripStatus.CANCELLED;

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
  });
});
