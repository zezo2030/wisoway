import { Test, TestingModule } from '@nestjs/testing';
import { Model } from 'mongoose';
import { AdminService } from './admin.service';
import { User, UserDocument, UserRole } from '../users/schemas/user.schema';
import { Trip, TripDocument } from '../trips/schemas/trip.schema';
import { Payment, PaymentDocument } from '../payments/schemas/payment.schema';
import { Vehicle, VehicleDocument } from '../vehicles/schemas/vehicle.schema';
import { Booking, BookingDocument } from '../bookings/schemas/booking.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { NotFoundException, BadRequestException } from '@nestjs/common';

describe('AdminService', () => {
  let service: AdminService;
  let userModel: Model<UserDocument>;
  let tripModel: Model<TripDocument>;
  let paymentModel: Model<PaymentDocument>;
  let vehicleModel: Model<VehicleDocument>;
  let bookingModel: Model<BookingDocument>;
  let notificationsService: NotificationsService;

  const mockUser = {
    _id: 'user-id-1',
    name: 'Test User',
    email: 'test@example.com',
    phoneNumber: '+201234567890',
    role: UserRole.PASSENGER,
    gender: 'male',
    isActive: true,
    rating: 4.5,
    totalRatings: 10,
    save: jest.fn().mockResolvedValue(this),
    toObject: jest.fn().mockReturnValue({
      _id: 'user-id-1',
      name: 'Test User',
      email: 'test@example.com',
    }),
  };

  const mockTrip = {
    _id: 'trip-id-1',
    driverId: 'driver-id-1',
    driverName: 'Test Driver',
    from: { name: 'Location A', latitude: 30.0, longitude: 31.0 },
    to: { name: 'Location B', latitude: 31.0, longitude: 32.0 },
    departureTime: new Date(),
    price: 100,
    currency: 'EGP',
    totalSeats: 4,
    availableSeats: 2,
    status: 'active',
    save: jest.fn().mockResolvedValue(this),
  };

  const mockPayment = {
    _id: 'payment-id-1',
    userId: 'user-id-1',
    tripId: 'trip-id-1',
    bookingId: 'booking-id-1',
    amount: 100,
    currency: 'EGP',
    method: 'manual',
    status: 'pending',
    paymentType: 'trip',
    proofImageUrl: 'https://s3.example.com/proof.jpg',
    save: jest.fn().mockResolvedValue(this),
  };

  const mockVehicle = {
    _id: 'vehicle-id-1',
    driverId: 'driver-id-1',
    vehicleType: 'sedan',
    plateNumber: 'ABC-123',
    model: 'Toyota Camry',
    seats: 4,
    isVerified: false,
    save: jest.fn().mockResolvedValue(this),
  };

  const mockBooking = {
    _id: 'booking-id-1',
    tripId: 'trip-id-1',
    userId: 'user-id-1',
    seatNumber: '0-0',
    status: 'pending',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminService,
        {
          provide: 'UserModel',
          useValue: {
            find: jest.fn().mockReturnValue({
              skip: jest.fn().mockReturnValue({
                limit: jest.fn().mockReturnValue({
                  sort: jest.fn().mockReturnValue({
                    exec: jest.fn().mockResolvedValue([mockUser]),
                  }),
                }),
              }),
            }),
            findById: jest.fn().mockResolvedValue(mockUser),
            findByIdAndUpdate: jest.fn().mockResolvedValue(mockUser),
            countDocuments: jest.fn().mockResolvedValue(1),
            aggregate: jest.fn().mockResolvedValue([
              { _id: 'passenger', count: 100 },
              { _id: 'driver', count: 20 },
              { _id: 'admin', count: 2 },
            ]),
          },
        },
        {
          provide: 'TripModel',
          useValue: {
            find: jest.fn().mockReturnValue({
              skip: jest.fn().mockReturnValue({
                limit: jest.fn().mockReturnValue({
                  sort: jest.fn().mockReturnValue({
                    exec: jest.fn().mockResolvedValue([mockTrip]),
                  }),
                }),
              }),
            }),
            findById: jest.fn().mockResolvedValue(mockTrip),
            countDocuments: jest.fn().mockResolvedValue(1),
            aggregate: jest.fn().mockResolvedValue([
              { _id: 'active', count: 45 },
              { _id: 'completed', count: 890 },
            ]),
          },
        },
        {
          provide: 'PaymentModel',
          useValue: {
            find: jest.fn().mockReturnValue({
              skip: jest.fn().mockReturnValue({
                limit: jest.fn().mockReturnValue({
                  sort: jest.fn().mockReturnValue({
                    populate: jest.fn().mockReturnValue({
                      exec: jest.fn().mockResolvedValue([mockPayment]),
                    }),
                  }),
                }),
              }),
            }),
            findById: jest.fn().mockResolvedValue(mockPayment),
            countDocuments: jest.fn().mockResolvedValue(1),
            aggregate: jest.fn().mockResolvedValue([{ total: 125000 }]),
          },
        },
        {
          provide: 'VehicleModel',
          useValue: {
            find: jest.fn().mockReturnValue({
              exec: jest.fn().mockResolvedValue([mockVehicle]),
            }),
            findById: jest.fn().mockResolvedValue(mockVehicle),
            findByIdAndUpdate: jest.fn().mockResolvedValue(mockVehicle),
            countDocuments: jest.fn().mockResolvedValue(5),
          },
        },
        {
          provide: 'BookingModel',
          useValue: {
            countDocuments: jest.fn().mockResolvedValue(100),
          },
        },
        {
          provide: NotificationsService,
          useValue: {
            create: jest.fn().mockResolvedValue({}),
          },
        },
      ],
    }).compile();

    service = module.get<AdminService>(AdminService);
    userModel = module.get<Model<UserDocument>>('UserModel');
    tripModel = module.get<Model<TripDocument>>('TripModel');
    paymentModel = module.get<Model<PaymentDocument>>('PaymentModel');
    vehicleModel = module.get<Model<VehicleDocument>>('VehicleModel');
    bookingModel = module.get<Model<BookingDocument>>('BookingModel');
    notificationsService =
      module.get<NotificationsService>(NotificationsService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getDashboardStats', () => {
    it('should return dashboard statistics', async () => {
      const stats = await service.getDashboardStats();

      expect(stats).toHaveProperty('totalUsers');
      expect(stats).toHaveProperty('totalDrivers');
      expect(stats).toHaveProperty('totalPassengers');
      expect(stats).toHaveProperty('activeTrips');
      expect(stats).toHaveProperty('completedTrips');
      expect(stats).toHaveProperty('totalRevenue');
      expect(stats).toHaveProperty('pendingPayments');
      expect(stats).toHaveProperty('pendingVehicleVerifications');
    });

    it('should call aggregate on user model for role counts', async () => {
      await service.getDashboardStats();
      expect(userModel.aggregate).toHaveBeenCalled();
    });

    it('should call countDocuments for pending payments', async () => {
      await service.getDashboardStats();
      expect(paymentModel.countDocuments).toHaveBeenCalledWith({
        status: 'pending',
      });
    });

    it('should call countDocuments for pending vehicle verifications', async () => {
      await service.getDashboardStats();
      expect(vehicleModel.countDocuments).toHaveBeenCalledWith({
        isVerified: false,
      });
    });
  });

  describe('getUsers', () => {
    it('should return paginated users', async () => {
      const query = { page: 1, limit: 20 };
      const result = await service.getUsers(query);

      expect(result).toHaveProperty('data');
      expect(result).toHaveProperty('meta');
      expect(result.meta).toHaveProperty('page');
      expect(result.meta).toHaveProperty('limit');
      expect(result.meta).toHaveProperty('total');
      expect(result.meta).toHaveProperty('totalPages');
    });

    it('should filter by role when provided', async () => {
      const query = { page: 1, limit: 20, role: UserRole.DRIVER };
      await service.getUsers(query);

      // The find should be called with role filter
      expect(userModel.find).toHaveBeenCalled();
    });

    it('should filter by isActive when provided', async () => {
      const query = { page: 1, limit: 20, isActive: true };
      await service.getUsers(query);

      expect(userModel.find).toHaveBeenCalled();
    });

    it('should search by name or email when search is provided', async () => {
      const query = { page: 1, limit: 20, search: 'test' };
      await service.getUsers(query);

      expect(userModel.find).toHaveBeenCalled();
    });
  });

  describe('changeUserRole', () => {
    it('should change user role successfully', async () => {
      const userId = 'user-id-1';
      const newRole = UserRole.DRIVER;

      const result = await service.changeUserRole(userId, newRole);

      expect(userModel.findById).toHaveBeenCalledWith(userId);
    });

    it('should throw NotFoundException if user not found', async () => {
      jest.spyOn(userModel, 'findById').mockResolvedValueOnce(null as any);

      await expect(
        service.changeUserRole('non-existent-id', UserRole.DRIVER),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('toggleBan', () => {
    it('should ban user successfully', async () => {
      const userId = 'user-id-1';
      const isActive = false;

      await service.toggleBan(userId, isActive);

      expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(
        userId,
        { isActive },
        { new: true },
      );
    });

    it('should unban user successfully', async () => {
      const userId = 'user-id-1';
      const isActive = true;

      await service.toggleBan(userId, isActive);

      expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(
        userId,
        { isActive },
        { new: true },
      );
    });

    it('should send notification when user is banned', async () => {
      const userId = 'user-id-1';
      const isActive = false;

      await service.toggleBan(userId, isActive);

      expect(notificationsService.create).toHaveBeenCalledWith(
        expect.objectContaining({
          userId,
          type: 'account_banned',
        }),
      );
    });
  });

  describe('getTrips', () => {
    it('should return paginated trips', async () => {
      const query = { page: 1, limit: 20 };
      const result = await service.getTrips(query);

      expect(result).toHaveProperty('data');
      expect(result).toHaveProperty('meta');
    });

    it('should filter by status when provided', async () => {
      const query = { page: 1, limit: 20, status: 'active' };
      await service.getTrips(query);

      expect(tripModel.find).toHaveBeenCalled();
    });

    it('should filter by driverId when provided', async () => {
      const query = { page: 1, limit: 20, driverId: 'driver-id-1' };
      await service.getTrips(query);

      expect(tripModel.find).toHaveBeenCalled();
    });
  });

  describe('getPendingPayments', () => {
    it('should return paginated pending payments', async () => {
      const query = { page: 1, limit: 20 };
      const result = await service.getPendingPayments(query);

      expect(result).toHaveProperty('data');
      expect(result).toHaveProperty('meta');
    });

    it('should only return payments with pending status', async () => {
      const query = { page: 1, limit: 20 };
      await service.getPendingPayments(query);

      expect(paymentModel.find).toHaveBeenCalledWith({ status: 'pending' });
    });
  });

  describe('getAllPayments', () => {
    it('should return paginated payments with filters', async () => {
      const query = { page: 1, limit: 20 };
      const result = await service.getAllPayments(query);

      expect(result).toHaveProperty('data');
      expect(result).toHaveProperty('meta');
    });

    it('should filter by status when provided', async () => {
      const query = { page: 1, limit: 20, status: 'approved' };
      await service.getAllPayments(query);

      expect(paymentModel.find).toHaveBeenCalled();
    });

    it('should filter by method when provided', async () => {
      const query = { page: 1, limit: 20, method: 'manual' };
      await service.getAllPayments(query);

      expect(paymentModel.find).toHaveBeenCalled();
    });

    it('should filter by paymentType when provided', async () => {
      const query = { page: 1, limit: 20, paymentType: 'trip' };
      await service.getAllPayments(query);

      expect(paymentModel.find).toHaveBeenCalled();
    });
  });

  describe('verifyVehicle', () => {
    it('should verify vehicle successfully', async () => {
      const vehicleId = 'vehicle-id-1';
      const isVerified = true;

      await service.verifyVehicle(vehicleId, isVerified);

      expect(vehicleModel.findByIdAndUpdate).toHaveBeenCalledWith(
        vehicleId,
        { isVerified },
        { new: true },
      );
    });

    it('should reject vehicle successfully', async () => {
      const vehicleId = 'vehicle-id-1';
      const isVerified = false;

      await service.verifyVehicle(vehicleId, isVerified);

      expect(vehicleModel.findByIdAndUpdate).toHaveBeenCalledWith(
        vehicleId,
        { isVerified },
        { new: true },
      );
    });

    it('should send notification to driver when vehicle is verified', async () => {
      const vehicleId = 'vehicle-id-1';
      const isVerified = true;

      await service.verifyVehicle(vehicleId, isVerified);

      expect(notificationsService.create).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'vehicle_verified',
        }),
      );
    });
  });

  describe('generateReport', () => {
    it('should generate revenue report', async () => {
      const query = {
        type: 'revenue',
        startDate: '2026-01-01',
        endDate: '2026-01-31',
      };

      const result = await service.generateReport(query);

      expect(result).toHaveProperty('type', 'revenue');
      expect(result).toHaveProperty('period');
      expect(result).toHaveProperty('summary');
      expect(result).toHaveProperty('breakdown');
    });

    it('should generate users report', async () => {
      const query = {
        type: 'users',
        startDate: '2026-01-01',
        endDate: '2026-01-31',
      };

      const result = await service.generateReport(query);

      expect(result).toHaveProperty('type', 'users');
      expect(result).toHaveProperty('period');
      expect(result).toHaveProperty('summary');
      expect(result).toHaveProperty('breakdown');
    });

    it('should generate trips report', async () => {
      const query = {
        type: 'trips',
        startDate: '2026-01-01',
        endDate: '2026-01-31',
      };

      const result = await service.generateReport(query);

      expect(result).toHaveProperty('type', 'trips');
      expect(result).toHaveProperty('period');
      expect(result).toHaveProperty('summary');
      expect(result).toHaveProperty('breakdown');
    });

    it('should throw BadRequestException for invalid date range', async () => {
      const query = {
        type: 'revenue',
        startDate: '2026-01-31',
        endDate: '2026-01-01',
      };

      await expect(service.generateReport(query)).rejects.toThrow(
        BadRequestException,
      );
    });
  });
});
