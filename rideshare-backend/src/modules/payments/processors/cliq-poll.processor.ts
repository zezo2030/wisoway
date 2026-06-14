/**
 * CliqPollProcessor
 *
 * بيكمل الاستعلام عن حالة معاملات CliQ اللي ما وصلتش لـ StatusCode=0 خلال
 * النافذة الأولى (الـ ~2 دقيقة الأولى داخل purchaseAndAwait).
 *
 * منطق الـ retry:
 *   - بنحاول كل بضع دقائق (intervalSeconds في الـ job data)
 *   - بنوقف لما:
 *     * StatusCode=0 → نشحن المحفظة، status='approved'
 *     * نوصل لـ maxAttempts → status='rejected' (timeout بعد ~24 ساعة)
 *     * المعاملة بقت في status نهائي بالفعل (مثلاً admin غيرها) → no-op
 */
import { Processor, Process, OnQueueFailed } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PaymentEntity } from '../../../database/entities/payment.entity';
import { UserEntity } from '../../../database/entities/user.entity';
import {
  PgUserRole,
  WalletAccountType,
} from '../../../database/entities';
import { A2aCliqService } from '../a2a-cliq.service';
import { WalletService } from '../../wallet/wallet.service';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';

export const CLIQ_POLL_QUEUE = 'cliq-poll';
export const CLIQ_POLL_JOB = 'poll-cliq-payment';

export interface CliqPollJobData {
  paymentId: string;
  messageTrxId: string;
  attempt: number; // 1-based
  maxAttempts: number; // مثلاً 144 محاولة كل 10 دقائق = 24 ساعة
  intervalSeconds: number; // المدة الفاصلة بين كل محاولة
}

@Processor(CLIQ_POLL_QUEUE)
export class CliqPollProcessor {
  private readonly logger = new Logger(CliqPollProcessor.name);

  constructor(
    @InjectRepository(PaymentEntity)
    private paymentRepo: Repository<PaymentEntity>,
    @InjectRepository(UserEntity)
    private userRepo: Repository<UserEntity>,
    private a2aCliqService: A2aCliqService,
    private walletService: WalletService,
    @InjectQueue(CLIQ_POLL_QUEUE) private cliqPollQueue: Queue<CliqPollJobData>,
  ) {}

  @Process(CLIQ_POLL_JOB)
  async handlePoll(job: Job<CliqPollJobData>): Promise<void> {
    const { paymentId, messageTrxId, attempt, maxAttempts, intervalSeconds } =
      job.data;

    const payment = await this.paymentRepo.findOne({
      where: { id: paymentId },
    });
    if (!payment) {
      this.logger.warn(`Payment ${paymentId} not found — stopping polling`);
      return;
    }

    // لو حد غيّر الحالة بالفعل (admin أو callback أو محاولة سابقة)، no-op
    if (payment.status !== 'pending') {
      this.logger.log(
        `Payment ${paymentId} already in status "${payment.status}" — stopping polling`,
      );
      return;
    }

    let inquiry;
    try {
      inquiry = await this.a2aCliqService.paymentInquiry(messageTrxId);
    } catch (err) {
      this.logger.warn(
        `Inquiry failed (attempt ${attempt}/${maxAttempts}) for payment ${paymentId}: ${err instanceof Error ? err.message : String(err)}`,
      );
      // لو الـ inquiry فشل (network/auth)، نجدول محاولة جديدة لو فيه محاولات متبقية
      await this.scheduleNextOrFail(
        payment,
        job.data,
        'inquiry-error',
      );
      return;
    }

    const statusCode = String(inquiry.StatusCode ?? '').trim();

    // حالة النجاح المؤكد
    if (statusCode === '0' || statusCode === '000') {
      await this.creditAndApprove(payment, inquiry.MSGID ?? undefined);
      this.logger.log(
        `✅ Payment ${paymentId} succeeded after ${attempt} background polls`,
      );
      return;
    }

    // لسه pending — نجدول محاولة جديدة أو نوقف لو خلصت المحاولات
    await this.scheduleNextOrFail(
      payment,
      job.data,
      `StatusCode=${statusCode}`,
    );
  }

  /**
   * يجدول المحاولة التالية لو فيه محاولات متبقية، وإلا يعتبرها مرفوضة (timeout).
   */
  private async scheduleNextOrFail(
    payment: PaymentEntity,
    jobData: CliqPollJobData,
    reason: string,
  ): Promise<void> {
    const { paymentId, messageTrxId, attempt, maxAttempts, intervalSeconds } =
      jobData;

    if (attempt >= maxAttempts) {
      payment.status = 'rejected';
      payment.adminNote =
        `[CliQ-poll-timeout] last reason: ${reason} after ${attempt} attempts`.slice(
          0,
          500,
        );
      await this.paymentRepo.save(payment);
      this.logger.warn(
        `⏱ Payment ${paymentId} rejected — exhausted ${maxAttempts} polling attempts (${reason})`,
      );
      return;
    }

    await this.cliqPollQueue.add(
      CLIQ_POLL_JOB,
      {
        paymentId,
        messageTrxId,
        attempt: attempt + 1,
        maxAttempts,
        intervalSeconds,
      },
      {
        delay: intervalSeconds * 1000,
        removeOnComplete: true,
        removeOnFail: false,
      },
    );

    this.logger.log(
      `↻ Payment ${paymentId} re-scheduled (attempt ${attempt + 1}/${maxAttempts} in ${intervalSeconds}s, reason=${reason})`,
    );
  }

  /**
   * يشحن المحفظة ويعلّم المعاملة كـ approved.
   * Idempotent عبر idempotencyKey في creditPostedTopup.
   */
  private async creditAndApprove(
    payment: PaymentEntity,
    msgId?: string,
  ): Promise<void> {
    if (msgId) payment.paymentGatewayRef = msgId;

    const user = await this.userRepo.findOne({
      where: { id: payment.userId },
    });
    if (!user) {
      this.logger.error(
        `Cannot credit payment ${payment.id}: user ${payment.userId} not found`,
      );
      payment.status = 'rejected';
      payment.adminNote = 'CliQ approved but user not found';
      await this.paymentRepo.save(payment);
      return;
    }

    const accountType =
      user.role === PgUserRole.DRIVER
        ? WalletAccountType.DRIVER
        : WalletAccountType.RIDER;

    try {
      await this.walletService.creditPostedTopup({
        userId: payment.userId,
        accountType,
        amount: Number(payment.amount),
        currency: payment.currency ?? 'JOD',
        idempotencyKey: `cliq-topup:${payment.id}`,
        note: `CliQ A2A wallet top-up ${payment.id} (background-poll)`,
      });
      payment.status = 'approved';
      await this.paymentRepo.save(payment);
    } catch (creditErr) {
      this.logger.error(
        `Wallet credit failed for payment ${payment.id} after CliQ success: ${creditErr instanceof Error ? creditErr.message : String(creditErr)}`,
      );
      // ساب الـ status على pending عشان admin يقدر يحلها يدوياً
      payment.adminNote =
        `CliQ succeeded but wallet credit failed: ${creditErr instanceof Error ? creditErr.message : String(creditErr)}`.slice(
          0,
          500,
        );
      await this.paymentRepo.save(payment);
    }
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `cliq-poll job ${job.id} failed for payment ${job.data?.paymentId}: ${error.message}`,
      error.stack,
    );
  }
}
