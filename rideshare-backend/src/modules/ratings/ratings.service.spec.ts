import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { RatingsService } from './ratings.service';
import { RatingEntity } from '../../database/entities/rating.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { NotificationsService } from '../notifications/notifications.service';

describe('RatingsService', () => {
  let service: RatingsService;
  let ratingRepo: jest.Mocked<Repository<RatingEntity>>;
  let userRepo: jest.Mocked<Repository<UserEntity>>;
  let tripRepo: jest.Mocked<Repository<TripEntity>>;
  let bookingRepo: jest.Mocked<Repository<BookingEntity>>;

  const uid = {
    passenger: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    driver: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    trip: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  };

  const mockTrip: Partial<TripEntity> = {
    id: uid.trip,
    driverId: uid.driver,
    status: TripStatus.COMPLETED,
  };

  const mockBooking: Partial<BookingEntity> = {
    id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
    tripId: uid.trip,
    userId: uid.passenger,
    status: 'completed',
  };

  const mockRating: Partial<RatingEntity> = {
    id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    fromUserId: uid.passenger,
    toUserId: uid.driver,
    tripId: uid.trip,
    rating: 5,
    comment: 'Great driver!',
    userRole: 'passenger',
    ratedRole: 'driver',
    createdAt: new Date(),
  };

  const mockDriver: Partial<UserEntity> = {
    id: uid.driver,
    name: 'Jane Driver',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RatingsService,
        {
          provide: getRepositoryToken(RatingEntity),
          useValue: {
            findOne: jest.fn(),
            findAndCount: jest.fn(),
            create: jest.fn(),
            save: jest.fn(),
            createQueryBuilder: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(UserEntity),
          useValue: {
            findOne: jest.fn(),
            update: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(TripEntity),
          useValue: {
            findOne: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: {
            findOne: jest.fn(),
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

    service = module.get(RatingsService);
    ratingRepo = module.get(getRepositoryToken(RatingEntity));
    userRepo = module.get(getRepositoryToken(UserEntity));
    tripRepo = module.get(getRepositoryToken(TripEntity));
    bookingRepo = module.get(getRepositoryToken(BookingEntity));
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    const createRatingDto = {
      toUserId: uid.driver,
      tripId: uid.trip,
      rating: 5,
      comment: 'Great driver!',
    };

    const qbMock = () => ({
      select: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getRawOne: jest.fn().mockResolvedValue({ cnt: '1', sum: '5' }),
    });

    it('should create a rating successfully', async () => {
      tripRepo.findOne.mockResolvedValue(mockTrip as TripEntity);
      bookingRepo.findOne.mockResolvedValue(mockBooking as BookingEntity);
      ratingRepo.findOne.mockResolvedValue(null);
      userRepo.findOne.mockResolvedValue(mockDriver as UserEntity);
      ratingRepo.create.mockReturnValue(mockRating as RatingEntity);
      ratingRepo.save.mockResolvedValue(mockRating as RatingEntity);
      ratingRepo.createQueryBuilder.mockReturnValue(qbMock() as any);
      userRepo.update.mockResolvedValue({} as any);

      const result = await service.create(
        createRatingDto,
        uid.passenger,
        'passenger',
      );
      expect(result).toBeDefined();
      expect(ratingRepo.save).toHaveBeenCalled();
    });

    it('should throw NotFoundException if trip not found', async () => {
      tripRepo.findOne.mockResolvedValue(null);

      await expect(
        service.create(createRatingDto, uid.passenger, 'passenger'),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException if trip not completed', async () => {
      tripRepo.findOne.mockResolvedValue({
        ...mockTrip,
        status: TripStatus.IN_PROGRESS,
      } as TripEntity);

      await expect(
        service.create(createRatingDto, uid.passenger, 'passenger'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw ForbiddenException if user not a participant', async () => {
      tripRepo.findOne.mockResolvedValue(mockTrip as TripEntity);
      bookingRepo.findOne.mockResolvedValue(null);

      await expect(
        service.create(createRatingDto, uid.passenger, 'passenger'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException if already rated', async () => {
      tripRepo.findOne.mockResolvedValue(mockTrip as TripEntity);
      bookingRepo.findOne.mockResolvedValue(mockBooking as BookingEntity);
      ratingRepo.findOne.mockResolvedValue(mockRating as RatingEntity);

      await expect(
        service.create(createRatingDto, uid.passenger, 'passenger'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if rating yourself', async () => {
      await expect(
        service.create(
          { ...createRatingDto, toUserId: uid.passenger },
          uid.passenger,
          'passenger',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('updateUserAverage', () => {
    it('should update user average rating correctly', async () => {
      ratingRepo.createQueryBuilder.mockReturnValue({
        select: jest.fn().mockReturnThis(),
        addSelect: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        getRawOne: jest.fn().mockResolvedValue({ cnt: '3', sum: '14' }),
      } as any);
      userRepo.update.mockResolvedValue({} as any);

      await service.updateUserAverage(uid.driver);

      expect(userRepo.update).toHaveBeenCalledWith(
        uid.driver,
        expect.objectContaining({
          rating: expect.any(Number),
          totalRatings: 3,
        }),
      );
    });
  });

  describe('findByUser', () => {
    it('should return paginated user ratings', async () => {
      ratingRepo.findAndCount.mockResolvedValue([
        [mockRating as RatingEntity],
        1,
      ]);

      const result = await service.findByUser(uid.driver, {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });
  });

  describe('findByTrip', () => {
    it('should return paginated trip ratings', async () => {
      ratingRepo.findAndCount.mockResolvedValue([
        [mockRating as RatingEntity],
        1,
      ]);

      const result = await service.findByTrip(uid.trip, {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });
  });

  describe('findByRater', () => {
    it('should return paginated ratings by rater', async () => {
      ratingRepo.findAndCount.mockResolvedValue([
        [mockRating as RatingEntity],
        1,
      ]);

      const result = await service.findByRater(uid.passenger, {
        page: 1,
        limit: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });
  });
});
