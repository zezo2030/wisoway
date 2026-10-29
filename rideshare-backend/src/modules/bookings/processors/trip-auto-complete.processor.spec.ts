import { RidePaymentsService } from '../../ride-payments/ride-payments.service';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { TripEntity } from '../../../database/entities/trip.entity';
import {
  BookingEntity,
  BookingStatus,
} from '../../../database/entities/booking.entity';
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
  /** Mutable booking store, so status flips are observable in call order. */
  let bookings: any[];

  beforeEach(async () => {
    bookings = [];
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
          provide: RidePaymentsService,
          useValue: { openForTrip: jest.fn().mockResolvedValue(undefined) },
        },
        {
          provide: getRepositoryToken(TripEntity),
          useValue: { findOne: async () => trip, save: async (t: any) => t },
        },
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: {
            find: async ({ where }: any) =>
              bookings.filter(
                (b) =>
                  b.tripId === where.tripId &&
                  (where.status === undefined || b.status === where.status),
              ),
            // find() hands back live references, so the processor's status
            // writes land in `bookings` without save() doing anything.
            save: async (b: any) => b,
          },
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

  it('opens payments and commission after completing boarded bookings', async () => {
    bookings = [
      {
        id: 'b',
        tripId: 'trip-1',
        status: BookingStatus.IN_PROGRESS,
        passengerPresenceConfirmedAt: new Date(),
      },
    ];
    const payments = (processor as any).ridePayments;
    payments.openForTrip.mockImplementation(async () =>
      expect(bookings[0].status).toBe(BookingStatus.COMPLETED),
    );
    await processor.handle({ data: { tripId: 'trip-1' } } as any);
    expect(payments.openForTrip).toHaveBeenCalledWith('trip-1');
    expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
  });
  it('does not open payments for a trip that is not in progress', async () => {
    trip.status = TripStatus.CANCELLED;
    await processor.handle({ data: { tripId: 'trip-1' } } as any);
    expect((processor as any).ridePayments.openForTrip).not.toHaveBeenCalled();
  });
});
