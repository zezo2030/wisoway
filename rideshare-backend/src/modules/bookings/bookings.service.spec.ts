import { Test, TestingModule } from '@nestjs/testing';
import { getModelToken } from '@nestjs/mongoose';
import { Model, Connection } from 'mongoose';
import { BookingsService } from './bookings.service';
import { Booking, BookingDocument } from './schemas/booking.schema';
import { Trip, TripDocument } from '../trips/schemas/trip.schema';
import { User, UserDocument } from '../users/schemas/user.schema';
import { TripsGateway } from '../trips/trips.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';

describe('BookingsService', () => {
  let service: BookingsService;
  let bookingModel: Model<BookingDocument>;
  let tripModel: Model<TripDocument>;
  let userModel: Model<UserDocument>;
  let tripsGateway: TripsGateway;

  const mockBooking = {
    _id: 'booking-id',
    tripId: 'trip-id',
    userId: 'user-id',
    seatNumber: '0-0',
    status: 'pending',
    hasDriverPaidToContact: false,
    sharePhoneWithDriver: false,
    save: jest.fn().mockResolvedValue(this),
  };

  const mockTrip = {
    _id: 'trip-id',
    driverId: 'driver-id',
    driverName: 'Driver Name',
    from: { name: 'Cairo', latitude: 30.0, longitude: 31.0 },
    to: { name: 'Alex', latitude: 31.0, longitude: 29.0 },
    departureTime: new Date(Date.now() + 86400000),
    price: 100,
    currency: 'EGP',
    totalSeats: 4,
    availableSeats: 3,
    seatLayout: {
      rows: 2,
      seatsPerRow: 2,
      preventGenderMixing: false,
    },
    seats: [
      { seatNumber: '0-0', status: 'available', userId: null, gender: null },
      {
        seatNumber: '0-1',
        status: 'booked',
        userId: 'other-user',
        gender: 'female',
      },
      { seatNumber: '1-0', status: 'available', userId: null, gender: null },
      { seatNumber: '1-1', status: 'available', userId: null, gender: null },
    ],
    status: 'active',
    save: jest.fn().mockResolvedValue(this),
  };

  const mockUser = {
    _id: 'user-id',
    email: 'user@example.com',
    name: 'Test User',
    gender: 'male',
    role: 'passenger',
  };

  const mockDriver = {
    _id: 'driver-id',
    email: 'driver@example.com',
    name: 'Driver User',
    gender: 'male',
    role: 'driver',
  };

  // Create a mock constructor function
  const MockBookingModel = jest.fn().mockImplementation((dto) => ({
    ...dto,
    _id: 'new-booking-id',
    save: jest.fn().mockResolvedValue({ _id: 'new-booking-id', ...dto }),
  }));

  // Add static methods to the mock
  MockBookingModel.find = jest.fn().mockReturnThis();
  MockBookingModel.findOne = jest.fn().mockReturnThis();
  MockBookingModel.findById = jest.fn().mockReturnThis();
  MockBookingModel.exec = jest.fn();
  MockBookingModel.updateMany = jest.fn().mockReturnValue({
    exec: jest.fn().mockResolvedValue({ modifiedCount: 1 }),
  });
  MockBookingModel.countDocuments = jest.fn();
  MockBookingModel.populate = jest.fn().mockReturnThis();
  MockBookingModel.skip = jest.fn().mockReturnThis();
  MockBookingModel.limit = jest.fn().mockReturnThis();
  MockBookingModel.sort = jest.fn().mockReturnThis();

  const mockBookingModel = MockBookingModel;

  const mockTripModel = {
    find: jest.fn().mockReturnThis(),
    findOne: jest.fn().mockReturnThis(),
    findById: jest.fn().mockReturnThis(),
    exec: jest.fn(),
    save: jest.fn(),
    db: {
      startSession: jest.fn().mockReturnValue({
        startTransaction: jest.fn(),
        commitTransaction: jest.fn(),
        abortTransaction: jest.fn(),
        endSession: jest.fn(),
      }),
    },
  };

  const mockUserModel = {
    find: jest.fn().mockReturnThis(),
    findOne: jest.fn().mockReturnThis(),
    findById: jest.fn().mockReturnThis(),
    exec: jest.fn(),
  };

  const mockTripsGateway = {
    emitSeatBooked: jest.fn().mockResolvedValue(undefined),
    emitSeatReleased: jest.fn().mockResolvedValue(undefined),
    emitTripUpdated: jest.fn().mockResolvedValue(undefined),
  };

  const mockNotificationsService = {
    create: jest.fn().mockResolvedValue(undefined),
  };

  const mockPaymentsService = {
    chargeDriverWalletForTrip: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        {
          provide: getModelToken(Booking.name),
          useValue: mockBookingModel,
        },
        {
          provide: getModelToken(Trip.name),
          useValue: mockTripModel,
        },
        {
          provide: getModelToken(User.name),
          useValue: mockUserModel,
        },
        {
          provide: TripsGateway,
          useValue: mockTripsGateway,
        },
        {
          provide: NotificationsService,
          useValue: mockNotificationsService,
        },
        {
          provide: PaymentsService,
          useValue: mockPaymentsService,
        },
      ],
    }).compile();

    service = module.get<BookingsService>(BookingsService);
    bookingModel = module.get<Model<BookingDocument>>(
      getModelToken(Booking.name),
    );
    tripModel = module.get<Model<TripDocument>>(getModelToken(Trip.name));
    userModel = module.get<Model<UserDocument>>(getModelToken(User.name));
    tripsGateway = module.get<TripsGateway>(TripsGateway);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('should create a booking successfully', async () => {
      const createBookingDto = {
        tripId: 'trip-id',
        seatNumber: '0-0',
      };

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          ...mockTrip,
          seats: mockTrip.seats.map((s) => ({ ...s })),
          save: jest.fn().mockResolvedValue(true),
        }),
      });

      mockUserModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockUser),
      });

      mockBookingModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      const result = await service.create(createBookingDto, 'user-id');

      expect(mockTripsGateway.emitSeatBooked).toHaveBeenCalled();
    });

    it('should throw NotFoundException if trip not found', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(
        service.create(
          { tripId: 'non-existent', seatNumber: '0-0' },
          'user-id',
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException if booking own trip', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          ...mockTrip,
          driverId: 'user-id',
        }),
      });

      await expect(
        service.create({ tripId: 'trip-id', seatNumber: '0-0' }, 'user-id'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if user already has booking for trip', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockBookingModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockBooking),
      });

      await expect(
        service.create({ tripId: 'trip-id', seatNumber: '1-0' }, 'user-id'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if seat not available', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockBookingModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(
        service.create({ tripId: 'trip-id', seatNumber: '0-1' }, 'user-id'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException for invalid seat number', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockBookingModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(
        service.create({ tripId: 'trip-id', seatNumber: '99-99' }, 'user-id'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException for gender mismatch when preventGenderMixing is true', async () => {
      const genderRestrictedTrip = {
        ...mockTrip,
        seatLayout: {
          ...mockTrip.seatLayout,
          preventGenderMixing: true,
        },
        seats: [
          {
            seatNumber: '0-0',
            status: 'booked',
            userId: 'other',
            gender: 'female',
          },
          {
            seatNumber: '0-1',
            status: 'available',
            userId: null,
            gender: null,
          },
        ],
      };

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(genderRestrictedTrip),
      });

      mockBookingModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      mockUserModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockUser), // male user
      });

      // Try to book seat 0-1 which is in same row as female passenger
      await expect(
        service.create({ tripId: 'trip-id', seatNumber: '0-1' }, 'user-id'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('confirm', () => {
    it('should confirm a booking as driver and call wallet charge', async () => {
      const confirmedBooking = {
        ...mockBooking,
        status: 'pending',
        hasDriverPaidToContact: false,
        tripId: { _id: 'trip-id', driverId: 'driver-id' },
        save: jest.fn().mockResolvedValue({
          ...mockBooking,
          status: 'confirmed',
          hasDriverPaidToContact: true,
        }),
      };

      mockBookingModel.findById.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          exec: jest.fn().mockResolvedValue(confirmedBooking),
        }),
      });

      const result = await service.confirm('booking-id', 'driver-id');

      expect(
        mockPaymentsService.chargeDriverWalletForTrip,
      ).toHaveBeenCalledWith('driver-id', 'trip-id');
      expect(result.status).toBe('confirmed');
    });

    it('should throw ForbiddenException if not trip driver', async () => {
      mockBookingModel.findById.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          exec: jest.fn().mockResolvedValue({
            ...mockBooking,
            tripId: { driverId: 'driver-id' },
          }),
        }),
      });

      await expect(
        service.confirm('booking-id', 'other-driver'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException if booking not pending', async () => {
      mockBookingModel.findById.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          exec: jest.fn().mockResolvedValue({
            ...mockBooking,
            status: 'confirmed',
            tripId: { driverId: 'driver-id' },
          }),
        }),
      });

      await expect(service.confirm('booking-id', 'driver-id')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('cancel', () => {
    it('should cancel booking as passenger', async () => {
      const tripWithSeat = {
        ...mockTrip,
        _id: 'trip-id',
        seats: [
          {
            seatNumber: '0-0',
            status: 'booked',
            userId: 'user-id',
            gender: 'male',
          },
          {
            seatNumber: '0-1',
            status: 'available',
            userId: null,
            gender: null,
          },
        ],
        save: jest.fn().mockResolvedValue(true),
      };

      const bookingToCancel = {
        ...mockBooking,
        status: 'pending',
        seatNumber: '0-0',
        tripId: tripWithSeat,
        save: jest.fn().mockResolvedValue({
          ...mockBooking,
          status: 'cancelled',
          cancelledBy: 'passenger',
        }),
      };

      mockBookingModel.findById.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          exec: jest.fn().mockResolvedValue(bookingToCancel),
        }),
      });

      mockTripModel.findById.mockReturnValue({
        session: jest.fn().mockReturnValue({
          exec: jest.fn().mockResolvedValue(tripWithSeat),
        }),
      });

      const result = await service.cancel(
        'booking-id',
        'user-id',
        { reason: 'Test cancellation' },
        false,
      );

      expect(mockTripsGateway.emitSeatReleased).toHaveBeenCalled();
    });

    it('should throw ForbiddenException if not authorized', async () => {
      mockBookingModel.findById.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          exec: jest.fn().mockResolvedValue({
            ...mockBooking,
            userId: 'other-user',
            tripId: { driverId: 'driver-id' },
          }),
        }),
      });

      await expect(
        service.cancel(
          'booking-id',
          'unauthorized-user',
          { reason: 'test' },
          false,
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException if already cancelled', async () => {
      mockBookingModel.findById.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          exec: jest.fn().mockResolvedValue({
            ...mockBooking,
            status: 'cancelled',
            tripId: { driverId: 'driver-id' },
          }),
        }),
      });

      await expect(
        service.cancel('booking-id', 'user-id', { reason: 'test' }, false),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('findByUser', () => {
    it('should return paginated user bookings', async () => {
      const bookings = [mockBooking];

      mockBookingModel.find.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          skip: jest.fn().mockReturnValue({
            limit: jest.fn().mockReturnValue({
              sort: jest.fn().mockReturnValue({
                exec: jest.fn().mockResolvedValue(bookings),
              }),
            }),
          }),
        }),
      });

      mockBookingModel.countDocuments.mockReturnValue({
        exec: jest.fn().mockResolvedValue(1),
      });

      const result = await service.findByUser('user-id', {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });

    it('should filter by status when provided', async () => {
      mockBookingModel.find.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          skip: jest.fn().mockReturnValue({
            limit: jest.fn().mockReturnValue({
              sort: jest.fn().mockReturnValue({
                exec: jest.fn().mockResolvedValue([]),
              }),
            }),
          }),
        }),
      });

      mockBookingModel.countDocuments.mockReturnValue({
        exec: jest.fn().mockResolvedValue(0),
      });

      await service.findByUser('user-id', {
        page: 1,
        limit: 20,
        status: 'pending',
      });

      expect(mockBookingModel.find).toHaveBeenCalledWith({
        userId: 'user-id',
        status: 'pending',
      });
    });
  });

  describe('findByTrip', () => {
    it('should return paginated trip bookings for driver', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockBookingModel.find.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          skip: jest.fn().mockReturnValue({
            limit: jest.fn().mockReturnValue({
              sort: jest.fn().mockReturnValue({
                exec: jest.fn().mockResolvedValue([mockBooking]),
              }),
            }),
          }),
        }),
      });

      mockBookingModel.countDocuments.mockReturnValue({
        exec: jest.fn().mockResolvedValue(1),
      });

      const result = await service.findByTrip('trip-id', 'driver-id', {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
    });

    it('should throw ForbiddenException if not trip owner', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      await expect(
        service.findByTrip('trip-id', 'other-driver', { page: 1, limit: 20 }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('findById', () => {
    it('should return booking for booking owner', async () => {
      mockBookingModel.findById.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          populate: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue({
              ...mockBooking,
              userId: { _id: 'user-id' },
              tripId: { driverId: 'driver-id' },
            }),
          }),
        }),
      });

      const result = await service.findById('booking-id', 'user-id');

      expect(result).toBeDefined();
    });

    it('should return booking for trip driver', async () => {
      mockBookingModel.findById.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          populate: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue({
              ...mockBooking,
              userId: { _id: 'other-user' },
              tripId: { driverId: 'driver-id' },
            }),
          }),
        }),
      });

      const result = await service.findById('booking-id', 'driver-id');

      expect(result).toBeDefined();
    });

    it('should throw ForbiddenException for unauthorized user', async () => {
      mockBookingModel.findById.mockReturnValue({
        populate: jest.fn().mockReturnValue({
          populate: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue({
              ...mockBooking,
              userId: { _id: 'user-id' },
              tripId: { driverId: 'driver-id' },
            }),
          }),
        }),
      });

      await expect(
        service.findById('booking-id', 'unauthorized-user'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('markAsCompleted', () => {
    it('should update all confirmed bookings to completed', async () => {
      mockBookingModel.updateMany.mockReturnValue({
        exec: jest.fn().mockResolvedValue({ modifiedCount: 2 }),
      });

      await service.markAsCompleted('trip-id');

      expect(mockBookingModel.updateMany).toHaveBeenCalledWith(
        { tripId: 'trip-id', status: 'confirmed' },
        { status: 'completed' },
      );
    });
  });

  describe('cancelAllForTrip', () => {
    it('should cancel all non-cancelled bookings for a trip', async () => {
      const bookings = [
        { ...mockBooking, status: 'pending', save: jest.fn() },
        { ...mockBooking, status: 'confirmed', save: jest.fn() },
      ];

      mockBookingModel.find.mockReturnValue({
        exec: jest.fn().mockResolvedValue(bookings),
      });

      await service.cancelAllForTrip('trip-id', 'Trip cancelled by driver');

      expect(mockBookingModel.find).toHaveBeenCalledWith({
        tripId: 'trip-id',
        status: { $ne: 'cancelled' },
      });
    });
  });
});
