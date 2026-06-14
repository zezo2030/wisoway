import { Test, TestingModule } from '@nestjs/testing';
import { getModelToken } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { TripsService } from './trips.service';
import { Trip, TripDocument } from './schemas/trip.schema';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';

describe('TripsService', () => {
  let service: TripsService;
  let tripModel: Model<TripDocument>;

  const mockTripId = '507f1f77bcf86cd799439011';
  const mockDriverId = '507f1f77bcf86cd799439012';

  const mockTrip = {
    _id: mockTripId,
    driverId: mockDriverId,
    driverName: 'Test Driver',
    from: {
      name: 'Cairo',
      latitude: 30.0444,
      longitude: 31.2357,
      address: 'Cairo, Egypt',
    },
    to: {
      name: 'Alexandria',
      latitude: 31.2001,
      longitude: 29.9187,
      address: 'Alexandria, Egypt',
    },
    departureTime: new Date(Date.now() + 24 * 60 * 60 * 1000),
    price: 100,
    currency: 'EGP',
    totalSeats: 4,
    availableSeats: 4,
    seatLayout: {
      rows: 2,
      seatsPerRow: 2,
      preventGenderMixing: false,
    },
    seats: [
      {
        seatNumber: '0-0',
        status: 'available',
        userId: null,
        userName: null,
        gender: null,
      },
      {
        seatNumber: '0-1',
        status: 'available',
        userId: null,
        userName: null,
        gender: null,
      },
      {
        seatNumber: '1-0',
        status: 'available',
        userId: null,
        userName: null,
        gender: null,
      },
      {
        seatNumber: '1-1',
        status: 'available',
        userId: null,
        userName: null,
        gender: null,
      },
    ],
    status: 'active',
    isVisible: true,
    communicationFeeStatus: 'not_paid',
    carImageUrl: null,
    save: jest.fn().mockResolvedValue(true),
  };

  const mockTripModel = {
    create: jest.fn(),
    findById: jest.fn(),
    find: jest.fn(),
    findOneAndUpdate: jest.fn(),
    deleteOne: jest.fn(),
    aggregate: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TripsService,
        {
          provide: getModelToken(Trip.name),
          useValue: mockTripModel,
        },
      ],
    }).compile();

    service = module.get<TripsService>(TripsService);
    tripModel = module.get<Model<TripDocument>>(getModelToken(Trip.name));
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('should create a trip with generated seat layout', async () => {
      const createTripDto: CreateTripDto = {
        from: mockTrip.from,
        to: mockTrip.to,
        departureTime: mockTrip.departureTime.toISOString(),
        price: mockTrip.price,
        currency: 'EGP',
        carImageUrl: null,
      };

      mockTripModel.create.mockResolvedValue(mockTrip);

      const result = await service.create(
        createTripDto,
        mockDriverId,
        'Test Driver',
      );

      expect(result).toBeDefined();
      expect(result.driverId).toBe(mockDriverId);
      expect(result.seats).toHaveLength(4);
      expect(result.availableSeats).toBe(4);
      expect(mockTripModel.create).toHaveBeenCalled();
    });

    it('should fail with past departure time', async () => {
      const createTripDto: CreateTripDto = {
        from: mockTrip.from,
        to: mockTrip.to,
        departureTime: new Date(Date.now() - 1000).toISOString(),
        price: mockTrip.price,
        currency: 'EGP',
        carImageUrl: null,
      };

      await expect(
        service.create(createTripDto, mockDriverId, 'Test Driver'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('findById', () => {
    it('should find a trip by ID', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      const result = await service.findById(mockTripId);

      expect(result).toBeDefined();
      expect(result._id).toBe(mockTripId);
      expect(mockTripModel.findById).toHaveBeenCalledWith(mockTripId);
    });

    it('should throw NotFoundException if trip not found', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(service.findById(mockTripId)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('update', () => {
    it('should update a trip successfully', async () => {
      const updateTripDto: UpdateTripDto = {
        price: 150,
      };

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockTripModel.findOneAndUpdate.mockReturnValue({
        exec: jest.fn().mockResolvedValue({ ...mockTrip, price: 150 }),
      });

      const result = await service.update(
        mockTripId,
        updateTripDto,
        mockDriverId,
      );

      expect(result.price).toBe(150);
    });

    it('should fail if user is not the owner', async () => {
      const otherDriverId = '507f1f77bcf86cd799439013';
      const updateTripDto: UpdateTripDto = { price: 150 };

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      await expect(
        service.update(mockTripId, updateTripDto, otherDriverId),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should fail if trip has bookings and trying to change seats', async () => {
      const updateTripDto: UpdateTripDto = {
        totalSeats: 6,
        seatLayout: { rows: 2, seatsPerRow: 3, preventGenderMixing: false },
      };

      const tripWithBookings = {
        ...mockTrip,
        seats: [
          {
            seatNumber: '0-0',
            status: 'booked',
            userId: '123',
            userName: 'User',
            gender: 'male',
          },
          {
            seatNumber: '0-1',
            status: 'available',
            userId: null,
            userName: null,
            gender: null,
          },
          {
            seatNumber: '1-0',
            status: 'available',
            userId: null,
            userName: null,
            gender: null,
          },
          {
            seatNumber: '1-1',
            status: 'available',
            userId: null,
            userName: null,
            gender: null,
          },
        ],
      };

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(tripWithBookings),
      });

      await expect(
        service.update(mockTripId, updateTripDto, mockDriverId),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('hide', () => {
    it('should hide a trip', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockTripModel.findOneAndUpdate.mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          ...mockTrip,
          status: 'hidden',
          isVisible: false,
        }),
      });

      const result = await service.hide(mockTripId, mockDriverId);

      expect(result.status).toBe('hidden');
      expect(result.isVisible).toBe(false);
    });
  });

  describe('show', () => {
    it('should show a hidden trip', async () => {
      const hiddenTrip = { ...mockTrip, status: 'hidden', isVisible: false };

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(hiddenTrip),
      });

      mockTripModel.findOneAndUpdate.mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          ...mockTrip,
          status: 'active',
          isVisible: true,
        }),
      });

      const result = await service.show(mockTripId, mockDriverId);

      expect(result.status).toBe('active');
      expect(result.isVisible).toBe(true);
    });
  });

  describe('complete', () => {
    it('should complete a trip', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockTripModel.findOneAndUpdate.mockReturnValue({
        exec: jest.fn().mockResolvedValue({ ...mockTrip, status: 'completed' }),
      });

      const result = await service.complete(mockTripId, mockDriverId);

      expect(result.status).toBe('completed');
    });

    it('should fail if trip is already completed', async () => {
      const completedTrip = { ...mockTrip, status: 'completed' };

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(completedTrip),
      });

      await expect(service.complete(mockTripId, mockDriverId)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('cancel', () => {
    it('should cancel a trip', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      mockTripModel.findOneAndUpdate.mockReturnValue({
        exec: jest.fn().mockResolvedValue({ ...mockTrip, status: 'cancelled' }),
      });

      const result = await service.cancel(mockTripId, mockDriverId);

      expect(result.status).toBe('cancelled');
    });

    it('should fail if trip is already completed', async () => {
      const completedTrip = { ...mockTrip, status: 'completed' };

      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(completedTrip),
      });

      await expect(service.cancel(mockTripId, mockDriverId)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('getSeats', () => {
    it('should get trip seats', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      });

      const result = await service.getSeats(mockTripId);

      expect(result).toHaveProperty('seatLayout');
      expect(result).toHaveProperty('seats');
      expect(result.seats).toHaveLength(4);
    });

    it('should throw NotFoundException if trip not found', async () => {
      mockTripModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(service.getSeats(mockTripId)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('search', () => {
    it('should search trips with filters', async () => {
      const mockQuery = {
        skip: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        sort: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([mockTrip]),
      };

      mockTripModel.find.mockReturnValue(mockQuery);

      const result = await service.search({
        fromLatitude: 30.0444,
        fromLongitude: 31.2357,
        minPrice: 50,
        maxPrice: 150,
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta).toHaveProperty('total');
    });
  });

  describe('findByDriver', () => {
    it('should find trips by driver', async () => {
      const mockQuery = {
        skip: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        sort: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue([mockTrip]),
      };

      mockTripModel.find.mockReturnValue(mockQuery);

      const result = await service.findByDriver(mockDriverId, {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(mockTripModel.find).toHaveBeenCalledWith({
        driverId: mockDriverId,
      });
    });
  });

  describe('generateSeatsGrid', () => {
    it('should generate seat layout array', () => {
      const seats = service['generateSeatsGrid'](2, 2);

      expect(seats).toHaveLength(4);
      expect(seats[0].seatNumber).toBe('0-0');
      expect(seats[0].status).toBe('available');
      expect(seats[3].seatNumber).toBe('1-1');
    });
  });
});
