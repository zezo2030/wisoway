import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Cron } from '@nestjs/schedule';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import { randomUUID } from 'crypto';
import { In, Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { A2aCliqService } from '../payments/a2a-cliq.service';
import { WalletService } from '../wallet/wallet.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ComplaintsService } from '../complaints/complaints.service';
import { parseCliqPayer } from './cliq-payer';

export const RIDE_FARE_CLIQ_QUEUE = 'ride-fare-cliq';
export const RIDE_FARE_POLL_JOB = 'poll-ride-fare';

/** Check the bank every 10 s for 10 minutes before calling it failed. */
export const RIDE_FARE_POLL_INTERVAL_MS = 10_000;
export const RIDE_FARE_POLL_ATTEMPTS = 60;

export type RideFarePollJob = { paymentId: string; attempt: number };

export type PaymentStatus =
  | 'pending'
  | 'requested'
  | 'failed'
  | 'paid'
  | 'disputed';

/** A booking's fare as either side of the ride sees it. */
export interface RidePaymentView {
  bookingId: string;
  tripId: string;
  passengerId: string;
  passengerName: string | null;
  amount: string;
  originalAmount: string;
  discountAmount: string;
  promoCode: string | null;
  currency: string;
  method: string;
  status: PaymentStatus;
  payerCliqAlias: string | null;
  paidAt: Date | null;
  disputedAt: Date | null;
}

/**
 * Collecting ride fares, for instant rides and shared trips alike.
 *
 * The passenger picks the method when booking. When the driver ends the ride:
 *  - cash: the fare is owed to the driver in hand, and the driver confirms
 *    it (or reports that it never came);
 *  - cliq: a CliQ request-to-pay goes to the passenger's alias. Once the bank
 *    confirms, the platform credits the full fare to the driver's wallet. If
 *    it fails the passenger can ask again or pay cash instead.
 *
 * Until the fare is settled the passenger's end-of-trip screen stays up.
 */
@Injectable()
export class RidePaymentsService {
  private readonly logger = new Logger(RidePaymentsService.name);

  constructor(
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(PaymentEntity)
    private readonly paymentRepo: Repository<PaymentEntity>,
    private readonly cliq: A2aCliqService,
    private readonly wallet: WalletService,
    private readonly notifications: NotificationsService,
    private readonly complaints: ComplaintsService,
    @InjectQueue(RIDE_FARE_CLIQ_QUEUE)
    private readonly pollQueue: Queue<RideFarePollJob>,
  ) {}

  // ── When the driver ends the ride ─────────────────────────────────────────

  /** Recover verified receipts when a worker crashed before committing the ledger. */
  @Cron('*/5 * * * *')
  async recoverPendingReceipts(): Promise<void> {
    const pending = await this.paymentRepo.find({
      where: {
        paymentType: 'ride_fare',
        method: 'cliq_a2a',
        status: 'pending',
      },
      order: { createdAt: 'ASC' },
      take: 100,
    });
    for (const payment of pending) {
      try {
        const code = await this.inquire(payment);
        if (code === '0' || code === '000') await this.onCliqPaid(payment);
      } catch (error) {
        this.logger.error(
          `Receipt ${payment.id} awaits ledger recovery: ${(error as Error).message}`,
        );
      }
    }
  }

  /**
   * Called once the trip is completed: asks every CliQ passenger who rode for
   * their fare, and reminds cash passengers to pay the driver. Never throws —
   * a payment problem must not undo the trip's completion.
   */
  async openForTrip(tripId: string): Promise<void> {
    await this.wallet.chargeCompletedTripCommission(tripId);
    const bookings = await this.bookingRepo.find({
      where: {
        tripId,
        status: BookingStatus.COMPLETED,
        paymentStatus: 'pending',
      },
    });
    for (const booking of bookings) {
      try {
        if (Number(booking.totalAmount) === 0) {
          await this.wallet.settleCollectedFare(
            booking.id,
            booking.paymentMethod as 'cash' | 'cliq' | 'wallet',
            booking.userId,
          );
        } else if (booking.paymentMethod === 'wallet') {
          await this.wallet.settleCollectedFare(
            booking.id,
            'wallet',
            booking.userId,
          );
        } else if (booking.paymentMethod === 'cliq') {
          await this.requestCliq(booking);
        } else {
          await this.push(booking.userId, {
            title: 'الرجاء دفع تكلفة الرحلة للسائق',
            body: `المبلغ المطلوب ${booking.totalAmount}. سيؤكد السائق الاستلام.`,
            type: 'ride_payment_due',
            data: { tripId, bookingId: booking.id },
          });
        }
      } catch (err) {
        this.logger.error(
          `Opening payment for booking ${booking.id} failed: ${(err as Error).message}`,
        );
      }
    }
  }

  /** Sends the CliQ request-to-pay and starts watching it. */
  private async requestCliq(booking: BookingEntity): Promise<void> {
    const payer = parseCliqPayer(booking.payerCliqAlias);
    const trip = await this.tripRepo.findOne({ where: { id: booking.tripId } });
    if (!payer || !trip) {
      await this.markFailed(booking, 'no-payer-alias');
      return;
    }

    const messageTrxId = randomUUID();
    const payment = await this.paymentRepo.save(
      this.paymentRepo.create({
        userId: booking.userId,
        tripId: booking.tripId,
        bookingId: booking.id,
        amount: Number(booking.totalAmount),
        currency: trip.currency,
        method: 'cliq_a2a',
        status: 'pending',
        paymentType: 'ride_fare',
        direction: 'credit',
        recipientAliasType: payer.type,
        recipientAliasValue: payer.value,
        transactionId: messageTrxId,
      }),
    );
    booking.passengerPaymentId = payment.id;
    booking.paymentStatus = 'requested';
    await this.bookingRepo.save(booking);

    try {
      const result = await this.cliq.purchase({
        messageTrxId,
        aliasType: payer.type,
        aliasValue: payer.value,
        amount: Number(booking.totalAmount),
      });
      if (result?.MSGID) {
        payment.paymentGatewayRef = result.MSGID;
        await this.paymentRepo.save(payment);
      }
      // Refused outright (e.g. 3010: paying yourself) — no point polling.
      if (String(result?.errorCode ?? '') === '3010') {
        payment.status = 'rejected';
        payment.adminNote = '[ride-fare] Purchase rejected: 3010';
        await this.paymentRepo.save(payment);
        await this.markFailed(booking, '3010');
        return;
      }
    } catch (err) {
      // A network error doesn't mean the request wasn't delivered: the
      // inquiry polling below finds out either way.
      this.logger.warn(
        `CliQ purchase for booking ${booking.id} threw: ${(err as Error).message}`,
      );
    }

    await this.push(booking.userId, {
      title: 'طلب دفع CliQ',
      body: `وافق على طلب دفع ${booking.totalAmount} ${trip.currency} في تطبيق البنك.`,
      type: 'ride_payment_requested',
      data: { tripId: booking.tripId, bookingId: booking.id },
    });
    await this.schedulePoll({ paymentId: payment.id, attempt: 1 });
  }

  private async schedulePoll(job: RideFarePollJob): Promise<void> {
    await this.pollQueue
      .add(RIDE_FARE_POLL_JOB, job, {
        delay: RIDE_FARE_POLL_INTERVAL_MS,
        removeOnComplete: true,
        removeOnFail: true,
        attempts: 10,
        backoff: { type: 'exponential', delay: 10_000 },
      })
      .catch((err: Error) =>
        this.logger.warn(`Failed to enqueue ride fare poll: ${err.message}`),
      );
  }

  /** One check with the bank; reschedules itself until a final answer. */
  async pollCliq(job: RideFarePollJob): Promise<void> {
    const payment = await this.paymentRepo.findOne({
      where: { id: job.paymentId },
    });
    if (!payment || payment.status !== 'pending') return;

    const code = await this.inquire(payment);
    if (code === '0' || code === '000') {
      await this.onCliqPaid(payment);
      return;
    }
    // Only "0" is final at uWallet: 300/310 have been seen turning into 0
    // after a late approval, so nothing short of the window running out
    // counts as a failure.
    if (job.attempt >= RIDE_FARE_POLL_ATTEMPTS) {
      payment.status = 'rejected';
      payment.adminNote = `[ride-fare] last StatusCode=${code || 'n/a'}`;
      await this.paymentRepo.save(payment);
      const booking = await this.bookingRepo.findOne({
        where: { id: payment.bookingId! },
      });
      if (booking && booking.paymentStatus === 'requested') {
        await this.markFailed(booking, code || 'timeout');
      }
      return;
    }
    await this.schedulePoll({ ...job, attempt: job.attempt + 1 });
  }

  private async inquire(payment: PaymentEntity): Promise<string> {
    try {
      const inquiry = await this.cliq.paymentInquiry(payment.transactionId!);
      return String(inquiry.StatusCode ?? '').trim();
    } catch (err) {
      this.logger.warn(
        `Ride fare inquiry ${payment.id} failed: ${(err as Error).message}`,
      );
      return '';
    }
  }

  /** The bank confirmed: the fare is paid and the driver's wallet credited. */
  private async onCliqPaid(payment: PaymentEntity): Promise<void> {
    // Keep pending until ledger settlement succeeds, so the poll can retry safely.
    await this.wallet.settleCollectedFare(payment.bookingId!, 'cliq');
    payment.status = 'approved';
    await this.paymentRepo.save(payment);

    const booking = await this.bookingRepo.findOne({
      where: { id: payment.bookingId! },
    });
    const trip = booking
      ? await this.tripRepo.findOne({ where: { id: booking.tripId } })
      : null;
    if (!booking || !trip) return;

    if (booking.paymentStatus !== 'paid') {
      booking.paymentStatus = 'paid';
      booking.settledAt = new Date();
      await this.bookingRepo.save(booking);
    }
    await this.push(booking.userId, {
      title: 'تم الدفع',
      body: 'وصلنا مبلغ الرحلة عبر CliQ. شكراً لك!',
      type: 'ride_payment_paid',
      data: { tripId: trip.id, bookingId: booking.id },
    });
    await this.push(trip.driverId, {
      title: 'أُضيفت الأجرة إلى محفظتك',
      body: `${booking.totalAmount} ${trip.currency} من رحلة دُفعت عبر CliQ.`,
      type: 'ride_fare_credited',
      data: { tripId: trip.id, bookingId: booking.id },
    });
  }

  private async markFailed(booking: BookingEntity, reason: string) {
    booking.paymentStatus = 'failed';
    await this.bookingRepo.save(booking);
    this.logger.warn(`Ride fare for booking ${booking.id} failed (${reason})`);
    await this.push(booking.userId, {
      title: 'لم يكتمل الدفع عبر CliQ',
      body: 'أعد إرسال طلب الدفع أو ادفع للسائق نقداً.',
      type: 'ride_payment_failed',
      data: { tripId: booking.tripId, bookingId: booking.id },
    });
  }

  // ── Passenger ─────────────────────────────────────────────────────────────

  /** The passenger's own fare on a trip, for their end-of-trip screen. */
  async getMine(tripId: string, passengerId: string): Promise<RidePaymentView> {
    const booking = await this.bookingRepo.findOne({
      where: {
        tripId,
        userId: passengerId,
        status: In([
          BookingStatus.COMPLETED,
          BookingStatus.IN_PROGRESS,
          BookingStatus.CONFIRMED,
        ]),
      },
      order: { createdAt: 'DESC' },
    });
    if (!booking) throw new NotFoundException('لا يوجد حجز لك في هذه الرحلة.');
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    return this.toView(booking, trip?.currency ?? 'JOD', null);
  }

  /** CliQ failed or was ignored: send the request again. */
  async retryCliq(bookingId: string, passengerId: string, payerAlias?: string) {
    const booking = await this.ownBooking(bookingId, passengerId);
    if (
      booking.paymentMethod !== 'cliq' ||
      booking.paymentStatus !== 'failed'
    ) {
      throw new ConflictException('لا يوجد دفع فاشل لإعادة إرساله.');
    }
    if (payerAlias) {
      const payer = parseCliqPayer(payerAlias);
      if (!payer) {
        throw new BadRequestException('اسم CliQ أو رقم الجوال غير صحيح.');
      }
      booking.payerCliqAlias = payer.value;
    }
    await this.requestCliq(booking);
    return this.getMine(booking.tripId, passengerId);
  }

  /** Give up on CliQ and hand the driver cash; the driver then confirms. */
  async switchToCash(bookingId: string, passengerId: string) {
    const booking = await this.ownBooking(bookingId, passengerId);
    if (
      booking.paymentMethod !== 'cliq' ||
      !['failed', 'requested'].includes(booking.paymentStatus)
    ) {
      throw new ConflictException('لا يمكن تغيير طريقة الدفع الآن.');
    }
    if (booking.passengerPaymentId) {
      const outstanding = await this.paymentRepo.findOne({
        where: { id: booking.passengerPaymentId },
      });
      // One last look first: an approval that just landed must not be paid
      // a second time in cash.
      if (outstanding?.status === 'pending') {
        const code = await this.inquire(outstanding);
        if (code === '0' || code === '000') {
          await this.onCliqPaid(outstanding);
          return this.getMine(booking.tripId, passengerId);
        }
        outstanding.status = 'rejected';
        outstanding.adminNote = 'Passenger switched to cash';
        await this.paymentRepo.save(outstanding);
      }
    }
    booking.paymentMethod = 'cash';
    booking.paymentStatus = 'pending';
    await this.bookingRepo.save(booking);

    const trip = await this.tripRepo.findOne({ where: { id: booking.tripId } });
    if (trip) {
      await this.push(trip.driverId, {
        title: 'الراكب سيدفع نقداً',
        body: `حصّل ${booking.totalAmount} ${trip.currency} نقداً وأكّد الاستلام.`,
        type: 'ride_payment_cash_switch',
        data: { tripId: trip.id, bookingId: booking.id },
      });
    }
    return this.getMine(booking.tripId, passengerId);
  }

  // ── Driver ────────────────────────────────────────────────────────────────

  /** Every rider's fare on the driver's trip, for the trip summary. */
  async getForTrip(
    tripId: string,
    driverId: string,
  ): Promise<RidePaymentView[]> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('الرحلة غير موجودة.');
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('هذه الرحلة ليست لك.');
    }
    const bookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.COMPLETED },
      relations: ['user'],
      order: { createdAt: 'ASC' },
    });
    return bookings.map((b) =>
      this.toView(b, trip.currency, b.user?.name ?? null),
    );
  }

  /**
   * Cash fare: the driver was paid, or the passenger didn't pay — which files
   * a payment complaint. Either answer releases the passenger. The first
   * answer stands.
   */
  async confirmCash(
    bookingId: string,
    driverId: string,
    dto: { received: boolean; note?: string },
  ): Promise<RidePaymentView> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['user'],
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود.');
    const trip = await this.tripRepo.findOne({ where: { id: booking.tripId } });
    if (!trip || trip.driverId !== driverId) {
      throw new ForbiddenException('هذه الرحلة ليست لك.');
    }
    if (booking.status !== BookingStatus.COMPLETED) {
      throw new ConflictException('أنهِ الرحلة أولاً ثم أكّد الدفع.');
    }
    if (['paid', 'disputed'].includes(booking.paymentStatus)) {
      return this.toView(booking, trip.currency, booking.user?.name ?? null);
    }
    if (booking.paymentMethod !== 'cash') {
      throw new ConflictException(
        'هذا الراكب يدفع عبر CliQ — ستصلك الأجرة في محفظتك عند اكتمال الدفع.',
      );
    }

    const now = new Date();
    if (dto.received) {
      await this.wallet.chargeCompletedTripCommission(trip.id);
      booking.paymentStatus = 'paid';
      booking.settledAt = now;
    } else {
      booking.paymentStatus = 'disputed';
      booking.paymentDisputedAt = now;
    }
    await this.bookingRepo.save(booking);

    if (!dto.received) {
      await this.complaints
        .create(driverId, {
          againstUserId: booking.userId,
          tripId: trip.id,
          bookingId: booking.id,
          category: 'payment',
          body: dto.note?.trim() || 'لم يدفع الراكب أجرة الرحلة.',
        })
        .catch((err: Error) =>
          this.logger.warn(
            `Failed to file non-payment complaint: ${err.message}`,
          ),
        );
    }

    await this.push(
      booking.userId,
      dto.received
        ? {
            title: 'تم تأكيد الدفع',
            body: 'شكراً لك! أكّد السائق استلام الأجرة.',
            type: 'ride_payment_paid',
            data: { tripId: trip.id, bookingId: booking.id },
          }
        : {
            title: 'لم يُسجَّل الدفع',
            body: 'أبلغ السائق أنه لم يستلم الأجرة. سيتواصل معك فريق VisionWay.',
            type: 'ride_payment_disputed',
            data: { tripId: trip.id, bookingId: booking.id },
          },
    );
    return this.toView(booking, trip.currency, booking.user?.name ?? null);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private async ownBooking(bookingId: string, passengerId: string) {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود.');
    if (booking.userId !== passengerId) {
      throw new ForbiddenException('هذا الحجز ليس لك.');
    }
    return booking;
  }

  private toView(
    booking: BookingEntity,
    currency: string,
    passengerName: string | null,
  ): RidePaymentView {
    return {
      bookingId: booking.id,
      tripId: booking.tripId,
      passengerId: booking.userId,
      passengerName,
      amount: booking.totalAmount,
      originalAmount: booking.originalAmount ?? booking.totalAmount,
      discountAmount: booking.discountAmount ?? '0.00',
      promoCode: booking.promoCode ?? null,
      currency,
      method: booking.paymentMethod ?? 'cash',
      status: (booking.paymentStatus ?? 'pending') as PaymentStatus,
      payerCliqAlias: booking.payerCliqAlias,
      paidAt: booking.settledAt,
      disputedAt: booking.paymentDisputedAt,
    };
  }

  private async push(
    userId: string,
    payload: {
      title: string;
      body: string;
      type: string;
      data: Record<string, unknown>;
    },
  ) {
    await this.notifications.sendPush(userId, payload).catch(() => undefined);
  }
}
