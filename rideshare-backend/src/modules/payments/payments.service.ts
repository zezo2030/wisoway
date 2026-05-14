import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { UserEntity } from '../../database/entities/user.entity';
import {
  BookingEntity,
  BookingStatus,
  PgUserRole,
  WalletAccountType,
} from '../../database/entities';
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
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import {
  CLIQ_POLL_QUEUE,
  CLIQ_POLL_JOB,
  CliqPollJobData,
} from './processors/cliq-poll.processor';

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
    @InjectQueue(CLIQ_POLL_QUEUE)
    private cliqPollQueue: Queue<CliqPollJobData>,
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

  async refreshCliqPaymentStatus(
    paymentId: string,
    requestingUserId?: string,
  ): Promise<PaymentEntity> {
    const payment = await this.paymentRepo.findOne({
      where: { id: paymentId },
    });
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
      throw new BadRequestException(
        'No CliQ transaction reference found for this payment',
      );
    }

    const inquiry = await this.a2aCliqService.paymentInquiry(messageTrxId);
    const statusCode = String(inquiry.StatusCode ?? '').trim();
    this.logger.log(
      `CliQ inquiry for payment ${paymentId}: StatusCode=${statusCode} (raw=${inquiry.StatusCode}), desc=${inquiry.StatusDescription}`,
    );

    if (statusCode === '0' || statusCode === '000') {
      const user = await this.userRepo.findOne({
        where: { id: payment.userId },
      });
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
        this.logger.log(
          `Payment ${paymentId} marked rejected (inquiry StatusCode=${statusCode})`,
        );
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
    const {
      userId,
      tripId,
      seatNumber,
      countryCode = 'JO',
      idempotencyKey,
    } = params;

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

    const key = idempotencyKey?.trim() || randomUUID();

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

    const countryCode = 'JO';
    const communicationFee = await this.communicationFeeRepo.findOne({
      where: { countryCode, isActive: true },
    });
    const unlock = this.platformPricing.driverUnlockPricing(
      trip,
      communicationFee,
    );
    const feeAmount = unlock.feeAmount;
    const currency = unlock.currency ?? driver.walletCurrency ?? 'JOD';
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
        await qr.manager.update(
          BookingEntity,
          {
            tripId,
            status: In([BookingStatus.PENDING, BookingStatus.CONFIRMED]),
          },
          { hasDriverPaidToContact: true },
        );
        await qr.commitTransaction();
        this.logger.log(
          `Lifetime free trip used for driver ${driverId}, trip ${tripId}`,
        );
        return;
      }

      const balance = Number(driver.walletBalance ?? 0);
      if (feeAmount > 0 && balance < feeAmount) {
        // Don't roll back here — the outer catch handles it. Doing both
        // raises TransactionNotStartedError on the second rollback and
        // hides the real cause (insufficient balance).
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
        await qr.manager.update(
          BookingEntity,
          {
            tripId,
            status: In([BookingStatus.PENDING, BookingStatus.CONFIRMED]),
          },
          { hasDriverPaidToContact: true },
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
      await qr.manager.update(
        BookingEntity,
        {
          tripId,
          status: In([BookingStatus.PENDING, BookingStatus.CONFIRMED]),
        },
        { hasDriverPaidToContact: true },
      );
      await qr.commitTransaction();
      this.logger.log(
        `Wallet charged ${feeAmount} ${currency} for driver ${driverId}, trip ${tripId}`,
      );
    } catch (err) {
      if (qr.isTransactionActive) {
        await qr.rollbackTransaction();
      }
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
      currency: user.walletCurrency ?? 'JOD',
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
        // المنطق الجديد:
        //   1. purchaseAndAwait يبعت Purchase + يـ poll لمدة ~120 ثانية
        //   2. لو StatusCode=0 → نشحن المحفظة ونعتبرها approved
        //   3. لو رفض نهائي فوري (مثل 3010) → status=rejected
        //   4. لو لسه pending بعد الـ 120s → نسيب status=pending ونضيف
        //      job للـ background polling لمدة 24 ساعة
        const result = await this.a2aCliqService.purchaseAndAwait({
          messageTrxId,
          aliasType: dto.aliasType,
          aliasValue: dto.aliasValue,
          amount: dto.amount,
          // foreground polling: 120s إجمالي، كل 3 ثوانٍ
          inquiryMaxWaitMs: 120_000,
          inquiryIntervalMs: 3_000,
        });

        if (result.MSGID) {
          saved.paymentGatewayRef = result.MSGID;
          await this.paymentRepo.save(saved);
        }

        // (1) نجاح مؤكد
        if (result.isSuccess) {
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
                `CliQ payment ${saved.id} succeeded immediately (StatusCode=0)`,
              );
            } catch (creditErr) {
              // العملية ناجحة عند uWallet لكن شحن المحفظة فشل — admin يحلها يدوياً
              this.logger.error(
                `CliQ payment ${saved.id} succeeded but wallet credit failed: ${creditErr instanceof Error ? creditErr.message : String(creditErr)}`,
              );
              saved.adminNote =
                `CliQ succeeded but wallet credit failed: ${creditErr instanceof Error ? creditErr.message : String(creditErr)}`.slice(
                  0,
                  500,
                );
              await this.paymentRepo.save(saved);
            }
          }
          return saved;
        }

        // (2) رفض نهائي مؤكد (مثلاً 3010 self-payment) — terminal بدون نجاح
        if (result.isTerminal && !result.isSuccess) {
          const code = String(result.StatusCode ?? '');
          const userMessage = resolveCliqError(code, result.StatusDescription);
          saved.status = 'rejected';
          saved.adminNote =
            `[${code}] ${result.StatusDescription ?? ''}`.trim().slice(0, 500);
          await this.paymentRepo.save(saved);
          throw new BadRequestException(userMessage);
        }

        // (3) لسه pending — نضيف Job للـ background polling لـ ~24 ساعة
        // كل 10 دقائق × 144 محاولة = 24 ساعة
        await this.cliqPollQueue.add(
          CLIQ_POLL_JOB,
          {
            paymentId: saved.id,
            messageTrxId,
            attempt: 1,
            maxAttempts: 144,
            intervalSeconds: 600,
          },
          {
            delay: 60_000, // أول محاولة بعد دقيقة من نهاية الـ foreground polling
            removeOnComplete: true,
            removeOnFail: false,
          },
        );
        this.logger.log(
          `CliQ payment ${saved.id} is pending (last StatusCode=${result.StatusCode}); background polling enqueued`,
        );
        // المعاملة هترجع للمستخدم بـ status='pending' وهيشوفها معلقة لحد ما تتأكد
      } catch (err) {
        if (err instanceof BadRequestException) throw err;
        // خطأ شبكة أو نظام — مش معناه فشل المعاملة. نسيبها pending ونعمل polling.
        this.logger.error(
          `CliQ purchaseAndAwait threw for payment ${saved.id}: ${err instanceof Error ? err.message : String(err)}`,
        );
        await this.cliqPollQueue.add(
          CLIQ_POLL_JOB,
          {
            paymentId: saved.id,
            messageTrxId,
            attempt: 1,
            maxAttempts: 144,
            intervalSeconds: 600,
          },
          {
            delay: 60_000,
            removeOnComplete: true,
            removeOnFail: false,
          },
        );
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
