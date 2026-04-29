import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BookingEntity } from '../../database/entities/booking.entity';
import {
  CallSessionEntity,
  CallSessionStatus,
} from '../../database/entities/call-session.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { ProxyPoolService } from './proxy-pool.service';
import { ErrorCodes } from '../../common/errors/error-codes';

const SESSION_EXPIRY_MINUTES = 60;

@Injectable()
export class CallsService {
  private readonly logger = new Logger(CallsService.name);

  constructor(
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectRepository(CallSessionEntity)
    private callSessionRepo: Repository<CallSessionEntity>,
    @InjectRepository(UserEntity)
    private userRepo: Repository<UserEntity>,
    private proxyPoolService: ProxyPoolService,
  ) {}

  async initiate(
    bookingId: string,
    callerId: string,
  ): Promise<{
    callSessionId: string;
    proxyNumberE164: string;
    expiresAt: string;
  }> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip'],
    });
    if (!booking) throw new NotFoundException('Booking not found');

    // Must be settled
    if (!booking.settledAt) {
      throw new ForbiddenException({
        statusCode: 403,
        code: ErrorCodes.BOOKING_NOT_SETTLED,
        message:
          'Calls are only available after the driver marks the booking as paid',
      });
    }

    // Must be a participant (passenger or driver)
    const isPassenger = booking.userId === callerId;
    const isDriver = booking.trip.driverId === callerId;
    if (!isPassenger && !isDriver) {
      throw new ForbiddenException('You are not a participant in this booking');
    }

    const calleeId = isDriver ? booking.userId : booking.trip.driverId;

    const caller = await this.userRepo.findOne({ where: { id: callerId } });
    const callee = await this.userRepo.findOne({ where: { id: calleeId } });

    if (!caller || !callee) throw new NotFoundException('User not found');

    const proxyNumber = await this.proxyPoolService.allocate(bookingId);

    const expiresAt = new Date(Date.now() + SESSION_EXPIRY_MINUTES * 60 * 1000);

    const session = await this.callSessionRepo.save(
      this.callSessionRepo.create({
        bookingId,
        callerUserId: callerId,
        calleeUserId: calleeId,
        proxyNumber,
        callerRealNumber: caller.phoneNumber,
        calleeRealNumber: callee.hidePhoneNumber ? null : callee.phoneNumber,
        status: CallSessionStatus.INITIATED,
      }),
    );

    this.logger.log(
      `Call session ${session.id} initiated for booking ${bookingId}`,
    );

    return {
      callSessionId: session.id,
      proxyNumberE164: proxyNumber,
      expiresAt: expiresAt.toISOString(),
    };
  }

  async handleTwilioWebhook(body: {
    CallSid?: string;
    CallStatus?: string;
    CallDuration?: string;
  }): Promise<void> {
    const { CallSid, CallStatus, CallDuration } = body;

    if (!CallSid) return; // nothing to update

    const session = await this.callSessionRepo.findOne({
      where: { twilioCallSid: CallSid },
    });

    if (!session) {
      // Unknown CallSid — idempotent; Twilio may retry
      this.logger.warn(`Twilio webhook: unknown CallSid ${CallSid}`);
      return;
    }

    const terminalStatuses = new Set([
      'completed',
      'failed',
      'busy',
      'no-answer',
      'canceled',
    ]);

    if (CallStatus === 'in-progress') {
      session.status = CallSessionStatus.IN_PROGRESS;
      session.startedAt = new Date();
    } else if (terminalStatuses.has(CallStatus ?? '')) {
      session.status =
        CallStatus === 'completed'
          ? CallSessionStatus.COMPLETED
          : CallSessionStatus.FAILED;
      session.endedAt = new Date();
      session.durationSeconds = CallDuration
        ? parseInt(CallDuration, 10)
        : null;
      session.terminationReason = CallStatus ?? null;
    }

    await this.callSessionRepo.save(session);
    this.logger.log(
      `Call session ${session.id} updated: status=${session.status}`,
    );
  }
}
