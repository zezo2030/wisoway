import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import {
  PayoutRequestEntity,
  TripEntity,
  WalletAccountEntity,
  WalletAccountType,
  WalletEntryDirection,
  PayoutStatus,
  WalletTransactionEntity,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../../database/entities';
import { CreateTopupDto } from './dto/create-topup.dto';
import { CreatePayoutRequestDto } from './dto/create-payout-request.dto';
import { DriverTripChargeDto } from './dto/driver-trip-charge.dto';

@Injectable()
export class WalletService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(WalletAccountEntity)
    private readonly walletAccountRepo: Repository<WalletAccountEntity>,
    @InjectRepository(WalletTransactionEntity)
    private readonly walletTxRepo: Repository<WalletTransactionEntity>,
    @InjectRepository(PayoutRequestEntity)
    private readonly payoutRepo: Repository<PayoutRequestEntity>,
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
  ) {}

  private async getOrCreateAccount(
    userId: string,
    accountType: WalletAccountType,
    currency = 'EGP',
  ) {
    let account = await this.walletAccountRepo.findOne({
      where: { userId, accountType, currency },
    });
    if (!account) {
      account = this.walletAccountRepo.create({
        userId,
        accountType,
        currency,
        balance: '0',
        isActive: true,
      });
      account = await this.walletAccountRepo.save(account);
    }
    return account;
  }

  async getWalletSummary(userId: string, role: string) {
    const accountType =
      role === WalletAccountType.DRIVER
        ? WalletAccountType.DRIVER
        : WalletAccountType.RIDER;
    const account = await this.getOrCreateAccount(userId, accountType);

    return {
      accountId: account.id,
      accountType: account.accountType,
      currency: account.currency,
      balance: Number(account.balance),
      isActive: account.isActive,
    };
  }

  async createTopup(userId: string, role: string, dto: CreateTopupDto) {
    const accountType =
      role === WalletAccountType.DRIVER
        ? WalletAccountType.DRIVER
        : WalletAccountType.RIDER;

    const account = await this.getOrCreateAccount(
      userId,
      accountType,
      dto.currency || 'EGP',
    );

    const existing = dto.idempotencyKey
      ? await this.walletTxRepo.findOne({
          where: { idempotencyKey: dto.idempotencyKey },
        })
      : null;
    if (existing) {
      return existing;
    }

    return this.dataSource.transaction(async (manager) => {
      const locked = await manager.findOne(WalletAccountEntity, {
        where: { id: account.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!locked) {
        throw new NotFoundException('Wallet account not found');
      }

      const amount = dto.amount;
      const current = Number(locked.balance);
      locked.balance = (current + amount).toFixed(2);
      await manager.save(locked);

      const tx = manager.create(WalletTransactionEntity, {
        accountId: locked.id,
        type: WalletTransactionType.TOPUP,
        direction: WalletEntryDirection.CREDIT,
        status: WalletTransactionStatus.POSTED,
        amount: amount.toFixed(2),
        currency: locked.currency,
        idempotencyKey: dto.idempotencyKey ?? null,
        metadata: {
          note: dto.note ?? null,
        },
      });
      return manager.save(tx);
    });
  }

  async chargeDriverForTrip(driverId: string, dto: DriverTripChargeDto) {
    const trip = await this.tripRepo.findOne({
      where: { id: dto.tripId, driverId },
      select: ['id', 'driverId'],
    });
    if (!trip) {
      throw new NotFoundException('Trip not found for this driver');
    }

    const account = await this.getOrCreateAccount(
      driverId,
      WalletAccountType.DRIVER,
      'EGP',
    );
    const fee = 10;

    const existing = dto.idempotencyKey
      ? await this.walletTxRepo.findOne({
          where: { idempotencyKey: dto.idempotencyKey },
        })
      : null;
    if (existing) {
      return existing;
    }

    return this.dataSource.transaction(async (manager) => {
      const locked = await manager.findOne(WalletAccountEntity, {
        where: { id: account.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!locked) {
        throw new NotFoundException('Wallet account not found');
      }

      const current = Number(locked.balance);
      if (current < fee) {
        throw new BadRequestException(
          'Insufficient wallet balance to activate trip',
        );
      }
      locked.balance = (current - fee).toFixed(2);
      await manager.save(locked);

      const tx = manager.create(WalletTransactionEntity, {
        accountId: locked.id,
        type: WalletTransactionType.TRIP_DEBIT,
        direction: WalletEntryDirection.DEBIT,
        status: WalletTransactionStatus.POSTED,
        amount: fee.toFixed(2),
        currency: locked.currency,
        referenceType: 'trip',
        referenceId: dto.tripId,
        idempotencyKey: dto.idempotencyKey ?? null,
      });
      return manager.save(tx);
    });
  }

  async payTripFromRiderWallet(
    riderId: string,
    tripId: string,
    amount: number,
    idempotencyKey?: string,
  ) {
    const riderAccount = await this.getOrCreateAccount(
      riderId,
      WalletAccountType.RIDER,
    );

    const existing = idempotencyKey
      ? await this.walletTxRepo.findOne({
          where: { idempotencyKey },
        })
      : null;
    if (existing) {
      return existing;
    }

    return this.dataSource.transaction(async (manager) => {
      const riderLocked = await manager.findOne(WalletAccountEntity, {
        where: { id: riderAccount.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!riderLocked) {
        throw new NotFoundException('Rider wallet not found');
      }
      if (Number(riderLocked.balance) < amount) {
        throw new BadRequestException('Insufficient rider wallet balance');
      }
      riderLocked.balance = (Number(riderLocked.balance) - amount).toFixed(2);
      await manager.save(riderLocked);

      const debitTx = manager.create(WalletTransactionEntity, {
        accountId: riderLocked.id,
        type: WalletTransactionType.TRIP_PAYMENT,
        direction: WalletEntryDirection.DEBIT,
        status: WalletTransactionStatus.POSTED,
        amount: amount.toFixed(2),
        currency: riderLocked.currency,
        referenceType: 'trip',
        referenceId: tripId,
        idempotencyKey: idempotencyKey ?? null,
      });

      return manager.save(debitTx);
    });
  }

  async createPayoutRequest(driverId: string, dto: CreatePayoutRequestDto) {
    const account = await this.getOrCreateAccount(
      driverId,
      WalletAccountType.DRIVER,
      dto.currency || 'EGP',
    );
    if (Number(account.balance) < dto.amount) {
      throw new BadRequestException('Insufficient wallet balance for payout');
    }

    return this.payoutRepo.save(
      this.payoutRepo.create({
        driverId,
        amount: dto.amount.toFixed(2),
        currency: dto.currency || account.currency,
        status: PayoutStatus.PENDING,
        bankAccountRef: dto.bankAccountRef ?? null,
        note: dto.note ?? null,
      } as Partial<PayoutRequestEntity>),
    );
  }

  async getWalletTransactions(userId: string, role: string, limit = 50) {
    const accountType =
      role === WalletAccountType.DRIVER
        ? WalletAccountType.DRIVER
        : WalletAccountType.RIDER;
    const account = await this.getOrCreateAccount(userId, accountType);
    const transactions = await this.walletTxRepo.find({
      where: { accountId: account.id },
      order: { createdAt: 'DESC' },
      take: Math.min(Math.max(limit, 1), 200),
    });
    return transactions.map((tx) => ({
      id: tx.id,
      type: tx.type,
      direction: tx.direction,
      amount: Number(tx.amount),
      currency: tx.currency,
      referenceType: tx.referenceType,
      referenceId: tx.referenceId,
      createdAt: tx.createdAt,
    }));
  }
}
