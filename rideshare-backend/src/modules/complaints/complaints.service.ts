import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  ComplaintEntity,
  ComplaintStatus,
} from '../../database/entities/complaint.entity';
import { NotificationsService } from '../notifications/notifications.service';

export interface CreateComplaintDto {
  againstUserId?: string;
  tripId?: string;
  bookingId?: string;
  category: string;
  body: string;
}

export interface AdminUpdateComplaintDto {
  status: ComplaintStatus;
  adminNotes?: string;
}

export interface ListComplaintsQuery {
  status?: string;
  category?: string;
  from?: string;
  to?: string;
  cursor?: string;
  limit?: number;
}

/**
 * ComplaintsService — T167 / T168 (Phase 8 / US6)
 *
 * Handles the full lifecycle of user complaints:
 *  - POST /complaints (user files a complaint)
 *  - GET /me/complaints (user lists their filed complaints)
 *  - GET /admin/complaints (admin filtered queue)
 *  - PATCH /admin/complaints/:id (admin resolves/rejects + notifies reporter)
 */
@Injectable()
export class ComplaintsService {
  constructor(
    @InjectRepository(ComplaintEntity)
    private readonly complaintRepo: Repository<ComplaintEntity>,

    private readonly notificationsService: NotificationsService,
  ) {}

  /** T167a — User files a complaint. At least one target field is required. */
  async create(
    reporterId: string,
    dto: CreateComplaintDto,
  ): Promise<ComplaintEntity> {
    if (!dto.againstUserId && !dto.tripId && !dto.bookingId) {
      throw new BadRequestException(
        'At least one of againstUserId, tripId, or bookingId is required',
      );
    }

    const complaint = this.complaintRepo.create({
      reporterId,
      againstUserId: dto.againstUserId ?? null,
      tripId: dto.tripId ?? null,
      bookingId: dto.bookingId ?? null,
      category: dto.category as any,
      body: dto.body,
      status: ComplaintStatus.OPEN,
    });

    return this.complaintRepo.save(complaint);
  }

  /** T167b — List complaints filed by the caller. */
  async listMine(reporterId: string): Promise<ComplaintEntity[]> {
    return this.complaintRepo.find({
      where: { reporterId },
      order: { createdAt: 'DESC' },
    });
  }

  /** T168a — Admin filtered listing with cursor pagination. */
  async listForAdmin(query: ListComplaintsQuery): Promise<{
    complaints: ComplaintEntity[];
    total: number;
  }> {
    const qb = this.complaintRepo
      .createQueryBuilder('c')
      .orderBy('c.createdAt', 'DESC')
      .take(query.limit ?? 50);

    if (query.status) {
      qb.andWhere('c.status = :status', { status: query.status });
    }
    if (query.category) {
      qb.andWhere('c.category = :category', { category: query.category });
    }
    if (query.from) {
      qb.andWhere('c.createdAt >= :from', { from: new Date(query.from) });
    }
    if (query.to) {
      qb.andWhere('c.createdAt <= :to', { to: new Date(query.to) });
    }
    if (query.cursor) {
      qb.andWhere(
        'c.createdAt < (SELECT "createdAt" FROM complaints WHERE id = :cursor)',
        {
          cursor: query.cursor,
        },
      );
    }

    const [complaints, total] = await qb.getManyAndCount();
    return { complaints, total };
  }

  /** T168b — Admin updates a complaint status and optionally adds notes. */
  async adminUpdate(
    complaintId: string,
    adminId: string,
    dto: AdminUpdateComplaintDto,
  ): Promise<ComplaintEntity> {
    const complaint = await this.complaintRepo.findOne({
      where: { id: complaintId },
    });
    if (!complaint) throw new NotFoundException('Complaint not found');

    const prevStatus = complaint.status;
    complaint.status = dto.status;
    if (dto.adminNotes) complaint.adminNotes = dto.adminNotes;

    const isDecision =
      dto.status === ComplaintStatus.RESOLVED ||
      dto.status === ComplaintStatus.REJECTED;

    if (isDecision) {
      complaint.resolvedByAdminId = adminId;
      complaint.resolvedAt = new Date();
    }

    const saved = await this.complaintRepo.save(complaint);

    // Notify the reporter when their complaint is resolved or rejected
    if (isDecision && prevStatus !== dto.status) {
      const isResolved = dto.status === ComplaintStatus.RESOLVED;
      try {
        await this.notificationsService.sendPush(complaint.reporterId, {
          title: isResolved ? 'Complaint Resolved' : 'Complaint Update',
          body: isResolved
            ? 'Your complaint has been reviewed and resolved.'
            : 'Your complaint could not be actioned at this time.',
          type: `complaint_${dto.status}`,
          data: { screen: 'complaints', complaintId },
        });
      } catch {
        // Non-fatal: notification failure must not roll back the status update
      }
    }

    return saved;
  }
}
