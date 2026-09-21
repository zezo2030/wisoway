/**
 * The five contact gates this branch removed all live in ChatPostgresService,
 * and nothing exercised it: the "inverted contract" specs under test/contract
 * assert on object literals and never touch product code, and the one real chat
 * spec covers ChatService, whose ChatModule is not registered in app.module.
 *
 * This spec is deliberately narrow — it pins the rule the branch exists to
 * enforce: a confirmed booking opens chat even though `hasDriverPaidToContact`
 * is false, which is the state every booking is in until the trip starts.
 */
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ForbiddenException } from '@nestjs/common';
import { ChatPostgresService } from './chat-postgres.service';
import { ChatRoomEntity } from '../../database/entities/chat-room.entity';
import { MessageEntity } from '../../database/entities/message.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';

const TRIP_ID = 'trip-1';
const DRIVER_ID = 'driver-1';
const PASSENGER_ID = 'rider-1';

describe('ChatPostgresService — contact is never gated on payment', () => {
  let service: ChatPostgresService;
  let chatRoomRepo: any;
  let tripRepo: any;
  let bookingRepo: any;

  /** The post-branch reality: the fee is charged at trip start, so every
   *  booking sits at hasDriverPaidToContact === false until then. */
  const unpaidConfirmedBooking = {
    id: 'b-1',
    tripId: TRIP_ID,
    userId: PASSENGER_ID,
    status: 'confirmed',
    hasDriverPaidToContact: false,
  };

  beforeEach(async () => {
    chatRoomRepo = {
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((dto: any) => dto),
      save: jest.fn(async (room: any) => ({ id: 'room-1', ...room })),
    };
    tripRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: TRIP_ID,
        driverId: DRIVER_ID,
        driverWalletChargeApplied: false,
      }),
    };
    bookingRepo = { findOne: jest.fn(), find: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatPostgresService,
        { provide: getRepositoryToken(ChatRoomEntity), useValue: chatRoomRepo },
        { provide: getRepositoryToken(MessageEntity), useValue: {} },
        { provide: getRepositoryToken(TripEntity), useValue: tripRepo },
        { provide: getRepositoryToken(BookingEntity), useValue: bookingRepo },
        { provide: getRepositoryToken(UserEntity), useValue: {} },
        { provide: PaymentsService, useValue: {} },
        { provide: NotificationsService, useValue: { create: jest.fn() } },
      ],
    }).compile();

    service = module.get(ChatPostgresService);
  });

  afterEach(() => jest.clearAllMocks());

  it('opens a passenger room on an unpaid confirmed booking', async () => {
    bookingRepo.findOne.mockResolvedValue(unpaidConfirmedBooking);

    const room = await service.getOrCreateRoom(TRIP_ID, PASSENGER_ID);

    expect(room).toMatchObject({ id: 'room-1', passengerId: PASSENGER_ID });
    expect(chatRoomRepo.save).toHaveBeenCalled();
  });

  it('opens the driver-side room on an unpaid confirmed booking', async () => {
    bookingRepo.findOne.mockResolvedValue(unpaidConfirmedBooking);

    const room = await service.getOrCreateRoomForDriverPassenger(
      TRIP_ID,
      DRIVER_ID,
      PASSENGER_ID,
    );

    expect(room).toMatchObject({ id: 'room-1', passengerId: PASSENGER_ID });
  });

  it('validates trip participation on an unpaid confirmed booking', async () => {
    bookingRepo.findOne.mockResolvedValue(unpaidConfirmedBooking);

    await expect(
      service['validateTripParticipation'](TRIP_ID, PASSENGER_ID),
    ).resolves.toBeUndefined();
  });

  it('lets the driver in without any booking of their own', async () => {
    bookingRepo.findOne.mockResolvedValue(null);

    await expect(
      service['validateTripParticipation'](TRIP_ID, DRIVER_ID),
    ).resolves.toBeUndefined();
  });

  it('still refuses a stranger with no booking on the trip', async () => {
    bookingRepo.findOne.mockResolvedValue(null);

    await expect(
      service['validateTripParticipation'](TRIP_ID, 'stranger'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('only accepts pending or confirmed bookings — the status guard stays', async () => {
    bookingRepo.findOne.mockResolvedValue(unpaidConfirmedBooking);

    await service['validateTripParticipation'](TRIP_ID, PASSENGER_ID);

    const where = bookingRepo.findOne.mock.calls[0][0].where;
    // In(['pending','confirmed']) — a FindOperator, so assert on its values.
    expect(where.status._value).toEqual(['pending', 'confirmed']);
  });
});
