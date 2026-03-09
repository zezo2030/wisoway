import { Test, TestingModule } from '@nestjs/testing';
import { getModelToken } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { RatingsService } from './ratings.service';
import { Rating, RatingDocument } from './schemas/rating.schema';
import { User, UserDocument } from '../users/schemas/user.schema';
import { Trip, TripDocument } from '../trips/schemas/trip.schema';
import { Booking, BookingDocument } from '../bookings/schemas/booking.schema';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';

describe('RatingsService', () => {
  let service: RatingsService;
  let ratingModel: Model<RatingDocument>;
  let userModel: Model<UserDocument>;
  let tripModel: Model<TripDocument>;
  let bookingModel: Model<BookingDocument>;

  const mockRating = {
    _id: '507f1f77bcf86cd799439011',
    fromUserId: '507f1f77bcf86cd799439012',
    toUserId: '507f1f77bcf86cd799439013',
    tripId: '507f1f77bcf86cd799439014',
    rating: 5,
    comment: 'Great driver!',
    userRole: 'passenger',
    ratedRole: 'driver',
    createdAt: new Date(),
  };

  const mockUser = {
    _id: '507f1f77bcf86cd799439012',
    name: 'John Doe',
    role: 'passenger',
    rating: 4.5,
    totalRatings: 10,
  };

  const mockDriver = {
    _id: '507f1f77bcf86cd799439013',
    name: 'Jane Driver',
    role: 'driver',
    rating: 4.8,
    totalRatings: 50,
    save: jest.fn(),
  };

  const mockTrip = {
    _id: '507f1f77bcf86cd799439014',
    driverId: '507f1f77bcf86cd799439013',
    status: 'completed',
  };

  const mockBooking = {
    _id: '507f1f77bcf86cd799439015',
    tripId: '507f1f77bcf86cd799439014',
    userId: '507f1f77bcf86cd799439012',
    status: 'confirmed',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RatingsService,
        {
          provide: getModelToken(Rating.name),
          useValue: {
            new: jest.fn().mockResolvedValue(mockRating),
            constructor: jest.fn().mockResolvedValue(mockRating),
            find: jest.fn().mockReturnValue({
              populate: jest.fn().mockReturnThis(),
              skip: jest.fn().mockReturnThis(),
              limit: jest.fn().mockReturnThis(),
              sort: jest.fn().mockReturnThis(),
              exec: jest.fn().mockResolvedValue([]),
            }),
            findOne: jest.fn().mockReturnThis(),
            findById: jest.fn().mockReturnThis(),
            create: jest.fn().mockResolvedValue(mockRating),
            countDocuments: jest.fn().mockResolvedValue(0),
            exec: jest.fn().mockResolvedValue(mockRating),
            save: jest.fn().mockResolvedValue(mockRating),
          },
        },
        {
          provide: getModelToken(User.name),
          useValue: {
            findById: jest.fn().mockReturnThis(),
            findByIdAndUpdate: jest.fn().mockReturnThis(),
            exec: jest.fn().mockResolvedValue(mockDriver),
          },
        },
        {
          provide: getModelToken(Trip.name),
          useValue: {
            findById: jest.fn().mockReturnThis(),
            exec: jest.fn().mockResolvedValue(mockTrip),
          },
        },
        {
          provide: getModelToken(Booking.name),
          useValue: {
            findOne: jest.fn().mockReturnThis(),
            exec: jest.fn().mockResolvedValue(mockBooking),
          },
        },
      ],
    }).compile();

    service = module.get<RatingsService>(RatingsService);
    ratingModel = module.get<Model<RatingDocument>>(getModelToken(Rating.name));
    userModel = module.get<Model<UserDocument>>(getModelToken(User.name));
    tripModel = module.get<Model<TripDocument>>(getModelToken(Trip.name));
    bookingModel = module.get<Model<BookingDocument>>(
      getModelToken(Booking.name),
    );
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    const createRatingDto = {
      toUserId: '507f1f77bcf86cd799439013',
      tripId: '507f1f77bcf86cd799439014',
      rating: 5,
      comment: 'Great driver!',
    };

    it('should create a rating successfully', async () => {
      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      } as any);

      jest.spyOn(bookingModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockBooking),
      } as any);

      jest.spyOn(ratingModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      jest.spyOn(userModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockDriver),
      } as any);

      jest.spyOn(ratingModel, 'create').mockResolvedValue(mockRating as any);

      jest.spyOn(ratingModel, 'find').mockReturnValue({
        exec: jest.fn().mockResolvedValue([]),
      } as any);

      const result = await service.create(
        createRatingDto,
        '507f1f77bcf86cd799439012',
        'passenger',
      );
      expect(result).toBeDefined();
    });

    it('should throw NotFoundException if trip not found', async () => {
      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      await expect(
        service.create(
          createRatingDto,
          '507f1f77bcf86cd799439012',
          'passenger',
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException if trip not completed', async () => {
      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue({ ...mockTrip, status: 'active' }),
      } as any);

      await expect(
        service.create(
          createRatingDto,
          '507f1f77bcf86cd799439012',
          'passenger',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw ForbiddenException if user not a participant', async () => {
      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      } as any);

      jest.spyOn(bookingModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      await expect(
        service.create(
          createRatingDto,
          '507f1f77bcf86cd799439012',
          'passenger',
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException if already rated', async () => {
      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      } as any);

      jest.spyOn(bookingModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockBooking),
      } as any);

      jest.spyOn(ratingModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockRating),
      } as any);

      await expect(
        service.create(
          createRatingDto,
          '507f1f77bcf86cd799439012',
          'passenger',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if rating yourself', async () => {
      await expect(
        service.create(
          { ...createRatingDto, toUserId: '507f1f77bcf86cd799439012' },
          '507f1f77bcf86cd799439012',
          'passenger',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('updateUserAverage', () => {
    it('should update user average rating correctly', async () => {
      const ratings = [{ rating: 5 }, { rating: 4 }, { rating: 5 }];

      jest.spyOn(ratingModel, 'find').mockReturnValue({
        exec: jest.fn().mockResolvedValue(ratings),
      } as any);

      jest.spyOn(ratingModel, 'countDocuments').mockReturnValue({
        exec: jest.fn().mockResolvedValue(3),
      } as any);

      jest.spyOn(userModel, 'findByIdAndUpdate').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockDriver),
      } as any);

      await service.updateUserAverage('507f1f77bcf86cd799439013');

      expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(
        '507f1f77bcf86cd799439013',
        expect.objectContaining({
          rating: expect.any(Number),
          totalRatings: 3,
        }),
      );
    });
  });

  describe('findByUser', () => {
    it('should return paginated user ratings', async () => {
      const mockRatings = [mockRating];

      jest.spyOn(ratingModel, 'find').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        sort: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue(mockRatings),
      } as any);

      jest.spyOn(ratingModel, 'countDocuments').mockReturnValue({
        exec: jest.fn().mockResolvedValue(1),
      } as any);

      const result = await service.findByUser('507f1f77bcf86cd799439013', {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });
  });

  describe('findByTrip', () => {
    it('should return paginated trip ratings', async () => {
      const mockRatings = [mockRating];

      jest.spyOn(ratingModel, 'find').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        sort: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue(mockRatings),
      } as any);

      jest.spyOn(ratingModel, 'countDocuments').mockReturnValue({
        exec: jest.fn().mockResolvedValue(1),
      } as any);

      const result = await service.findByTrip('507f1f77bcf86cd799439014', {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });
  });

  describe('findByRater', () => {
    it('should return paginated ratings by rater', async () => {
      const mockRatings = [mockRating];

      jest.spyOn(ratingModel, 'find').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        sort: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue(mockRatings),
      } as any);

      jest.spyOn(ratingModel, 'countDocuments').mockReturnValue({
        exec: jest.fn().mockResolvedValue(1),
      } as any);

      const result = await service.findByRater('507f1f77bcf86cd799439012', {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });
  });
});
