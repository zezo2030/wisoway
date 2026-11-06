import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { PgUserRole, WalletAccountType } from '../../database/entities';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { CreateCommunicationFeeDto } from './dto/create-communication-fee.dto';
import { CreateWalletTopupDto } from './dto/create-wallet-topup.dto';
import { UpdateManualPaymentDto } from './dto/update-manual-payment.dto';
import {
  ApprovePaymentDto,
  RejectPaymentDto,
  QueryPaymentsDto,
} from './dto/update-payment-status.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { A2aCliqService, newCliqMessageTrxId } from './a2a-cliq.service';
import { resolveCliqRecipient } from '../ride-payments/cliq-payer';
import { NotificationsService } from '../notifications/notifications.service';
import type { CreateNotificationDto } from '../notifications/dto/create-notification.dto';
import { PlatformPricingService } from './platform-pricing.service';
import { WalletService } from '../wallet/wallet.service';
import { AdminAlertsService } from '../admin/admin-alerts.service';
import { topupCreditedNotice, topupRejectedNotice } from './topup-notices';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import {
  CLIQ_POLL_QUEUE,
  CLIQ_POLL_JOB,
  CliqPollJobData,
} from './processors/cliq-poll.processor';

/**
 * How long a top-up waits on the gateway to accept the request. With the token
 * fetch it must stay under the app's 15 second limit; a slower gateway is not
 * a failure, the payment just carries on as pending.
 */
