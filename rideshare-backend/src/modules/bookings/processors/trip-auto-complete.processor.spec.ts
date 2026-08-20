import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { TripEntity } from '../../../database/entities/trip.entity';
import { BookingEntity } from '../../../database/entities/booking.entity';
import { TripStatus } from '../../../database/entities/shared.enums';
import { NotificationsService } from '../../notifications/notifications.service';
import { PresenceService } from '../../trip-time/presence.service';
import { DriverTripFeeService } from '../../driver-trip-fee/driver-trip-fee.service';
import { TripAutoCompleteProcessor } from './trip-auto-complete.processor';

describe('TripAutoCompleteProcessor — fee reconciliation sweep', () => {
  let processor: TripAutoCompleteProcessor;
  let trip: any;
  let driverTripFee: { chargeAtTripStart: jest.Mock };
  let presenceService: { settleTripPresence: jest.Mock };

  beforeEach(async () => {
    trip = {
      id: 'trip-1',
      driverId: 'driver-1',
      status: TripStatus.IN_PROGRESS,
      departureTime: new Date(),
      toName: 'الطفيلة',
      price: 4,
      totalSeats: 4,
      driverWalletChargeApplied: false,
    };
    driverTripFee = {
      chargeAtTripStart: jest.fn().mockResolvedValue({
        tripId: 'trip-1',
        charged: 1.6,
        pendingRemainder: 0,
        currency: 'JOD',
        applied: true,
      }),
    };
    presenceService = {
      settleTripPresence: jest.fn().mockResolvedValue({
        tripId: 'trip-1',
        billableSeats: 2,
        bookedSeats: 2,
        captured: 8,
        released: 0,
        currency: 'JOD',
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TripAutoCompleteProcessor,
        {
          provide: getRepositoryToken(TripEntity),
          useValue: { findOne: async () => trip, save: async (t: any) => t },
        },
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: { find: async () => [], save: async (b: any) => b },
        },
        {
          provide: NotificationsService,
          useValue: { create: jest.fn().mockResolvedValue({}) },
        },
        { provide: PresenceService, useValue: presenceService },
        { provide: DriverTripFeeService, useValue: driverTripFee },
      ],
    }).compile();

    processor = module.get(TripAutoCompleteProcessor);
  });

  it('charges a trip whose start-time debit never landed', async () => {
    trip.driverWalletChargeApplied = false;

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledWith(trip);
  });

  it('does not re-charge a trip already stamped', async () => {
    trip.driverWalletChargeApplied = true;

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
  });

  it('does not sweep a trip the processor bails out on (not IN_PROGRESS)', async () => {
    trip.status = TripStatus.COMPLETED;
    trip.driverWalletChargeApplied = false;

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
  });

  it('still settles presence when the recovered charge throws', async () => {
    trip.driverWalletChargeApplied = false;
    driverTripFee.chargeAtTripStart.mockRejectedValue(new Error('ledger down'));

    await expect(
      processor.handle({ data: { tripId: 'trip-1' } } as any),
    ).resolves.toBeUndefined();

    expect(presenceService.settleTripPresence).toHaveBeenCalledWith('trip-1');
  });

  it('logs a distinguishable recovery message when the sweep charges a trip trip-start missed', async () => {
    trip.driverWalletChargeApplied = false;
    const logSpy = jest.spyOn((processor as any).logger, 'log');

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(logSpy).toHaveBeenCalledWith(
      expect.stringContaining('RECOVERED'),
    );
  });

  it('logs at error level, with the trip id and error, when the sweep charge attempt fails', async () => {
    trip.driverWalletChargeApplied = false;
    driverTripFee.chargeAtTripStart.mockRejectedValue(new Error('ledger down'));
    const errorSpy = jest.spyOn((processor as any).logger, 'error');

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    const call = errorSpy.mock.calls.find((c) =>
      String(c[0]).includes('reconcil'),
    );
    expect(call).toBeDefined();
    expect(String(call?.[0])).toContain('trip-1');
    expect(String(call?.[0])).toContain('ledger down');
  });

  it('does not log a recovery message when the trip was already stamped', async () => {
    trip.driverWalletChargeApplied = true;
    const logSpy = jest.spyOn((processor as any).logger, 'log');

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(logSpy).not.toHaveBeenCalledWith(
      expect.stringContaining('RECOVERED'),
    );
  });
});
