import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  RefundRequestEntity,
  RefundRequestStatus,
} from '../../database/entities/refund-request.entity';

export interface CreateRefundRequestDto {
  bookingId?: string;
  amount?: string;
  currency?: string;
  reason: string;
}

export interface AdminUpdateRefundDto {
  status: 'contacted' | 'resolved' | 'rejected';
  adminNotes?: string;
}

export interface ListRefundsQuery {
  status?: string;
  limit?: number;
  offset?: number;
}

const SUPPORT_WHATSAPP_E164 = (): string =>
  process.env.SUPPORT_WHATSAPP_E164 ?? '+962788883007';

const SUPPORT_WHATSAPP_NUMBER = (): string =>
  SUPPORT_WHATSAPP_E164().replace(/^\+/, ''); // strip leading +

/**
 * RefundsService — T169 / T170 (Phase 8 / US6)
 *
 * POST /refund-requests:
 *   Creates a `refund_requests` row (status='open', whatsappContactedAt=now)
 *   and returns a pre-filled WhatsApp deep-link.
 *
 * Admin endpoints (GET/PATCH /admin/refund-requests):
 *   Admin queue management.  Actual refund processing is off-platform
 *   (via WhatsApp); this service only tracks the record.
 */
@Injectable()
export class RefundsService {
  constructor(
    @InjectRepository(RefundRequestEntity)
    private readonly refundRepo: Repository<RefundRequestEntity>,
  ) {}

  /** T169 — User submits a refund request. Returns the row + WA deep-link. */
  async create(
    userId: string,
    dto: CreateRefundRequestDto,
  ): Promise<{ refundRequest: RefundRequestEntity; whatsappDeepLink: string }> {
    const now = new Date();

    const refundRequest = await this.refundRepo.save(
      this.refundRepo.create({
        userId,
        bookingId: dto.bookingId ?? null,
        amount: dto.amount ?? null,
        currency: dto.currency ?? 'JOD',
        reason: dto.reason,
        status: RefundRequestStatus.OPEN,
        whatsappContactedAt: now,
      }),
    );

    const whatsappDeepLink = this._buildDeepLink(refundRequest, userId);

    return { refundRequest, whatsappDeepLink };
  }

  /** T170a — Admin listing. */
  async listForAdmin(query: ListRefundsQuery): Promise<{
    refundRequests: RefundRequestEntity[];
    total: number;
  }> {
    const qb = this.refundRepo
      .createQueryBuilder('r')
      .orderBy('r.createdAt', 'DESC')
      .take(query.limit ?? 50)
      .skip(query.offset ?? 0);

    if (query.status) {
      qb.andWhere('r.status = :status', { status: query.status });
    }

    const [refundRequests, total] = await qb.getManyAndCount();
    return { refundRequests, total };
  }

  /** T170b — Admin status update. */
  async adminUpdate(
    refundId: string,
    adminId: string,
    dto: AdminUpdateRefundDto,
  ): Promise<RefundRequestEntity> {
    const refund = await this.refundRepo.findOne({ where: { id: refundId } });
    if (!refund) throw new NotFoundException('Refund request not found');

    refund.status = dto.status as RefundRequestStatus;
    if (dto.adminNotes) refund.adminNotes = dto.adminNotes;

    if (dto.status === 'resolved' || dto.status === 'rejected') {
      refund.resolvedByAdminId = adminId;
      refund.resolvedAt = new Date();
    }

    return this.refundRepo.save(refund);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  private _buildDeepLink(refund: RefundRequestEntity, userId: string): string {
    const userRef = userId.slice(-6);
    const bookingRef = refund.bookingId
      ? `Booking: ${refund.bookingId.slice(-8)}`
      : 'No booking ref';
    const amountPart = refund.amount
      ? `Amount: ${refund.amount} ${refund.currency}`
      : '';

    const prefill = [
      'Hi, I would like to request a refund.',
      bookingRef,
      amountPart,
      `Reason: ${refund.reason}`,
      `Ref: ${userRef}`,
    ]
      .filter(Boolean)
      .join('\n');

    const encoded = encodeURIComponent(prefill);
    return `https://wa.me/${SUPPORT_WHATSAPP_NUMBER()}?text=${encoded}`;
  }
}
