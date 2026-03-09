import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Rating, RatingDocument } from './schemas/rating.schema';
import { User, UserDocument } from '../users/schemas/user.schema';
import { Trip, TripDocument } from '../trips/schemas/trip.schema';
import { Booking, BookingDocument } from '../bookings/schemas/booking.schema';
import { CreateRatingDto } from './dto/create-rating.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class RatingsService {
  private readonly logger = new Logger(RatingsService.name);

  constructor(
    @InjectModel(Rating.name) private ratingModel: Model<RatingDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Trip.name) private tripModel: Model<TripDocument>,
    @InjectModel(Booking.name) private bookingModel: Model<BookingDocument>,
    private notificationsService: NotificationsService,
  ) {}

  async create(
    createRatingDto: CreateRatingDto,
    fromUserId: string,
    userRole: string,
  ): Promise<Rating> {
    const { toUserId, tripId, rating, comment } = createRatingDto;

    if (fromUserId === toUserId) {
      throw new BadRequestException('You cannot rate yourself');
    }

    const trip = await this.tripModel.findById(tripId).exec();
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    if (trip.status !== 'completed') {
      throw new BadRequestException('Trip must be completed to rate');
    }

    const isDriver = trip.driverId.toString() === fromUserId;

    const passengerBooking = await this.bookingModel
      .findOne({
        tripId: tripId,
        userId: fromUserId,
        status: 'confirmed',
      })
      .exec();

    const isPassenger = !!passengerBooking;

    if (!isDriver && !isPassenger) {
      throw new ForbiddenException('You are not a participant of this trip');
    }

    const existingRating = await this.ratingModel
      .findOne({
        fromUserId: new Types.ObjectId(fromUserId),
        tripId: new Types.ObjectId(tripId),
      })
      .exec();
    if (existingRating) {
      throw new BadRequestException(
        'You have already rated this user for this trip',
      );
    }

    const targetUser = await this.userModel.findById(toUserId).exec();
    if (!targetUser) {
      throw new NotFoundException('User not found');
    }

    const ratedRole = userRole === 'driver' ? 'passenger' : 'driver';

    const newRating = await this.ratingModel.create({
      fromUserId: new Types.ObjectId(fromUserId),
      toUserId: new Types.ObjectId(toUserId),
      tripId: new Types.ObjectId(tripId),
      rating,
      comment,
      userRole,
      ratedRole,
    });

    await this.updateUserAverage(toUserId);

    // Send notification to rated user
    await this.notificationsService.create({
      userId: toUserId,
      type: 'rating_new',
      title: 'New Rating',
      body: `You received a ${rating}-star rating${comment ? `: ${comment}` : ''}`,
      data: { tripId, ratingId: newRating._id.toString() },
    });

    return newRating;
  }

  async updateUserAverage(userId: string): Promise<void> {
    const ratings = await this.ratingModel
      .find({ toUserId: new Types.ObjectId(userId) })
      .exec();
    const totalRatings = ratings.length;

    if (totalRatings === 0) {
      await this.userModel.findByIdAndUpdate(userId, {
        rating: 0,
        totalRatings: 0,
      });
      return;
    }

    const sum = ratings.reduce((acc, r) => acc + r.rating, 0);
    const average = sum / totalRatings;

    await this.userModel.findByIdAndUpdate(userId, {
      rating: Math.round(average * 10) / 10,
      totalRatings,
    });
  }

  async findByUser(
    userId: string,
    pagination: { page: number; limit: number },
  ): Promise<PaginatedResult<Rating>> {
    const { page, limit } = pagination;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.ratingModel
        .find({ toUserId: new Types.ObjectId(userId) })
        .populate('fromUserId', 'name photoUrl')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .exec(),
      this.ratingModel
        .countDocuments({ toUserId: new Types.ObjectId(userId) })
        .exec(),
    ]);

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
  ): Promise<PaginatedResult<Rating>> {
    const { page, limit } = pagination;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.ratingModel
        .find({ tripId: new Types.ObjectId(tripId) })
        .populate('fromUserId', 'name photoUrl')
        .populate('toUserId', 'name photoUrl')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .exec(),
      this.ratingModel
        .countDocuments({ tripId: new Types.ObjectId(tripId) })
        .exec(),
    ]);

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
  ): Promise<PaginatedResult<Rating>> {
    const { page, limit } = pagination;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.ratingModel
        .find({ fromUserId: new Types.ObjectId(raterId) })
        .populate('toUserId', 'name photoUrl')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .exec(),
      this.ratingModel
        .countDocuments({ fromUserId: new Types.ObjectId(raterId) })
        .exec(),
    ]);

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
