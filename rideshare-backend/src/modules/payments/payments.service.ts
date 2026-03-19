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
    _rawBody: string | Buffer,
    _signature: string,
  ): Promise<void> {
    this.logger.log('Stripe webhook not yet migrated to Postgres.');
  }

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
    const feeAmount = Number(communicationFee?.feeAmount ?? 0);
    const currency =
      communicationFee?.currency ?? driver.walletCurrency ?? 'EGP';

    const qr = this.dataSource.createQueryRunner();
    await qr.connect();
    await qr.startTransaction();
    try {
      if (!driver.hasUsedLifetimeFreeTrip) {
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
      if (balance < feeAmount) {
        await qr.rollbackTransaction();
        throw new BadRequestException(
          'Insufficient wallet balance. Please top up your wallet to confirm bookings and view passenger details.',
        );
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