const CLIQ_PURCHASE_TIMEOUT_MS = 8_000;

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
    @InjectRepository(TripEntity) private tripRepo: Repository<TripEntity>,
    @InjectRepository(UserEntity) private userRepo: Repository<UserEntity>,
    private notificationsService: NotificationsService,
    private a2aCliqService: A2aCliqService,
    private platformPricing: PlatformPricingService,
    private walletService: WalletService,
    private adminAlerts: AdminAlertsService,
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
      this.tellUser(topupCreditedNotice(payment));
      this.alertAdmins(payment);
    } else {
      // The numeric codes are not final at uWallet: 300/310 have turned into 0
      // after a late approval, and the app asks from the moment the request
      // is sent. Rejecting on them would keep money we then never credit. The
      // background poll gives up once the window runs out.
      const failureCodes = ['FAILED', 'REJECTED'];
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
      this.tellUser(topupCreditedNotice(payment));
      return payment;
    }

    throw new BadRequestException(
      'Approval for this payment type is not implemented yet',
    );
  }

  /**
   * Lets a user add the receipt or transfer details to their own manual
   * payment. Once an admin has decided, the payment is frozen.
   */
  async updateManualPayment(
    paymentId: string,
    userId: string,
    dto: UpdateManualPaymentDto,
  ): Promise<PaymentEntity> {
    const hasAny = Object.values(dto).some((value) => value !== undefined);
    if (!hasAny) {
      throw new BadRequestException('At least one field is required');
    }

    const payment = await this.paymentRepo.findOne({
      where: { id: paymentId },
    });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }
    if (payment.userId !== userId) {
      throw new ForbiddenException('Not authorized to update this payment');
    }
    if (payment.method !== 'manual') {
      throw new BadRequestException('Only manual payments can be updated');
    }
    if (payment.status !== 'pending') {
      throw new BadRequestException('Only pending payments can be updated');
    }

    if (dto.proofImageUrl !== undefined) {
      payment.proofImageUrl = dto.proofImageUrl;
    }
    if (dto.walletNumber !== undefined) {
      payment.walletNumber = dto.walletNumber;
    }
    if (dto.transactionId !== undefined) {
      payment.transactionId = dto.transactionId;
    }
    return this.paymentRepo.save(payment);
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
    const rejected = await this.paymentRepo.save(payment);
    if (rejected.paymentType === 'wallet_topup') {
      this.tellUser(topupRejectedNotice(rejected, rejected.adminNote));
    }
    return rejected;
  }

  /**
   * `page`/`limit` arrive as query strings, so they are coerced here rather
   * than trusted as numbers, and clamped so a caller cannot ask for the whole
   * table in one page.
   */
  private resolvePaging(query: QueryPaymentsDto): {
    page: number;
    limit: number;
  } {
    const page = Math.max(1, Number(query?.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(query?.limit) || 20));
    return { page, limit };
  }

  private buildPaymentFilter(query: QueryPaymentsDto): Record<string, unknown> {
    const where: Record<string, unknown> = {};
    if (query?.status) where.status = query.status;
    if (query?.paymentType) where.paymentType = query.paymentType;
    return where;
  }

  /**
   * The current user's own payments — top-ups, trip payments and fees.
   *
   * This and `findById`/`findAll` below were stubs returning an empty page and
   * a hard 404 since the initial commit, so `GET /payments/my`,
   * `GET /payments/:id` and the admin listing never showed anything despite
   * rows existing in `payments`.
   */
  async findByUser(
    userId: string,
    query: QueryPaymentsDto,
  ): Promise<PaginatedResult<PaymentEntity>> {
    const { page, limit } = this.resolvePaging(query);
    const [data, total] = await this.paymentRepo.findAndCount({
      where: { ...this.buildPaymentFilter(query), userId },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });
    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /**
   * A single payment. Non-admins may only read their own — otherwise a payment
   * id would expose another user's amounts and proof image.
   */
  async findById(
    paymentId: string,
    userId: string,
    isAdmin: boolean = false,
  ): Promise<PaymentEntity> {
    const payment = await this.paymentRepo.findOne({
      where: { id: paymentId },
    });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }
    if (!isAdmin && payment.userId !== userId) {
      throw new ForbiddenException('Not authorized to view this payment');
    }
    return payment;
  }

  /** Admin-wide payment listing. */
  async findAll(
    query: QueryPaymentsDto,
  ): Promise<PaginatedResult<PaymentEntity>> {
    const { page, limit } = this.resolvePaging(query);
    const [data, total] = await this.paymentRepo.findAndCount({
      where: this.buildPaymentFilter(query),
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });
    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
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

  // chargeDriverWalletForTrip() was deleted here. It was a second, complete
  // driver-fee implementation: it computed the fee from driverUnlockPricing,
  // consumed hasUsedLifetimeFreeTrip, debited users.walletBalance directly
  // (bypassing the wallet ledger) and stamped driverWalletChargeApplied /
  // communicationFeeStatus / hasDriverPaidToContact — all without writing the
  // `trip-fee:<tripId>` audit row that DriverTripFeeService.chargeAtTripStart
  // uses for idempotency, so it could silently defeat it. Nothing called it.
  // DriverTripFeeService is the only path that charges a driver for a trip.

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
    await this.walletService.assertDriverTopup(
      userId,
      dto.amount,
      dto.currency || 'JOD',
    );
    if (dto.method === 'manual' && !dto.proofImageUrl?.trim()) {
      throw new BadRequestException(
        'Proof image URL is required for manual top-up',
      );
    }
    if (dto.method === 'cliq_a2a') {
      // CliQ is Jordan's rail: it can only fund a dinar wallet.
      if (dto.currency && dto.currency.toUpperCase() !== 'JOD') {
        throw new BadRequestException('CliQ top-ups are available in JOD only');
      }
      if (!dto.aliasType || !dto.aliasValue?.trim()) {
        throw new BadRequestException(
          'aliasType and aliasValue are required for CliQ A2A top-up',
        );
      }
      const recipient = resolveCliqRecipient(dto.aliasType, dto.aliasValue);

      const messageTrxId = newCliqMessageTrxId();
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
        recipientAliasType: recipient.type,
        recipientAliasValue: recipient.value,
        transactionId: messageTrxId,
      });
      const saved = await this.paymentRepo.save(p);

      // The customer approves in their bank app, which can take minutes, so
      // this only sends the request. The app then polls the payment, and the
      // queue keeps checking after it stops.
      let sent: Awaited<ReturnType<A2aCliqService['purchase']>>;
      try {
        sent = await this.a2aCliqService.purchase({
          messageTrxId,
          aliasType: recipient.type,
          aliasValue: recipient.value,
          amount: dto.amount,
          timeoutMs: CLIQ_PURCHASE_TIMEOUT_MS,
        });
      } catch (err) {
        // A failed call doesn't prove the request never arrived, so the
        // payment stays pending and is still checked.
        this.logger.error(
          `CliQ purchase failed for payment ${saved.id}: ${err instanceof Error ? err.message : String(err)}`,
        );
        await this.pollCliqTopup(saved.id, messageTrxId);
        throw new BadRequestException(
          'تعذر إرسال طلب الدفع إلى CliQ الآن. حاول مرة أخرى بعد قليل.',
        );
      }

      if (sent.MSGID) {
        saved.paymentGatewayRef = sent.MSGID;
        await this.paymentRepo.save(saved);
      }

      const code = String(sent.errorCode ?? '');
      // Refused outright (paying yourself): nothing will ever settle.
      if (code === '3010') {
        saved.status = 'rejected';
        saved.adminNote = `[${code}] ${sent.description ?? ''}`
          .trim()
          .slice(0, 500);
        await this.paymentRepo.save(saved);
        throw new BadRequestException(resolveCliqError(code, sent.description));
      }

      await this.pollCliqTopup(saved.id, messageTrxId);

      // A timeout only means the answer was slow. Any other code means no
      // request is on its way, but it isn't proof enough to close the payment.
      if (code !== '0' && code !== 'TIMEOUT') {
        this.logger.error(
          `CliQ refused payment ${saved.id}: [${code}] ${sent.description ?? ''}`.slice(
            0,
            500,
          ),
        );
        throw new BadRequestException(resolveCliqError(code));
      }

      this.logger.log(
        `CliQ payment ${saved.id} sent (errorCode=${code}); awaiting approval`,
      );
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
    const pending = await this.paymentRepo.save(p);
    this.alertAdmins(pending);
    return pending;
  }

  /** Hands a top-up to the background poll: every 10 minutes for 24 hours. */
  private async pollCliqTopup(
    paymentId: string,
    messageTrxId: string,
  ): Promise<void> {
    await this.cliqPollQueue
      .add(
        CLIQ_POLL_JOB,
        {
          paymentId,
          messageTrxId,
          attempt: 1,
          maxAttempts: 144,
          intervalSeconds: 600,
        },
        { delay: 60_000, removeOnComplete: true, removeOnFail: false },
      )
      .catch((err: Error) =>
        this.logger.error(
          `Failed to enqueue CliQ poll for ${paymentId}: ${err.message}`,
        ),
      );
  }

  /** Tell the user how their payment went; never fails the payment. */
  private tellUser(notice: CreateNotificationDto): void {
    this.notificationsService
      .create(notice)
      .catch((err: Error) =>
        this.logger.warn(
          `Payment notice to ${notice.userId} failed: ${err.message}`,
        ),
      );
  }

  /** Alert admins to a top-up waiting on them (or one CliQ settled). */
  private alertAdmins(payment: PaymentEntity): void {
    void this.userRepo
      .findOne({
        where: { id: payment.userId },
        select: ['id', 'name', 'phoneNumber'],
      })
      .then((user) => this.adminAlerts.notifyWalletTopup(payment, user))
      .catch((err: Error) =>
        this.logger.warn(`Admin top-up alert failed: ${err.message}`),
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
