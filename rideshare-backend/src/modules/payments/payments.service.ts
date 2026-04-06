import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
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

/**
 * Maps raw A2A CliQ error codes / descriptions to user-friendly Arabic messages.
 * Falls back to the raw description when no mapping exists.
 */
function resolveCliqError(code: string, description?: string): string {
  const map: Record<string, string> = {
    EE11: 'لم يتم العثور على الحساب، تحقق من قيمة الـ alias وأعد المحاولة',
    EE12: 'رصيد غير كافٍ في الحساب',
    EE13: 'الحساب موقوف أو غير فعّال',
    EE14: 'تجاوزت الحد الأقصى للمعاملات اليومية',
    '310': 'تم رفض العملية من قِبل مزود الخدمة',
    '300': 'انتهت مهلة العملية، حاول مجدداً',
    '001': 'بيانات الطلب غير صحيحة',
  };
  return map[code] ?? description ?? 'فشلت عملية الدفع عبر CliQ';
}

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

  async refreshCliqPaymentStatus(paymentId: string, requestingUserId?: string): Promise<PaymentEntity> {
    const payment = await this.paymentRepo.findOne({ where: { id: paymentId } });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }
    if (requestingUserId && payment.userId !== requestingUserId) {
      throw new ForbiddenException('Not authorized to check this payment');
    }
    if (payment.method !== 'cliq_a2a') {
      throw new BadRequestException('Payment is not a CliQ A2A payment');
    }
    if (payment.status === 'rejected' || payment.status === 'approved') {
      return payment;
    }

    // PaymentInquiry يتوقع MessageTrxID نفسه المرسل في Purchase (محفوظ في transactionId).
    // لا تستخدم paymentGatewayRef (MSGID) أولاً — كان يسبب استعلامًا خاطئًا وحالة pending دائمة.
    const messageTrxId = payment.transactionId ?? payment.paymentGatewayRef;
    if (!messageTrxId) {
      throw new BadRequestException('No CliQ transaction reference found for this payment');
    }

    const inquiry = await this.a2aCliqService.paymentInquiry(messageTrxId);
    const statusCode = String(inquiry.StatusCode ?? '').trim();
    this.logger.log(
      `CliQ inquiry for payment ${paymentId}: StatusCode=${statusCode} (raw=${inquiry.StatusCode}), desc=${inquiry.StatusDescription}`,
    );

    if (statusCode === '0' || statusCode === '000') {
      const user = await this.userRepo.findOne({ where: { id: payment.userId } });
      if (!user) throw new NotFoundException('User not found');
      const accountType =
        user.role === PgUserRole.DRIVER
          ? WalletAccountType.DRIVER
          : WalletAccountType.RIDER;
      await this.walletService.creditPostedTopup({
        userId: payment.userId,
        accountType,
        amount: Number(payment.amount),
        currency: payment.currency,
        idempotencyKey: `cliq-topup:${payment.id}`,
        note: `CliQ A2A wallet top-up ${payment.id}`,
      });
      payment.status = 'approved';
      await this.paymentRepo.save(payment);
    } else {
      // StatusCode "310" = Rejected, "306" = error; "300" = processing — keep pending
      const failureCodes = ['310', '306', 'FAILED', 'REJECTED'];
      if (failureCodes.includes(statusCode)) {
        payment.status = 'rejected';
        payment.adminNote =
          inquiry.StatusDescription_ar ??
          inquiry.StatusDescription ??
          'CliQ payment rejected';
        await this.paymentRepo.save(payment);
        this.logger.log(`Payment ${paymentId} marked rejected (inquiry StatusCode=${statusCode})`);
      }
    }

    const fresh = await this.paymentRepo.findOne({ where: { id: paymentId } });
    return fresh ?? payment;
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
    const { userId, tripId, seatNumber, countryCode = 'JO', idempotencyKey } =
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
      trip.currency ?? 'JOD',
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

  /**
   * Hold platform fee in rider wallet (PENDING) until driver confirms; creates payment status `held`.
   * Must run inside the same DB transaction as booking insert.
   */
  async holdPassengerWalletPaymentInTransaction(
    manager: EntityManager,
    params: {
      userId: string;
      tripId: string;
      bookingId: string;
      platformAmount: number;
      currency: string;
      idempotencyKey: string;
    },
  ): Promise<{ payment: PaymentEntity; walletTxId: string }> {
    const {
      userId,
      tripId,
      bookingId,
      platformAmount,
      currency,
      idempotencyKey,
    } = params;
    if (!Number.isFinite(platformAmount) || platformAmount <= 0) {
      throw new BadRequestException('Invalid platform amount for hold');
    }

    const walletTx = await this.walletService.holdRiderPlatformFeeWithManager(
      manager,
      {
        riderId: userId,
        bookingId,
        tripId,
        amount: platformAmount,
        currency,
        idempotencyKey,
      },
    );

    const payment = manager.create(PaymentEntity, {
      userId,
      tripId,
      bookingId,
      amount: platformAmount,
      currency,
      method: 'wallet',
      status: 'held',
      paymentType: 'trip_platform',
      direction: 'debit',
      paymentGatewayRef: walletTx.id,
    });
    await manager.save(payment);
    return { payment, walletTxId: walletTx.id };
  }

  /** Finalize passenger hold after driver confirms booking (platform fee kept). */
  async capturePassengerHoldForPaymentId(paymentId: string): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const payment = await manager.findOne(PaymentEntity, {
        where: { id: paymentId },
      });
      if (!payment || payment.status !== 'held' || !payment.paymentGatewayRef) {
        return;
      }
      await this.walletService.captureRiderHoldWithManager(
        manager,
        payment.paymentGatewayRef,
      );
      payment.status = 'approved';
      await manager.save(payment);
    });
  }

  /** Refund rider when booking cancelled or trip departed without driver confirm. */
  async releasePassengerHoldForPaymentId(paymentId: string): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const payment = await manager.findOne(PaymentEntity, {
        where: { id: paymentId },
      });
      if (!payment || payment.status !== 'held' || !payment.paymentGatewayRef) {
        return;
      }
      await this.walletService.releaseRiderHoldWithManager(
        manager,
        payment.paymentGatewayRef,
      );
      payment.status = 'refunded';
      await manager.save(payment);
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
      select: ['id', 'hasUsedLifetimeFreeTrip'],
    });
    if (!driver) {
      throw new NotFoundException('User not found');
    }

    const countryCode = 'JO';
    const communicationFee = await this.communicationFeeRepo.findOne({
      where: { countryCode, isActive: true },
    });
    const unlock = this.platformPricing.driverUnlockPricing(
      trip,
      communicationFee,
    );
    const feeAmount = unlock.feeAmount;
    const currency = unlock.currency ?? 'JOD';
    const lifetimeFreeEnabled =
      communicationFee?.lifetimeFreeTripEnabled !== false;

    await this.dataSource.transaction(async (manager) => {
      if (lifetimeFreeEnabled && !driver.hasUsedLifetimeFreeTrip) {
        await manager.update(
          UserEntity,
          { id: driverId },
          { hasUsedLifetimeFreeTrip: true },
        );
        await manager.update(
          TripEntity,
          { id: tripId },
          {
            driverWalletChargeApplied: true,
            driverWalletChargeAt: new Date(),
            communicationFeeStatus: 'paid',
          },
        );
        this.logger.log(
          `Lifetime free trip used for driver ${driverId}, trip ${tripId}`,
        );
        return;
      }

      if (feeAmount <= 0) {
        await manager.update(
          TripEntity,
          { id: tripId },
          {
            driverWalletChargeApplied: true,
            driverWalletChargeAt: new Date(),
            communicationFeeStatus: 'paid',
          },
        );
        this.logger.log(
          `Zero unlock fee for driver ${driverId}, trip ${tripId}; marked paid.`,
        );
        return;
      }

      await this.walletService.debitDriverUnlockFee(manager, {
        driverId,
        tripId,
        feeAmount,
        currency,
      });

      const payment = manager.create(PaymentEntity, {
        userId: driverId,
        tripId,
        amount: feeAmount,
        currency,
        method: 'manual',
        status: 'approved',
        paymentType: 'wallet_trip_charge',
        direction: 'debit',
      });
      await manager.save(payment);
      await manager.update(
        TripEntity,
        { id: tripId },
        {
          driverWalletChargeApplied: true,
          driverWalletChargeAt: new Date(),
          communicationFeeStatus: 'paid',
        },
      );
      this.logger.log(
        `Wallet charged ${feeAmount} ${currency} for driver ${driverId}, trip ${tripId}`,
      );
    });
  }

  async getWalletMe(userId: string): Promise<{
    balance: number;
    currency: string;
    hasUsedLifetimeFreeTrip: boolean;
  }> {
    const user = await this.userRepo.findOne({
      where: { id: userId },
      select: ['hasUsedLifetimeFreeTrip', 'role'],
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    /** Same ledger as admin-approved top-ups (`wallet_accounts`), not legacy `users.walletBalance`. */
    const walletRole =
      user.role === PgUserRole.DRIVER ? 'driver' : 'passenger';
    const summary = await this.walletService.getWalletSummary(
      userId,
      walletRole,
    );
    return {
      balance: summary.balance,
      currency: summary.currency,
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
      if (!dto.aliasType || !dto.aliasValue?.trim()) {
        throw new BadRequestException(
          'aliasType and aliasValue are required for CliQ A2A top-up',
        );
      }

      const messageTrxId = randomUUID();
      const p = this.paymentRepo.create({
        userId,
        tripId: null,
        bookingId: null,
        amount: dto.amount,
        currency: dto.currency ?? 'JOD',
        method: 'cliq_a2a',
        status: 'pending',
        paymentType: 'wallet_topup',
        direction: 'credit',
        recipientAliasType: dto.aliasType,
        recipientAliasValue: dto.aliasValue,
        transactionId: messageTrxId,
      });
      const saved = await this.paymentRepo.save(p);

      try {
        const purchaseResult = await this.a2aCliqService.purchase({
          messageTrxId,
          aliasType: dto.aliasType,
          aliasValue: dto.aliasValue,
          amount: dto.amount,
        });

        if (purchaseResult.MSGID) {
          saved.paymentGatewayRef = purchaseResult.MSGID;
          await this.paymentRepo.save(saved);
        }

        const rawCode = String(purchaseResult.errorCode ?? '');
        const isSuccess = rawCode === '0';

        if (!isSuccess) {
          const userMessage =
            purchaseResult.description_ar ??
            resolveCliqError(rawCode, purchaseResult.description);
          saved.status = 'rejected';
          saved.adminNote = `[${rawCode}] ${purchaseResult.description ?? ''}`.trim();
          await this.paymentRepo.save(saved);
          throw new BadRequestException(userMessage);
        }

        const user = await this.userRepo.findOne({ where: { id: userId } });
        if (user) {
          const accountType =
            user.role === PgUserRole.DRIVER
              ? WalletAccountType.DRIVER
              : WalletAccountType.RIDER;
          try {
            await this.walletService.creditPostedTopup({
              userId,
              accountType,
              amount: dto.amount,
              currency: dto.currency ?? 'JOD',
              idempotencyKey: `cliq-topup:${saved.id}`,
              note: `CliQ A2A wallet top-up ${saved.id}`,
            });
            saved.status = 'approved';
            await this.paymentRepo.save(saved);
            this.logger.log(
              `CliQ purchase succeeded (errorCode=0), wallet credited immediately for payment ${saved.id}`,
            );
          } catch (creditErr) {
            this.logger.error(
              `CliQ purchase succeeded but wallet credit failed for payment ${saved.id}: ${creditErr}`,
            );
          }
        }
      } catch (err) {
        if (err instanceof BadRequestException) throw err;
        saved.status = 'rejected';
        saved.adminNote = 'CliQ gateway error';
        await this.paymentRepo.save(saved);
        throw new BadRequestException('تعذّر الاتصال ببوابة CliQ، حاول مجدداً');
      }

      return saved;
    }

    const p = this.paymentRepo.create({
      userId,
      tripId: null,
      bookingId: null,
      amount: dto.amount,
      currency: dto.currency ?? 'JOD',
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
