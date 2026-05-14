import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { RatingEntity } from '../../database/entities/rating.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { CreateRatingDto } from './dto/create-rating.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { NotificationsService } from '../notifications/notifications.service';

const PASSENGER_BOOKING_STATUSES: BookingStatus[] = [
  BookingStatus.CONFIRMED,
  BookingStatus.COMPLETED,
  BookingStatus.IN_PROGRESS,
];

@Injectable()
export class RatingsService {
  private readonly logger = new Logger(RatingsService.name);

  constructor(
    @InjectRepository(RatingEntity)
    private readonly ratingRepo: Repository<RatingEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(
    createRatingDto: CreateRatingDto,
    fromUserId: string,
    userRole: string,
  ): Promise<RatingEntity> {
    const { toUserId, tripId, rating, comment } = createRatingDto;

    if (fromUserId === toUserId) {
      throw new BadRequestException('لا يمكنك تقييم نفسك');
    }

    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      throw new NotFoundException('الرحلة غير موجودة');
    }

    if (trip.status !== TripStatus.COMPLETED) {
      throw new BadRequestException(
        'لا يمكن التقييم إلا بعد اكتمال الرحلة. انتظر حتى ينهي السائق الرحلة ثم عُد للتقييم.',
      );
    }

    const isDriver = trip.driverId === fromUserId;

    const passengerBooking = await this.bookingRepo.findOne({
      where: {
        tripId,
        userId: fromUserId,
        status: In(PASSENGER_BOOKING_STATUSES),
      },
    });

    const isPassenger = !!passengerBooking;

    if (!isDriver && !isPassenger) {
      throw new ForbiddenException('أنت لست مشاركاً في هذه الرحلة');
    }

    const existingRating = await this.ratingRepo.findOne({
      where: { fromUserId, tripId },
    });
    if (existingRating) {
      throw new BadRequestException(
        'لقد قمت بالفعل بتقييم هذا المستخدم لهذه الرحلة',
      );
    }

    const targetUser = await this.userRepo.findOne({ where: { id: toUserId } });
    if (!targetUser) {
      throw new NotFoundException('المستخدم غير موجود');
    }

    const ratedRole = userRole === 'driver' ? 'passenger' : 'driver';

    const newRating = this.ratingRepo.create({
      fromUserId,
      toUserId,
      tripId,
      rating,
      comment: comment ?? null,
      userRole,
      ratedRole,
    });
    const saved = await this.ratingRepo.save(newRating);

    await this.updateUserAverage(toUserId);

    await this.notificationsService
      .create({
        userId: toUserId,
        type: 'rating_new',
        title: 'تقييم جديد',
        body: `وصلك تقييم ${rating} من 5${comment ? ` — ${comment}` : ''}`,
        data: { tripId, ratingId: saved.id },
      })
      .catch((err: Error) =>
        this.logger.warn(`Failed to notify rated user: ${err.message}`),
      );

    return saved;
  }

  async updateUserAverage(userId: string): Promise<void> {
    const raw = await this.ratingRepo
      .createQueryBuilder('r')
      .select('COUNT(r.id)::int', 'cnt')
      .addSelect('COALESCE(SUM(r.rating), 0)::float', 'sum')
      .where('r.toUserId = :userId', { userId })
      .getRawOne<{ cnt: string; sum: string }>();

    const totalRatings = Number(raw?.cnt ?? 0);

    if (totalRatings === 0) {
      await this.userRepo.update(userId, {
        rating: 0,
        totalRatings: 0,
      });
      return;
    }

    const sum = Number(raw?.sum ?? 0);
    const average = sum / totalRatings;

    await this.userRepo.update(userId, {
      rating: Math.round(average * 10) / 10,
      totalRatings,
    });
  }

  async findByUser(
    userId: string,
    pagination: { page: number; limit: number },
  ): Promise<PaginatedResult<RatingEntity>> {
    const { page, limit } = pagination;
    const skip = (page - 1) * limit;

    const [data, total] = await this.ratingRepo.findAndCount({
      where: { toUserId: userId },
      relations: ['fromUser'],
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findByTrip(
    tripId: string,
    pagination: { page: number; limit: number },
  ): Promise<PaginatedResult<RatingEntity>> {
    const { page, limit } = pagination;
    const skip = (page - 1) * limit;

    const [data, total] = await this.ratingRepo.findAndCount({
      where: { tripId },
      relations: ['fromUser', 'toUser'],
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findByRater(
    raterId: string,
    pagination: { page: number; limit: number },
  ): Promise<PaginatedResult<RatingEntity>> {
    const { page, limit } = pagination;
    const skip = (page - 1) * limit;

    const [data, total] = await this.ratingRepo.findAndCount({
      where: { fromUserId: raterId },
      relations: ['toUser'],
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}
