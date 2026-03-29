import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { CreateCommunicationFeeDto } from './dto/create-communication-fee.dto';
import { CreateWalletTopupDto } from './dto/create-wallet-topup.dto';
import {
  ApprovePaymentDto,
  RejectPaymentDto,
  QueryPaymentsDto,
} from './dto/update-payment-status.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { StripeService } from './stripe.service';
import { A2aCliqService } from './a2a-cliq.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PlatformPricingService } from './platform-pricing.service';
import Stripe from 'stripe';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    @InjectRepository(PaymentEntity)
    private paymentRepo: Repository<PaymentEntity>,
    @InjectRepository(CommunicationFeeEntity)
    private communicationFeeRepo: Repository<CommunicationFeeEntity>,
    @InjectRepository(TripEntity) private tripRepo: Repository<TripEntity>,
    @InjectRepository(UserEntity) private userRepo: Repository<UserEntity>,
    private dataSource: DataSource,
    private stripeService: StripeService,
    private notificationsService: NotificationsService,
    private a2aCliqService: A2aCliqService,
    private platformPricing: PlatformPricingService,
  ) {}

  /**
   * Create a payment for a trip booking (TODO: full TypeORM implementation)
   */
  async createPayment(
    createPaymentDto: CreatePaymentDto,
    userId: string,
  ): Promise<PaymentEntity> {
    throw new BadRequestException(
      'Payment creation not yet migrated to Postgres. Use wallet or Stripe.',
    );
  }

  async createCommunicationFee(
    _createCommunicationFeeDto: CreateCommunicationFeeDto,
    _driverId: string,
  ): Promise<PaymentEntity> {
    throw new BadRequestException(
      'Communication fee not yet migrated to Postgres.',
    );
  }

  async initiateCliqCommunicationFee(_params: {
    bookingId: string;
    driverId: string;
    aliasType: 'ALIAS' | 'MOBL';
    aliasValue: string;
  }): Promise<PaymentEntity> {
    throw new BadRequestException('CliQ not yet migrated to Postgres.');
  }

  async refreshCliqPaymentStatus(_paymentId: string): Promise<PaymentEntity> {
    throw new BadRequestException('CliQ not yet migrated to Postgres.');
  }

  async approve(
    _paymentId: string,
    _adminId: string,
    _approveDto: ApprovePaymentDto,
  ): Promise<PaymentEntity> {
    throw new BadRequestException(
      'Approve payment not yet migrated to Postgres.',
    );
  }

  async reject(
    _paymentId: string,
    _adminId: string,
    _rejectDto: RejectPaymentDto,
  ): Promise<PaymentEntity> {
    throw new BadRequestException(
      'Reject payment not yet migrated to Postgres.',
    );
  }

  async findByUser(
    _userId: string,
    _query: QueryPaymentsDto,
  ): Promise<PaginatedResult<PaymentEntity>> {
    return { data: [], meta: { page: 1, limit: 20, total: 0, totalPages: 0 } };
  }

  async findById(
    _paymentId: string,
    _userId: string,
    _isAdmin: boolean = false,
  ): Promise<PaymentEntity> {
    throw new NotFoundException('Payment not found');
  }

  async findAll(
    _query: QueryPaymentsDto,
  ): Promise<PaginatedResult<PaymentEntity>> {
    return { data: [], meta: { page: 1, limit: 20, total: 0, totalPages: 0 } };
  }

  async handleStripeWebhook(_event: any): Promise<void> {
    this.logger.log('Stripe webhook not yet migrated to Postgres.');
  }

  async verifyAndHandleStripeWebhook(
    rawBody: string | Buffer,
    signature: string,
  ): Promise<void> {
    const event = await this.stripeService.handleWebhookEvent(
      rawBody,
      signature,
    );
    if (event.type === 'payment_intent.succeeded') {
      const pi = event.data.object as Stripe.PaymentIntent;
      await this.paymentRepo.update(
        { paymentGatewayRef: pi.id },
        { status: 'approved' },
      );
      this.logger.log(`Stripe PI ${pi.id} marked approved from webhook`);
    }
  }

  /**
   * Legacy / admin: amount supplied by caller. Prefer createPassengerSeatPaymentIntent for bookings.
   */
  async createStripePaymentIntent(
    amount: number,
    currency: string,
    bookingId?: string,
    paymentType?: string,
  ): Promise<{ clientSecret: string; paymentIntentId: string }> {
    return this.stripeService.createPaymentIntent(amount, currency, {
      bookingId: bookingId || '',
      paymentType: paymentType || 'trip',
    });
  }

  async createPassengerSeatPaymentIntent(params: {
    tripId: string;
    seatNumber: string;
    userId: string;
    countryCode?: string;
  }): Promise<{
    clientSecret: string;
    paymentIntentId: string;
    platformAmount: number;
    driverAmount: number;
    currency: string;
  }> {
    const { tripId, seatNumber, userId, countryCode = 'EG' } = params;
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }
    if (trip.driverId === userId) {
      throw new BadRequestException('Cannot book your own trip');
    }
    const seats = trip.seats || [];
    const seat = seats.find((s: { seatNumber?: string }) => s.seatNumber === seatNumber);
    if (!seat || seat.status !== 'available') {
      throw new BadRequestException('Seat is not available');
    }

    const feeRow = await this.platformPricing.getActiveFeeRow(countryCode);
    const pricing = this.platformPricing.passengerSeatPricing(
      Number(trip.price ?? 0),
      trip.currency ?? 'EGP',
      feeRow,
    );
    if (!pricing.requiresOnlinePayment) {
      throw new BadRequestException(
        'No platform fee is configured for this region; complete booking without online payment.',
      );
    }

    const { clientSecret, paymentIntentId } =
      await this.stripeService.createPaymentIntent(
        pricing.platformAmount,
        trip.currency ?? 'EGP',
        {
          tripId,
          seatNumber,
          userId,
          paymentType: 'trip_platform',
        },
      );

    const payment = this.paymentRepo.create({
      userId,
      tripId,
      bookingId: null,
      amount: pricing.platformAmount,
      currency: pricing.currency,
      method: 'stripe',
      status: 'pending',
      paymentType: 'trip_platform',
      direction: 'credit',
      paymentGatewayRef: paymentIntentId,
    });
    await this.paymentRepo.save(payment);

    return {
      clientSecret,
      paymentIntentId,
      platformAmount: pricing.platformAmount,
      driverAmount: pricing.driverAmount,
      currency: pricing.currency,
    };
  }

  /**
   * After Stripe confirms payment, validate and return the payment row for linking to a booking.
   */
  async resolvePassengerPaymentIntentForBooking(params: {
    paymentIntentId: string;
    userId: string;
    tripId: string;
    seatNumber: string;
    countryCode?: string;
  }): Promise<{ payment: PaymentEntity; platformAmount: number; driverAmount: number }> {
    const { paymentIntentId, userId, tripId, seatNumber, countryCode = 'EG' } =
      params;

    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    const feeRow = await this.platformPricing.getActiveFeeRow(countryCode);
    const pricing = this.platformPricing.passengerSeatPricing(
      Number(trip.price ?? 0),
      trip.currency ?? 'EGP',
      feeRow,
    );
    if (!pricing.requiresOnlinePayment) {
      throw new BadRequestException('Online payment is not required for this trip');
    }

    const pi = await this.stripeService.retrievePaymentIntent(paymentIntentId);
    if (pi.status !== 'succeeded') {
      throw new BadRequestException('Payment has not completed successfully');
    }

    const meta = pi.metadata || {};
    if (
      meta.tripId !== tripId ||
      meta.seatNumber !== seatNumber ||
      meta.userId !== userId ||
      meta.paymentType !== 'trip_platform'
    ) {
      throw new BadRequestException('Payment does not match this booking request');
    }

    const expectedCents = Math.round(pricing.platformAmount * 100);
    const paid = pi.amount_received ?? pi.amount;
    if (paid !== expectedCents) {
      throw new BadRequestException('Paid amount does not match expected platform fee');
    }

    const payment = await this.paymentRepo.findOne({
      where: { paymentGatewayRef: paymentIntentId, userId },
    });
    if (!payment) {
      throw new BadRequestException('Payment record not found for this intent');
    }
    if (payment.bookingId) {
      throw new BadRequestException('This payment has already been used for a booking');
    }

    payment.status = 'approved';
    await this.paymentRepo.save(payment);

    return {
      payment,
      platformAmount: pricing.platformAmount,
      driverAmount: pricing.driverAmount,
    };
  }

  async chargeDriverWalletForTrip(
    driverId: string,
    tripId: string,
  ): Promise<void> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('Not the driver of this trip');
    }
    if (trip.driverWalletChargeApplied) {
      return;
    }

    const driver = await this.userRepo.findOne({
      where: { id: driverId },
      select: [
        'id',
        'walletBalance',
        'walletCurrency',
        'hasUsedLifetimeFreeTrip',
      ],
    });
    if (!driver) {
      throw new NotFoundException('User not found');
    }

    const countryCode = 'EG';
    const communicationFee = await this.communicationFeeRepo.findOne({
      where: { countryCode, isActive: true },
    });
    const unlock = this.platformPricing.driverUnlockPricing(
      trip,
      communicationFee,
    );
    const feeAmount = unlock.feeAmount;
    const currency = unlock.currency ?? driver.walletCurrency ?? 'EGP';
    const lifetimeFreeEnabled =
      communicationFee?.lifetimeFreeTripEnabled !== false;

    const qr = this.dataSource.createQueryRunner();
    await qr.connect();
    await qr.startTransaction();
    try {
      if (lifetimeFreeEnabled && !driver.hasUsedLifetimeFreeTrip) {
        await qr.manager.update(
          UserEntity,
          { id: driverId },
          { hasUsedLifetimeFreeTrip: true },
        );
        await qr.manager.update(
          TripEntity,
          { id: tripId },
          {
            driverWalletChargeApplied: true,
            driverWalletChargeAt: new Date(),
            communicationFeeStatus: 'paid',
          },
        );
        await qr.commitTransaction();
        this.logger.log(
          `Lifetime free trip used for driver ${driverId}, trip ${tripId}`,
        );
        return;
      }

      const balance = Number(driver.walletBalance ?? 0);
      if (feeAmount > 0 && balance < feeAmount) {
        await qr.rollbackTransaction();
        throw new BadRequestException(
          'Insufficient wallet balance. Please top up your wallet to confirm bookings and view passenger details.',
        );
      }

      if (feeAmount <= 0) {
        await qr.manager.update(
          TripEntity,
          { id: tripId },
          {
            driverWalletChargeApplied: true,
            driverWalletChargeAt: new Date(),
            communicationFeeStatus: 'paid',
          },
        );
        await qr.commitTransaction();
        this.logger.log(
          `Zero unlock fee for driver ${driverId}, trip ${tripId}; marked paid.`,
        );
        return;
      }

      await qr.manager
        .createQueryBuilder()
        .update(UserEntity)
        .set({ walletBalance: () => '"walletBalance" - :fee' })
        .setParameter('fee', feeAmount)
        .where('id = :id', { id: driverId })
        .execute();
      const payment = qr.manager.create(PaymentEntity, {
        userId: driverId,
        tripId,
        amount: feeAmount,
        currency,
        method: 'manual',
        status: 'approved',
        paymentType: 'wallet_trip_charge',
        direction: 'debit',
      });
      await qr.manager.save(PaymentEntity, payment);
      await qr.manager.update(
        TripEntity,
        { id: tripId },
        {
          driverWalletChargeApplied: true,
          driverWalletChargeAt: new Date(),
          communicationFeeStatus: 'paid',
        },
      );
      await qr.commitTransaction();
      this.logger.log(
        `Wallet charged ${feeAmount} ${currency} for driver ${driverId}, trip ${tripId}`,
      );
    } catch (err) {
      await qr.rollbackTransaction();
      throw err;
    } finally {
      await qr.release();
    }
  }

  async getWalletMe(userId: string): Promise<{
    balance: number;
    currency: string;
    hasUsedLifetimeFreeTrip: boolean;
  }> {
    const user = await this.userRepo.findOne({
      where: { id: userId },
      select: ['walletBalance', 'walletCurrency', 'hasUsedLifetimeFreeTrip'],
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return {
      balance: Number(user.walletBalance ?? 0),
      currency: user.walletCurrency ?? 'EGP',
      hasUsedLifetimeFreeTrip: user.hasUsedLifetimeFreeTrip ?? false,
    };
  }

  async getWalletTransactions(
    _userId: string,
    _query: { page?: number; limit?: number },
  ): Promise<PaginatedResult<PaymentEntity>> {
    return { data: [], meta: { page: 1, limit: 20, total: 0, totalPages: 0 } };
  }

  async createWalletTopup(
    _userId: string,
    _dto: CreateWalletTopupDto,
  ): Promise<PaymentEntity> {
    throw new BadRequestException(
      'Wallet top-up not yet migrated to Postgres.',
    );
  }

  async getPendingPaymentsCount(): Promise<number> {
    return this.paymentRepo.count({ where: { status: 'pending' } });
  }

  async hasUserPaidCommunicationFee(
    _bookingId: string,
    _userId: string,
  ): Promise<boolean> {
    return false;
  }
}
