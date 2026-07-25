import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import {
  WalletAccountEntity,
  WalletHoldEntity,
  WalletHoldStatus,
  WalletTransactionEntity,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../../database/entities';
import { WalletHoldService } from './wallet-hold.service';

/**
 * In-memory stand-in for the account + hold + transaction tables so the ledger
 * arithmetic is exercised for real rather than asserted against mocks.
 */
class FakeDb {
  account: Partial<WalletAccountEntity> = {
    id: 'acc-1',
    currency: 'JOD',
    balance: '10.00',
    reservedBalance: '0.00',
  };
  holds: Partial<WalletHoldEntity>[] = [];
  txs: Partial<WalletTransactionEntity>[] = [];

  manager = {
    getRepository: (entity: any) => ({
      findOne: async (opts: any) => this.manager.findOne(entity, opts),
    }),
    findOne: async (entity: any, opts: any) => {
      if (entity === WalletAccountEntity) {
        return opts.where.id === this.account.id ? this.account : null;
      }
      if (entity === WalletHoldEntity) {
        return (
          this.holds.find(
            (h) =>
              h.referenceType === opts.where.referenceType &&
              h.referenceId === opts.where.referenceId &&
              (opts.where.status ? h.status === opts.where.status : true),
          ) ?? null
        );
      }
      if (entity === WalletTransactionEntity) {
        return (
          this.txs.find(
            (t) =>
              t.referenceId === opts.where.referenceId &&
              t.type === opts.where.type &&
              t.status === opts.where.status,
          ) ?? null
        );
      }
      return null;
    },
    create: (_entity: any, data: any) => ({ ...data }),
    save: async (obj: any) => {
      if (obj === this.account) return obj;
      if (obj.amount !== undefined && obj.status !== undefined && obj.type) {
        if (!this.txs.includes(obj)) this.txs.push(obj);
        return obj;
      }
      if (obj.amount !== undefined) {
        if (!this.holds.includes(obj)) {
          obj.id = obj.id ?? `hold-${this.holds.length + 1}`;
          this.holds.push(obj);
        }
        return obj;
      }
      return obj;
    },
  };
}

describe('WalletHoldService', () => {
  let service: WalletHoldService;
  let db: FakeDb;

  beforeEach(async () => {
    db = new FakeDb();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WalletHoldService,
        {
          provide: DataSource,
          useValue: {
            transaction: (fn: any) => fn(db.manager),
            manager: db.manager,
          },
        },
      ],
    }).compile();
    service = module.get(WalletHoldService);
  });

  const place = (amount: number) =>
    service.placeHold({
      accountId: 'acc-1',
      amount,
      referenceType: 'trip',
      referenceId: 't1',
      metadata: { percent: 10, seatPrice: 2 },
    });

  describe('placeHold', () => {
    it('reserves funds without moving the balance', async () => {
      await place(0.8);

      expect(db.account.balance).toBe('10.00');
      expect(db.account.reservedBalance).toBe('0.80');
      expect(db.holds).toHaveLength(1);
      expect(db.holds[0].status).toBe(WalletHoldStatus.ACTIVE);
    });

    it('writes a PENDING hold transaction, not a posted debit', async () => {
      await place(0.8);

      expect(db.txs).toHaveLength(1);
      expect(db.txs[0].type).toBe(WalletTransactionType.HOLD);
      expect(db.txs[0].status).toBe(WalletTransactionStatus.PENDING);
    });

    it('is idempotent per reference — a replay does not double-reserve', async () => {
      await place(0.8);
      await place(0.8);

      expect(db.holds).toHaveLength(1);
      expect(db.account.reservedBalance).toBe('0.80');
    });

    it('rejects when available balance is short, counting existing reservations', async () => {
      db.account.balance = '1.00';
      await place(0.8);

      await expect(
        service.placeHold({
          accountId: 'acc-1',
          amount: 0.8,
          referenceType: 'trip',
          referenceId: 't2',
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('rejects an unknown account', async () => {
      await expect(
        service.placeHold({
          accountId: 'nope',
          amount: 1,
          referenceType: 'trip',
          referenceId: 't9',
        }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('settleHold', () => {
    it('captures the fee and releases the remainder', async () => {
      await place(0.8);

      const out = await service.settleHold({
        referenceType: 'trip',
        referenceId: 't1',
        captureAmount: 0.4,
      });

      expect(out.captured).toBe(0.4);
      expect(out.released).toBe(0.4);
      expect(db.account.balance).toBe('9.60');
      expect(db.account.reservedBalance).toBe('0.00');
    });

    it('resolves the pending hold transaction to the captured amount', async () => {
      await place(0.8);
      await service.settleHold({
        referenceType: 'trip',
        referenceId: 't1',
        captureAmount: 0.4,
      });

      const holdTx = db.txs.find(
        (t) => t.type === WalletTransactionType.HOLD,
      )!;
      expect(holdTx.status).toBe(WalletTransactionStatus.POSTED);
      expect(holdTx.amount).toBe('0.40');

      const releaseTx = db.txs.find(
        (t) => t.type === WalletTransactionType.RELEASE_HOLD,
      )!;
      expect(releaseTx.amount).toBe('0.40');
    });

    it('capturing nothing returns the whole reservation and reverses the tx', async () => {
      await place(0.8);

      const out = await service.settleHold({
        referenceType: 'trip',
        referenceId: 't1',
        captureAmount: 0,
      });

      expect(out.captured).toBe(0);
      expect(out.released).toBe(0.8);
      expect(db.account.balance).toBe('10.00');
      expect(db.account.reservedBalance).toBe('0.00');
      expect(
        db.txs.find((t) => t.type === WalletTransactionType.HOLD)!.status,
      ).toBe(WalletTransactionStatus.REVERSED);
    });

    it('clamps capture to the held amount so it can never overdraw the reservation', async () => {
      await place(0.8);

      const out = await service.settleHold({
        referenceType: 'trip',
        referenceId: 't1',
        captureAmount: 5,
      });

      expect(out.captured).toBe(0.8);
      expect(out.released).toBe(0);
      expect(db.account.balance).toBe('9.20');
    });

    it('is idempotent — settling twice moves money only once', async () => {
      await place(0.8);
      await service.settleHold({
        referenceType: 'trip',
        referenceId: 't1',
        captureAmount: 0.4,
      });

      const replay = await service.settleHold({
        referenceType: 'trip',
        referenceId: 't1',
        captureAmount: 0.4,
      });

      expect(replay.applied).toBe(false);
      expect(db.account.balance).toBe('9.60');
    });

    it('throws when there is no hold for the reference', async () => {
      await expect(
        service.settleHold({
          referenceType: 'trip',
          referenceId: 'missing',
          captureAmount: 1,
        }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('releaseHold', () => {
    it('returns the full reservation on cancellation', async () => {
      await place(0.8);

      const out = await service.releaseHold('trip', 't1');

      expect(out!.released).toBe(0.8);
      expect(db.account.balance).toBe('10.00');
      expect(db.account.reservedBalance).toBe('0.00');
    });

    it('no-ops when nothing is held', async () => {
      expect(await service.releaseHold('trip', 'none')).toBeNull();
    });
  });

  it('conserves value: balance drop always equals the captured amount', async () => {
    const opening = Number(db.account.balance);
    await place(0.8);
    const out = await service.settleHold({
      referenceType: 'trip',
      referenceId: 't1',
      captureAmount: 0.6,
    });

    expect(Number(db.account.balance)).toBeCloseTo(opening - out.captured, 2);
    expect(out.captured + out.released).toBeCloseTo(0.8, 2);
    expect(Number(db.account.reservedBalance)).toBe(0);
  });
});
