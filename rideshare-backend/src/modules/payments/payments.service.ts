import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { PgUserRole, WalletAccountType } from '../../database/entities';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { CreateCommunicationFeeDto } from './dto/create-communication-fee.dto';
import { CreateWalletTopupDto } from './dto/create-wallet-topup.dto';
import {
  ApprovePaymentDto,
  RejectPaymentDto,
  QueryPaymentsDto,
} from './dto/update-payment-status.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { A2aCliqService } from './a2a-cliq.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PlatformPricingService } from './platform-pricing.service';
import { WalletService } from '../wallet/wallet.service';

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
    private notificationsService: NotificationsService,
    private a2aCliqService: A2aCliqService,
    private platformPricing: PlatformPricingService,
    private walletService: WalletService,
  ) {}

  /**
   * Create a payment for a trip booking (TODO: full TypeORM implementation)
   */
  async createPayment(
    createPaymentDto: CreatePaymentDto,
    userId: string,
  ): Promise<PaymentEntity> {
    throw new BadRequestException(
      'Payment creation not yet migrated to Postgres. Use wallet or manual flows.',
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
    paymentId: string,
    _adminId: string,
    approveDto: ApprovePaymentDto,
  ): Promise<PaymentEntity> {
    const payment = await this.paymentRepo.findOne({
      where: { id: paymentId },
    });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }
    if (payment.status !== 'pending') {
      throw new BadRequestException('Only pending payments can be approved');
    }

    if (payment.paymentType === 'wallet_topup') {
      const user = await this.userRepo.findOne({
        where: { id: payment.userId },
      });
      if (!user) {
        throw new NotFoundException('User not found');
      }
      const accountType =
        user.role === PgUserRole.DRIVER
          ? WalletAccountType.DRIVER
          : WalletAccountType.RIDER;
      await this.walletService.creditPostedTopup({
        userId: payment.userId,
        accountType,
        amount: Number(payment.amount),
        currency: payment.currency,
        idempotencyKey: `payment-topup:${payment.id}`,
        note: `Approved wallet top-up payment ${payment.id}`,
      });
      payment.status = 'approved';
      payment.adminNote = approveDto.adminNote ?? null;
      await this.paymentRepo.save(payment);
      return payment;
    }

    throw new BadRequestException(
      'Approval for this payment type is not implemented yet',
    );
  }

  async reject(
    paymentId: string,
    _adminId: string,
    rejectDto: RejectPaymentDto,
  ): Promise<PaymentEntity> {
    const payment = await this.paymentRepo.findOne({
      where: { id: paymentId },
    });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }
    if (payment.status !== 'pending') {
      throw new BadRequestException('Only pending payments can be rejected');
    }
    payment.status = 'rejected';
    payment.adminNote = rejectDto.adminNote ?? null;
    return this.paymentRepo.save(payment);
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

  /**
   * Debit rider wallet for the platform seat fee and create an approved payment row for the booking.
   */
  async resolvePassengerWalletPaymentForBooking(params: {
    userId: string;
    tripId: string;
    seatNumber: string;
    idempotencyKey?: string;
    countryCode?: string;
  }): Promise<{
    payment: PaymentEntity;
    platformAmount: number;
    driverAmount: number;
  }> {
    const { userId, tripId, seatNumber, countryCode = 'EG', idempotencyKey } =
      params;

    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }
    if (trip.driverId === userId) {
      throw new BadRequestException('Cannot book your own trip');
    }

    const seats = trip.seats || [];
    const seat = seats.find(
      (s: { seatNumber?: string }) => s.seatNumber === seatNumber,
    );
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
        'Online payment is not required for this trip',
      );
    }

    const key = (idempotencyKey?.trim() || randomUUID()) as string;

    const walletTx = await this.walletService.payTripFromRiderWallet(
      userId,
      tripId,
      pricing.platformAmount,
      key,
    );

    const payment = this.paymentRepo.create({
      userId,
      tripId,
      bookingId: null,
      amount: pricing.platformAmount,
      currency: pricing.currency,
      method: 'wallet',
      status: 'approved',
      paymentType: 'trip_platform',
      direction: 'debit',
      paymentGatewayRef: walletTx.id,
    });
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
    userId: string,
    dto: CreateWalletTopupDto,
  ): Promise<PaymentEntity> {
    if (dto.method === 'manual' && !dto.proofImageUrl?.trim()) {
      throw new BadRequestException(
        'Proof image URL is required for manual top-up',
      );
    }
    if (dto.method === 'cliq_a2a') {
      throw new BadRequestException(
        'CliQ wallet top-up is not available yet. Use manual with proof.',
      );
    }
    const p = this.paymentRepo.create({
      userId,
      tripId: null,
      bookingId: null,
      amount: dto.amount,
      currency: dto.currency ?? 'EGP',
      method: dto.method,
      status: 'pending',
      paymentType: 'wallet_topup',
      direction: 'credit',
      proofImageUrl: dto.proofImageUrl ?? null,
      walletNumber: dto.walletNumber ?? null,
    });
    return this.paymentRepo.save(p);
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
