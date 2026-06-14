import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, Repository } from 'typeorm';
import {
  PendingChargeEntity,
  PendingChargeKind,
  PendingChargeStatus,
} from '../../database/entities/pending-charge.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { PgUserRole } from '../../database/entities/shared.enums';
import { PendingChargesService } from '../pending-charges/pending-charges.service';
import { NotificationsService } from '../notifications/notifications.service';

export interface CreateFineParams {
  driverId: string;
  amount: number;
  reason: string;
  tripId?: string | null;
  bookingId?: string | null;
}

export interface ListFinesQuery {
  status?: PendingChargeStatus;
  driverId?: string;
  from?: string;
  to?: string;
  page?: number;
  limit?: number;
}

/**
 * AdminFinesService — manually-issued penalty charges against drivers.
 * Re-uses PendingChargeEntity (kind=DRIVER_NO_SHOW) and PendingChargesService
 * for the wallet-deduction flow.
 */
@Injectable()
export class AdminFinesService {
  private readonly logger = new Logger(AdminFinesService.name);

  constructor(
    @InjectRepository(PendingChargeEntity)
    private readonly chargeRepo: Repository<PendingChargeEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    private readonly pendingChargesService: PendingChargesService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(
    adminId: string,
    params: CreateFineParams,
  ): Promise<PendingChargeEntity> {
    if (!Number.isFinite(params.amount) || params.amount <= 0) {
      throw new BadRequestException('amount must be a positive number');
    }
    if (!params.reason || params.reason.trim().length === 0) {
      throw new BadRequestException('reason is required');
    }

    const driver = await this.userRepo.findOne({
      where: { id: params.driverId },
    });
    if (!driver) throw new NotFoundException('Driver not found');
    if (driver.role !== PgUserRole.DRIVER) {
      throw new BadRequestException('Target user is not a driver');
    }

    const created = await this.pendingChargesService.record({
      userId: params.driverId,
      kind: PendingChargeKind.DRIVER_NO_SHOW,
      amount: params.amount,
      bookingId: params.bookingId ?? null,
      tripId: params.tripId ?? null,
    });

    created.reason = params.reason.trim();
    created.createdByAdminId = adminId;
    await this.chargeRepo.save(created);

    this.notificationsService
      .create({
        userId: params.driverId,
        type: 'driver_fine_issued',
        title: 'تم إصدار غرامة',
        body: `تم إصدار غرامة بقيمة ${params.amount.toFixed(2)}. السبب: ${created.reason}`,
        data: { fineId: created.id, amount: params.amount },
      })
      .catch((err: Error) =>
        this.logger.warn(`Failed to notify driver of fine: ${err.message}`),
      );

    return created;
  }

  async list(query: ListFinesQuery): Promise<{
    data: Array<
      PendingChargeEntity & {
        driver: { id: string; name: string | null; phone: string | null };
      }
    >;
    meta: { page: number; limit: number; total: number; totalPages: number };
  }> {
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, 100);
    const skip = (page - 1) * limit;

    const qb = this.chargeRepo
      .createQueryBuilder('pc')
      .leftJoinAndSelect('pc.user', 'driver')
      .where('pc.kind = :kind', { kind: PendingChargeKind.DRIVER_NO_SHOW })
      .orderBy('pc.createdAt', 'DESC');

    if (query.status) {
      qb.andWhere('pc.status = :status', { status: query.status });
    }
    if (query.driverId) {
      qb.andWhere('pc.userId = :driverId', { driverId: query.driverId });
    }
    if (query.from) {
      qb.andWhere('pc.createdAt >= :from', { from: new Date(query.from) });
    }
    if (query.to) {
      qb.andWhere('pc.createdAt <= :to', { to: new Date(query.to) });
    }

    const [rows, total] = await qb.skip(skip).take(limit).getManyAndCount();

    const data = rows.map((row) => {
      const driver = row.user;
      return Object.assign(row, {
        driver: {
          id: driver?.id ?? row.userId,
          name: driver?.name ?? null,
          phone: driver?.phoneNumber ?? null,
        },
      });
    });

    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async waive(
    fineId: string,
    adminId: string,
  ): Promise<PendingChargeEntity> {
    const charge = await this.chargeRepo.findOne({ where: { id: fineId } });
    if (!charge) throw new NotFoundException('Fine not found');
    if (charge.kind !== PendingChargeKind.DRIVER_NO_SHOW) {
      throw new BadRequestException('Charge is not a driver fine');
    }
    return this.pendingChargesService.waive(fineId, adminId);
  }
}
