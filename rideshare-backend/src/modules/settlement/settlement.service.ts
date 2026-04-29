import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';
import {
  SettlementAuditEntity,
  SettlementAuditAction,
} from '../../database/entities/settlement-audit.entity';
import { CallSessionEntity } from '../../database/entities/call-session.entity';
import { ChatRoomEntity } from '../../database/entities/chat-room.entity';
import { MessageEntity } from '../../database/entities/message.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { ErrorCodes } from '../../common/errors/error-codes';

const GRACE_PERIOD_MS = 5 * 60 * 1000; // 5 minutes

@Injectable()
export class SettlementService {
  private readonly logger = new Logger(SettlementService.name);

  constructor(
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectRepository(SettlementAuditEntity)
    private auditRepo: Repository<SettlementAuditEntity>,
    @InjectRepository(CallSessionEntity)
    private callSessionRepo: Repository<CallSessionEntity>,
    @InjectRepository(ChatRoomEntity)
    private chatRoomRepo: Repository<ChatRoomEntity>,
    @InjectRepository(MessageEntity)
    private messageRepo: Repository<MessageEntity>,
    private notificationsService: NotificationsService,
  ) {}

  async markPaid(bookingId: string, actorId: string): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip'],
    });
    if (!booking) throw new NotFoundException('Booking not found');

    if (booking.trip.driverId !== actorId) {
      throw new ForbiddenException({
        statusCode: 403,
        code: ErrorCodes.NOT_TRIP_DRIVER,
        message: 'Only the trip driver may mark this booking as paid',
      });
    }

    if (booking.status !== BookingStatus.CONFIRMED) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.BOOKING_NOT_CONFIRMED,
        message: 'Booking must be in confirmed state before marking as paid',
      });
    }

    if (booking.settledAt !== null) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.ALREADY_SETTLED,
        message: 'This booking has already been marked as paid',
      });
    }

    const now = new Date();
    booking.settledAt = now;
    booking.settlementGraceUntil = new Date(now.getTime() + GRACE_PERIOD_MS);
    const saved = await this.bookingRepo.save(booking);

    await this.auditRepo.save(
      this.auditRepo.create({
        bookingId,
        action: SettlementAuditAction.MARK_PAID,
        actorId,
        reason: null,
      }),
    );

    // Notify passenger
    try {
      await this.notificationsService.create({
        userId: booking.userId,
        type: 'settlement_marked_paid',
        title: 'تم تأكيد الدفع',
        body: 'قام السائق بتأكيد استلام المبلغ. يمكنك الآن التواصل معه.',
        data: { bookingId },
      });
    } catch (err) {
      this.logger.warn(`Failed to send mark-paid notification: ${err.message}`);
    }

    this.logger.log(`Booking ${bookingId} marked as paid by driver ${actorId}`);
    return saved;
  }

  async unmarkPaid(bookingId: string, actorId: string): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip'],
    });
    if (!booking) throw new NotFoundException('Booking not found');

    if (booking.trip.driverId !== actorId) {
      throw new ForbiddenException({
        statusCode: 403,
        code: ErrorCodes.NOT_TRIP_DRIVER,
        message: 'Only the trip driver may unmark this booking',
      });
    }

    // Grace window check
    const now = new Date();
    if (!booking.settlementGraceUntil || now >= booking.settlementGraceUntil) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.GRACE_EXPIRED,
        message:
          'The 5-minute grace window to reverse this settlement has expired',
      });
    }

    // Contact-already-used checks
    const callUsed = await this.callSessionRepo.findOne({
      where: { bookingId },
    });
    if (callUsed) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.CONTACT_ALREADY_USED,
        message: 'A call has already been made — settlement cannot be reversed',
      });
    }

    const room = await this.chatRoomRepo.findOne({
      where: { tripId: booking.tripId, passengerId: booking.userId },
    });
    if (room) {
      const msgCount = await this.messageRepo.count({
        where: { chatRoomId: room.id },
      });
      if (msgCount > 0) {
        throw new ConflictException({
          statusCode: 409,
          code: ErrorCodes.CONTACT_ALREADY_USED,
          message:
            'A chat message has already been sent — settlement cannot be reversed',
        });
      }
    }

    booking.settledAt = null;
    booking.settlementGraceUntil = null;
    const saved = await this.bookingRepo.save(booking);

    await this.auditRepo.save(
      this.auditRepo.create({
        bookingId,
        action: SettlementAuditAction.UNMARK_PAID,
        actorId,
        reason: null,
      }),
    );

    this.logger.log(`Booking ${bookingId} un-marked by driver ${actorId}`);
    return saved;
  }

  async adminRevert(
    bookingId: string,
    actorId: string,
    reason: string,
  ): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    booking.settledAt = null;
    booking.settlementGraceUntil = null;
    const saved = await this.bookingRepo.save(booking);

    await this.auditRepo.save(
      this.auditRepo.create({
        bookingId,
        action: SettlementAuditAction.ADMIN_REVERT,
        actorId,
        reason,
      }),
    );

    this.logger.log(
      `Booking ${bookingId} settlement reverted by admin ${actorId}: ${reason}`,
    );
    return saved;
  }

  async getAuditTrail(bookingId: string): Promise<SettlementAuditEntity[]> {
    return this.auditRepo.find({
      where: { bookingId },
      order: { createdAt: 'ASC' },
      relations: ['actor'],
    });
  }
}
