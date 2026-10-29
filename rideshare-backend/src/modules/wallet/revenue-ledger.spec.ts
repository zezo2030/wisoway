import { WalletService } from './wallet.service';
import {
  BookingEntity,
  PayoutRequestEntity,
  PlatformSettingEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletTransactionEntity,
  PayoutStatus,
} from '../../database/entities';

/** Stateful ledger seam: verify balances and rows, including repeated/concurrent calls. */
describe('Revenue ledger', () => {
  let service: WalletService;
  let tables: Map<any, any[]>;
  let manager: any;
  let settings: any;
  const rows = (type: any) => tables.get(type)!;
  const matches = (row: any, where: any) =>
    Object.entries(where ?? {}).every(([k, v]) => row[k] === v);
  const account = (owner: string | null, type: string) =>
    rows(WalletAccountEntity).find(
      (a) => a.userId === owner && a.accountType === type,
    );
  beforeEach(() => {
    tables = new Map(
      [
        BookingEntity,
        PayoutRequestEntity,
        PlatformSettingEntity,
        TripEntity,
        UserEntity,
        WalletAccountEntity,
        WalletTransactionEntity,
      ].map((t) => [t, []]),
    );
    rows(PlatformSettingEntity).push({
      key: 'commission.cutover',
      value: '2026-01-01',
    });
    rows(TripEntity).push({
      id: 't',
      driverId: 'd',
      currency: 'JOD',
      tripType: 'instant',
      status: 'completed',
      tripCompletedAt: new Date(),
      capturedFeeAmount: '0',
    });
    rows(BookingEntity).push({
      id: 'b',
      tripId: 't',
      userId: 'r',
      status: 'completed',
      totalAmount: '10.00',
      passengerPresenceConfirmedAt: new Date(),
      paymentMethod: 'cash',
      paymentStatus: 'pending',
    });
    rows(UserEntity).push({ id: 'd' }, { id: 'r' });
    rows(WalletAccountEntity).push(
      Object.assign(new WalletAccountEntity(), {
        id: 'wd',
        userId: 'd',
        accountType: 'driver',
        currency: 'JOD',
        balance: '5.00',
        reservedBalance: '0',
        isActive: true,
        rechargeRequired: false,
      }),
    );
    manager = {
      findOne: jest.fn(
        async (type, opts) =>
          rows(type).find((r) => matches(r, opts.where)) ?? null,
      ),
      findOneOrFail: jest.fn(async (type, opts) => {
        const r = rows(type).find((r) => matches(r, opts.where));
        if (!r) throw new Error('not found');
        return r;
      }),
      find: jest.fn(async (type, opts) =>
        rows(type).filter((r) => matches(r, opts.where)),
      ),
      create: (type: any, data: any) => Object.assign(new type(), data),
      save: jest.fn(async (typeOrRow, maybeRow) => {
        const row = maybeRow ?? typeOrRow;
        const type = maybeRow ? typeOrRow : row.constructor;
        // Plain fixture trip/booking objects already live in their table.
        if (!tables.has(type)) return row;
        if (!row.id) row.id = `id-${rows(type).length}`;
        if (!rows(type).includes(row)) rows(type).push(row);
        return row;
      }),
      update: jest.fn(),
      query: jest.fn(async (sql, params) => {
        if (sql.startsWith('UPDATE driver_availability')) return [];
        const [userId, accountType, currency] = params;
        let a = rows(WalletAccountEntity).find(
          (r) =>
            r.userId === userId &&
            r.accountType === accountType &&
            r.currency === currency,
        );
        if (sql.startsWith('INSERT') && !a) {
          a = Object.assign(new WalletAccountEntity(), {
            id: `w-${rows(WalletAccountEntity).length}`,
            userId,
            accountType,
            currency,
            balance: '0',
            reservedBalance: '0',
            isActive: true,
            rechargeRequired: false,
          });
          rows(WalletAccountEntity).push(a);
        }
        return a ? [{ id: a.id }] : [];
      }),
    };
    // Serialize calls to model the row lock at the service boundary.
    let tail = Promise.resolve();
    const ds: any = {
      transaction: (fn: any) => {
        const next = tail.then(() => fn(manager));
        tail = next.catch(() => undefined);
        return next;
      },
      getRepository: (type: any) => ({
        findOne: (opts: any) => manager.findOne(type, opts),
        findOneOrFail: (opts: any) => manager.findOneOrFail(type, opts),
      }),
    };
    const repo = (type: any): any => ({
      find: (opts: any) => manager.find(type, opts),
      findOne: (opts: any) => manager.findOne(type, opts),
    });
    settings = { getNumber: jest.fn(async () => 10) };
    service = new WalletService(
      ds,
      repo(WalletAccountEntity),
      repo(WalletTransactionEntity),
      repo(PayoutRequestEntity),
      repo(TripEntity),
      repo(UserEntity),
      {} as any,
      settings,
      { minimum: jest.fn(async (c) => (c === 'SAR' ? 25 : 5)) } as any,
      { create: jest.fn(async () => undefined) } as any,
    );
  });

  it.each(['instant', 'shared'])(
    'charges 10%% of completed %s fares and credits the platform exactly once',
    async (type) => {
      rows(TripEntity)[0].tripType = type;
      rows(BookingEntity).push({
        id: 'absent',
        tripId: 't',
        status: 'no_show',
        totalAmount: '100',
      });
      await Promise.all([
        service.chargeCompletedTripCommission('t'),
        service.chargeCompletedTripCommission('t'),
      ]);
      expect(account('d', 'driver').balance).toBe('4.00');
      expect(account(null, 'system').balance).toBe('1.00');
      expect(rows(WalletTransactionEntity)).toHaveLength(2);
      expect(settings.getNumber).toHaveBeenCalledWith(
        type === 'instant'
          ? 'instantCommissionPercent'
          : 'sharedCommissionPercent',
      );
    },
  );
  it('uses the configured percentage; zero means no fee', async () => {
    settings.getNumber.mockResolvedValue(0);
    await service.chargeCompletedTripCommission('t');
    expect(account('d', 'driver').balance).toBe('5.00');
    expect(account(null, 'system').balance).toBe('0.00');
  });
  it.each(['cash', 'cliq', 'wallet'] as const)(
    'funds a 20%% promotion without reducing driver earnings for %s',
    async (method) => {
      Object.assign(rows(BookingEntity)[0], {
        originalAmount: '10.00',
        totalAmount: '8.00',
        discountAmount: '2.00',
        promoCode: 'SAVE20',
        paymentMethod: method,
      });
      if (method === 'wallet')
        rows(WalletAccountEntity).push(
          Object.assign(new WalletAccountEntity(), {
            id: 'wr',
            userId: 'r',
            accountType: 'rider',
            currency: 'JOD',
            balance: '20',
            reservedBalance: '0',
            isActive: true,
          }),
        );
      await service.chargeCompletedTripCommission('t');
      if (method !== 'cash') {
        await service.settleCollectedFare('b', method);
        await service.settleCollectedFare('b', method);
      }
      // Driver owns 9 from the fare: cash 8 + wallet increase 1, or wallet increase 9.
      expect(account('d', 'driver').balance).toBe(
        method === 'cash' ? '6.00' : '14.00',
      );
      expect(account(null, 'system').balance).toBe('-1.00');
      expect(
        rows(WalletTransactionEntity).filter(
          (t) => t.idempotencyKey === 'promotion-driver:t',
        ),
      ).toHaveLength(1);
      if (method === 'wallet')
        expect(account('r', 'rider').balance).toBe('12.00');
    },
  );
  it('settles a free CliQ ride without taking money from the passenger', async () => {
    Object.assign(rows(BookingEntity)[0], {
      originalAmount: '10.00',
      totalAmount: '0.00',
      discountAmount: '10.00',
      paymentMethod: 'cliq',
    });
    await service.settleCollectedFare('b', 'cliq');
    expect(account('d', 'driver').balance).toBe('14.00');
    expect(account(null, 'system').balance).toBe('-9.00');
    expect(rows(BookingEntity)[0].paymentStatus).toBe('paid');
  });
  it('charges shared commission only for passenger-confirmed seats, excluding driver-only confirmation and exemptions', async () => {
    rows(TripEntity)[0].tripType = 'scheduled';
    Object.assign(rows(BookingEntity)[0], {
      seatCount: 4,
      totalAmount: '40.00',
      seats: [
        { passengerSelfConfirmedAt: new Date() },
        { presenceConfirmedAt: new Date() },
        { passengerSelfConfirmedAt: new Date(), billableOverride: false },
        {},
      ],
    });
    await service.chargeCompletedTripCommission('t');
    expect(account('d', 'driver').balance).toBe('4.00');
    expect(account(null, 'system').balance).toBe('1.00');
  });
  it('does not charge a completed shared booking without passenger confirmation', async () => {
    rows(TripEntity)[0].tripType = 'scheduled';
    rows(BookingEntity)[0].passengerPresenceConfirmedAt = null;
    await service.chargeCompletedTripCommission('t');
    expect(account('d', 'driver').balance).toBe('5.00');
    expect(account(null, 'system').balance).toBe('0.00');
  });
  it('charges the full instant fare regardless of passenger seat confirmations', async () => {
    Object.assign(rows(BookingEntity)[0], {
      passengerPresenceConfirmedAt: null,
      seatCount: 3,
      seats: [{}, {}, {}],
    });
    await service.chargeCompletedTripCommission('t');
    expect(account('d', 'driver').balance).toBe('4.00');
    expect(account(null, 'system').balance).toBe('1.00');
  });
  it('does not debit before completion or re-charge a legacy trip', async () => {
    rows(TripEntity)[0].status = 'in_progress';
    await service.chargeCompletedTripCommission('t');
    rows(TripEntity)[0].status = 'completed';
    rows(TripEntity)[0].driverWalletChargeApplied = true;
    await service.chargeCompletedTripCommission('t');
    expect(rows(WalletTransactionEntity)).toHaveLength(0);
  });
  it('credits collected CliQ gross only once after commission: 5 + 10 - 1 = 14', async () => {
    rows(BookingEntity)[0].paymentMethod = 'cliq';
    await service.settleCollectedFare('b', 'cliq');
    await service.settleCollectedFare('b', 'cliq');
    expect(account('d', 'driver').balance).toBe('14.00');
    expect(account(null, 'system').balance).toBe('1.00');
    expect(rows(BookingEntity)[0].paymentStatus).toBe('paid');
  });
  it('uses the real fare rather than the client amount when paying with a rider wallet', async () => {
    rows(BookingEntity)[0].paymentMethod = 'wallet';
    rows(WalletAccountEntity).push(
      Object.assign(new WalletAccountEntity(), {
        id: 'wr',
        userId: 'r',
        accountType: 'rider',
        currency: 'JOD',
        balance: '20',
        reservedBalance: '0',
        isActive: true,
      }),
    );
    await service.payTripFromRiderWallet('r', 't', 0.01, 'invented');
    expect(account('r', 'rider').balance).toBe('10.00');
    expect(account('d', 'driver').balance).toBe('14.00');
  });
  it('marks an exhausted wallet for recharge and blocks new trips', async () => {
    account('d', 'driver').balance = '1';
    await service.chargeCompletedTripCommission('t');
    expect(account('d', 'driver').rechargeRequired).toBe(true);
    await expect(service.assertNonNegativeDriverBalance('d')).rejects.toThrow();
  });
  it('grants welcome credit once even on re-approval', async () => {
    account('d', 'driver').balance = '0';
    await service.grantDriverWelcome('d', 'JOD');
    await service.grantDriverWelcome('d', 'SAR');
    expect(account('d', 'driver').balance).toBe('5.00');
    expect(rows(WalletTransactionEntity)).toHaveLength(1);
  });
  it('allows 45 from 50, reserves it, and prevents a second withdrawal', async () => {
    account('d', 'driver').balance = '50';
    const p = await service.createPayoutRequest('d', {
      amount: 45,
      currency: 'JOD',
      bankAccountRef: 'driver-cliq',
    });
    expect(account('d', 'driver').reservedBalance).toBe('45.00');
    await expect(
      service.createPayoutRequest('d', {
        amount: 1,
        currency: 'JOD',
        bankAccountRef: 'driver-cliq',
      }),
    ).rejects.toThrow();
    await service.processPayout(p.id, 'admin', PayoutStatus.PAID);
    await service.processPayout(p.id, 'admin', PayoutStatus.PAID);
    expect(account('d', 'driver').balance).toBe('5.00');
    expect(account('d', 'driver').reservedBalance).toBe('0.00');
  });
  it('releases rejected payout funds without debiting them', async () => {
    account('d', 'driver').balance = '50';
    const p = await service.createPayoutRequest('d', {
      amount: 45,
      currency: 'JOD',
      bankAccountRef: 'driver',
    });
    await service.processPayout(p.id, 'admin', PayoutStatus.REJECTED);
    expect(account('d', 'driver').balance).toBe('50');
    expect(account('d', 'driver').reservedBalance).toBe('0.00');
  });
});
