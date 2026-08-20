# Driver Fee at Trip Start + Open Passenger Contact — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Charge the driver's platform fee exactly once, when the trip auto-starts, computed on all trip seats — and open passenger contact details unconditionally by deleting the pay-to-unlock gate and the wallet-hold machinery.

**Architecture:** A new `DriverTripFeeService` in its own module owns fee computation, the publish-time balance guard, and the single debit at trip start. `TripsService.create` calls the guard; `TripAutoStartProcessor` calls the debit. `WalletHoldService`, `WalletService.chargeDriverTripFee` and the `POST /wallet/driver/trip-charge` route are deleted. `PresenceService.settleTripPresence` keeps its presence bookkeeping and loses its money movement. Every `hasDriverPaidToContact` read in calls, chat, the booking serializer and the Flutter app is removed; the column survives as an audit stamp.

**Tech Stack:** NestJS 11, TypeORM, PostgreSQL, BullMQ (`bull`), Jest (backend). Flutter 3.9.2 / Dart 3.x, `flutter_bloc`, `provider` (mobile). React 19 + Vite 7 (dashboard).

**Spec:** `docs/superpowers/specs/2026-08-20-driver-fee-at-trip-start-design.md`

## Global Constraints

- Fee formula, verbatim: `seatPrice × trip.totalSeats × driverUnlockPercent / 100`, rounded to 2 decimals. **All trip seats**, never booked-seat or presence-confirmed-seat counts.
- The fee is debited exactly once, at the trip's transition to `IN_PROGRESS`. Never at publish, never at booking, never at completion.
- No wallet holds are created anywhere, at any point, after this plan lands.
- The fee is never refunded, never partially released, never recomputed after the debit.
- A trip that starts with zero `CONFIRMED` bookings is charged `0.00`.
- The lifetime-free-trip path (`user.hasUsedLifetimeFreeTrip`) is preserved exactly as it behaves today.
- A failed debit must never prevent a trip from starting.
- `booking.hasDriverPaidToContact` and `trip.communicationFeeStatus` keep their columns and keep being written. Nothing may branch on them for access control.
- Existing money in `wallet_holds` must be returned to drivers by migration, not stranded.
- Currency default throughout: `'JOD'`. Country code for pricing lookups: `'JO'`.
- Backend verification commands: `npm test` and `npm run lint` in `rideshare-backend/`.
- Mobile verification commands: `flutter test` and `flutter analyze` in `rideshare/`.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- `git` in this repo has no configured identity. Commit with:
  `git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit ...`

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.service.ts` | Fee computation, publish guard, single trip-start debit |
| `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.service.spec.ts` | Unit tests for the above |
| `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.module.ts` | Wires the service; imports `WalletModule`, `PendingChargesModule` |
| `rideshare-backend/src/database/migrations/1747000000000-add-driver-trip-fee-pending-charge-kind.ts` | Extends the `pending_charges.kind` enum |
| `rideshare-backend/src/database/migrations/1747100000000-release-wallet-holds-fee-at-trip-start.ts` | Returns reserved money, stamps already-captured trips |
| `rideshare-backend/src/modules/bookings/processors/trip-auto-start.processor.spec.ts` | Processor tests (does not exist today) |
| `rideshare/lib/screens/driver/widgets/trip_route_card.dart` | Origin → destination card from the mock |
| `rideshare/lib/screens/driver/widgets/trip_facts_strip.dart` | Five-column day/time/meeting-point/distance/seats strip |
| `rideshare/lib/screens/driver/widgets/trip_fare_breakdown_card.dart` | Passenger fare, passengers total, trip fee |

**Deleted**

| Path | Reason |
|---|---|
| `rideshare-backend/src/modules/wallet/wallet-hold.service.ts` + `.spec.ts` | Holds are gone |

**Modified** — listed per task.

A new module rather than adding to `WalletModule`: `PendingChargesModule` already imports `WalletModule`, so a `WalletModule` provider depending on `PendingChargesService` would be a circular dependency. `DriverTripFeeModule` imports both and is imported by `TripsModule` and `BookingsModule`, which keeps the graph acyclic.

---

### Task 1: Enum value, account mapping, and error code

**Files:**
- Modify: `rideshare-backend/src/database/entities/pending-charge.entity.ts:29-33`
- Modify: `rideshare-backend/src/modules/pending-charges/pending-charges.service.ts:36-42`
- Modify: `rideshare-backend/src/common/errors/error-codes.ts:124-126`
- Create: `rideshare-backend/src/database/migrations/1747000000000-add-driver-trip-fee-pending-charge-kind.ts`
- Test: `rideshare-backend/src/modules/pending-charges/pending-charges.service.spec.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `PendingChargeKind.DRIVER_TRIP_FEE = 'driver_trip_fee'`
  - `ErrorCodes.INSUFFICIENT_BALANCE_FOR_TRIP_FEE = 'INSUFFICIENT_BALANCE_FOR_TRIP_FEE'`
  - `walletAccountTypeForCharge(PendingChargeKind.DRIVER_TRIP_FEE) === WalletAccountType.DRIVER`

`walletAccountTypeForCharge` currently reads `kind === DRIVER_NO_SHOW ? DRIVER : RIDER`. Without this task a driver trip fee would be taken from the driver's **rider** wallet.

- [ ] **Step 1: Write the failing test**

Create `rideshare-backend/src/modules/pending-charges/pending-charges.service.spec.ts` if it does not exist; otherwise append. `walletAccountTypeForCharge` is a module-private function, so assert it through an export — add `export` to the function declaration in Step 3.

```typescript
import { WalletAccountType } from '../../database/entities';
import { PendingChargeKind } from '../../database/entities/pending-charge.entity';
import { walletAccountTypeForCharge } from './pending-charges.service';

describe('walletAccountTypeForCharge', () => {
  it('routes a driver trip fee to the driver ledger', () => {
    expect(walletAccountTypeForCharge(PendingChargeKind.DRIVER_TRIP_FEE)).toBe(
      WalletAccountType.DRIVER,
    );
  });

  it('routes a driver no-show to the driver ledger', () => {
    expect(walletAccountTypeForCharge(PendingChargeKind.DRIVER_NO_SHOW)).toBe(
      WalletAccountType.DRIVER,
    );
  });

  it('routes passenger charges to the rider ledger', () => {
    expect(
      walletAccountTypeForCharge(PendingChargeKind.PASSENGER_NO_SHOW),
    ).toBe(WalletAccountType.RIDER);
    expect(
      walletAccountTypeForCharge(PendingChargeKind.PASSENGER_CANCELLATION),
    ).toBe(WalletAccountType.RIDER);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- pending-charges.service.spec`
Expected: FAIL — `DRIVER_TRIP_FEE` does not exist on `PendingChargeKind`, and `walletAccountTypeForCharge` is not exported.

- [ ] **Step 3: Add the enum value, export and fix the mapping**

In `pending-charge.entity.ts`, extend the enum and the docblock:

```typescript
export enum PendingChargeKind {
  PASSENGER_CANCELLATION = 'passenger_cancellation',
  DRIVER_NO_SHOW = 'driver_no_show',
  PASSENGER_NO_SHOW = 'passenger_no_show',
  /** Platform fee owed by a driver whose wallet could not cover it at trip start. */
  DRIVER_TRIP_FEE = 'driver_trip_fee',
}
```

In `pending-charges.service.ts`, export the helper and switch on driver kinds:

```typescript
const DRIVER_CHARGE_KINDS: ReadonlySet<PendingChargeKind> = new Set([
  PendingChargeKind.DRIVER_NO_SHOW,
  PendingChargeKind.DRIVER_TRIP_FEE,
]);

export function walletAccountTypeForCharge(
  kind: PendingChargeKind,
): WalletAccountType {
  return DRIVER_CHARGE_KINDS.has(kind)
    ? WalletAccountType.DRIVER
    : WalletAccountType.RIDER;
}
```

In `error-codes.ts`, add before the closing `} as const;`:

```typescript
  /** Driver wallet cannot cover the platform fee for the trip being published. */
  INSUFFICIENT_BALANCE_FOR_TRIP_FEE: 'INSUFFICIENT_BALANCE_FOR_TRIP_FEE',
```

- [ ] **Step 4: Write the enum migration**

Create `rideshare-backend/src/database/migrations/1747000000000-add-driver-trip-fee-pending-charge-kind.ts`:

```typescript
import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddDriverTripFeePendingChargeKind1747000000000
  implements MigrationInterface
{
  name = 'AddDriverTripFeePendingChargeKind1747000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    const [{ typname }] = (await queryRunner.query(`
      SELECT t.typname
      FROM pg_type t
      JOIN pg_attribute a ON a.atttypid = t.oid
      JOIN pg_class c ON c.oid = a.attrelid
      WHERE c.relname = 'pending_charges' AND a.attname = 'kind'
    `)) as { typname: string }[];

    await queryRunner.query(
      `ALTER TYPE "${typname}" ADD VALUE IF NOT EXISTS 'driver_trip_fee'`,
    );
  }

  public async down(): Promise<void> {
    // Postgres cannot drop a value from an enum type. Intentionally a no-op:
    // leaving the unused label in place is harmless and reversible-by-restore.
  }
}
```

The type name is looked up rather than hardcoded because TypeORM derives enum type names from the table and column and the exact name varies between generated schemas.

- [ ] **Step 5: Run test to verify it passes**

Run: `npm test -- pending-charges.service.spec`
Expected: PASS, 3 tests.

- [ ] **Step 6: Lint and commit**

```bash
cd rideshare-backend && npm run lint
git add src/database/entities/pending-charge.entity.ts \
        src/modules/pending-charges/pending-charges.service.ts \
        src/modules/pending-charges/pending-charges.service.spec.ts \
        src/common/errors/error-codes.ts \
        src/database/migrations/1747000000000-add-driver-trip-fee-pending-charge-kind.ts
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(wallet): add driver_trip_fee pending charge kind

Route it to the driver ledger and add the publish-guard error code.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `DriverTripFeeService` — fee computation and publish guard

**Files:**
- Create: `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.service.ts`
- Create: `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.module.ts`
- Test: `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.service.spec.ts`

**Interfaces:**
- Consumes: `ErrorCodes.INSUFFICIENT_BALANCE_FOR_TRIP_FEE` (Task 1); `PlatformPricingService.getActiveFeeRow(countryCode: string): Promise<CommunicationFeeEntity | null>`; `WalletService.getWalletSummary(userId: string, accountType: WalletAccountType): Promise<{ balance: number; currency: string; ... }>`.
- Produces:

```typescript
export interface TripFeeBasis {
  seatPrice: number;
  totalSeats: number;
  currency?: string | null;
}

export interface TripFeeQuote {
  amount: number;
  seatPrice: number;
  totalSeats: number;
  percent: number;
  currency: string;
}

class DriverTripFeeService {
  computeExpectedFee(basis: TripFeeBasis): Promise<TripFeeQuote>;
  assertDriverCanCoverTripFee(driverId: string, basis: TripFeeBasis): Promise<TripFeeQuote>;
}
```

`computeExpectedFee` takes a plain basis rather than a `TripEntity` so the publish guard can run before the trip row exists.

- [ ] **Step 1: Write the failing test**

Create `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.service.spec.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import {
  BookingEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletAccountType,
  WalletTransactionEntity,
} from '../../database/entities';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { PendingChargesService } from '../pending-charges/pending-charges.service';
import { WalletService } from '../wallet/wallet.service';
import { DriverTripFeeService } from './driver-trip-fee.service';

describe('DriverTripFeeService — quoting and publish guard', () => {
  let service: DriverTripFeeService;
  let walletService: { getWalletSummary: jest.Mock };
  let pricing: { getActiveFeeRow: jest.Mock };

  beforeEach(async () => {
    walletService = { getWalletSummary: jest.fn() };
    pricing = {
      getActiveFeeRow: jest.fn().mockResolvedValue({
        driverUnlockPercent: 10,
        feeAmount: 0,
        currency: 'JOD',
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DriverTripFeeService,
        { provide: WalletService, useValue: walletService },
        { provide: PlatformPricingService, useValue: pricing },
        { provide: PendingChargesService, useValue: { record: jest.fn() } },
        { provide: DataSource, useValue: { transaction: jest.fn() } },
        { provide: getRepositoryToken(TripEntity), useValue: {} },
        { provide: getRepositoryToken(BookingEntity), useValue: {} },
        { provide: getRepositoryToken(UserEntity), useValue: {} },
        { provide: getRepositoryToken(WalletAccountEntity), useValue: {} },
        { provide: getRepositoryToken(WalletTransactionEntity), useValue: {} },
      ],
    }).compile();

    service = module.get(DriverTripFeeService);
  });

  it('charges on every seat, not on booked seats', async () => {
    const quote = await service.computeExpectedFee({
      seatPrice: 4,
      totalSeats: 4,
      currency: 'JOD',
    });
    expect(quote.amount).toBe(1.6);
    expect(quote.percent).toBe(10);
    expect(quote.totalSeats).toBe(4);
  });

  it('rounds to two decimals', async () => {
    const quote = await service.computeExpectedFee({
      seatPrice: 3.33,
      totalSeats: 3,
      currency: 'JOD',
    });
    expect(quote.amount).toBe(1.0);
  });

  it('falls back to the legacy flat fee when the percent is zero', async () => {
    pricing.getActiveFeeRow.mockResolvedValue({
      driverUnlockPercent: 0,
      feeAmount: 0.75,
      currency: 'JOD',
    });
    const quote = await service.computeExpectedFee({
      seatPrice: 4,
      totalSeats: 4,
    });
    expect(quote.amount).toBe(0.75);
  });

  it('allows publishing when the balance exactly equals the fee', async () => {
    walletService.getWalletSummary.mockResolvedValue({
      balance: 1.6,
      currency: 'JOD',
    });
    await expect(
      service.assertDriverCanCoverTripFee('driver-1', {
        seatPrice: 4,
        totalSeats: 4,
      }),
    ).resolves.toMatchObject({ amount: 1.6 });
    expect(walletService.getWalletSummary).toHaveBeenCalledWith(
      'driver-1',
      WalletAccountType.DRIVER,
    );
  });

  it('blocks publishing one fils below the fee', async () => {
    walletService.getWalletSummary.mockResolvedValue({
      balance: 1.59,
      currency: 'JOD',
    });
    await expect(
      service.assertDriverCanCoverTripFee('driver-1', {
        seatPrice: 4,
        totalSeats: 4,
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('blocks publishing on a negative balance', async () => {
    walletService.getWalletSummary.mockResolvedValue({
      balance: -3,
      currency: 'JOD',
    });
    await expect(
      service.assertDriverCanCoverTripFee('driver-1', {
        seatPrice: 4,
        totalSeats: 4,
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- driver-trip-fee.service.spec`
Expected: FAIL — `Cannot find module './driver-trip-fee.service'`.

- [ ] **Step 3: Write the service (quoting half only)**

Create `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.service.ts`. Task 3 appends `chargeAtTripStart` to this same class, so declare the constructor dependencies it will need now.

```typescript
/**
 * DriverTripFeeService
 *
 * Owns the shared-trip platform fee end to end: the quote shown before
 * publishing, the balance guard at publish, and the single debit at trip start.
 *
 * The fee is deliberately based on the trip's TOTAL seat count, not on booked
 * or presence-confirmed seats — a driver pays the same whether the car fills or
 * not. It is charged once, when the trip starts, and is never refunded or
 * recomputed afterwards.
 */
import {
  ForbiddenException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import {
  BookingEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletAccountType,
  WalletTransactionEntity,
} from '../../database/entities';
import { ErrorCodes } from '../../common/errors/error-codes';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { PendingChargesService } from '../pending-charges/pending-charges.service';
import { WalletService } from '../wallet/wallet.service';

export interface TripFeeBasis {
  seatPrice: number;
  totalSeats: number;
  currency?: string | null;
}

export interface TripFeeQuote {
  amount: number;
  seatPrice: number;
  totalSeats: number;
  percent: number;
  currency: string;
}

const PRICING_COUNTRY = 'JO';

@Injectable()
export class DriverTripFeeService {
  private readonly logger = new Logger(DriverTripFeeService.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(WalletAccountEntity)
    private readonly walletAccountRepo: Repository<WalletAccountEntity>,
    @InjectRepository(WalletTransactionEntity)
    private readonly walletTxRepo: Repository<WalletTransactionEntity>,
    private readonly dataSource: DataSource,
    private readonly walletService: WalletService,
    private readonly pendingCharges: PendingChargesService,
    private readonly platformPricing: PlatformPricingService,
  ) {}

  /**
   * Fee = seatPrice * totalSeats * percent%, or the legacy flat amount when the
   * configured percent is zero. Mirrors PlatformPricingService.driverUnlockPricing
   * but accepts a plain basis so it can be quoted before a trip row exists.
   */
  async computeExpectedFee(basis: TripFeeBasis): Promise<TripFeeQuote> {
    const row = await this.platformPricing.getActiveFeeRow(PRICING_COUNTRY);
    const seatPrice = this.round2(Number(basis.seatPrice ?? 0));
    const totalSeats = Number(basis.totalSeats ?? 0);
    const percent = Number(row?.driverUnlockPercent ?? 0);
    const legacyFlat = Number(row?.feeAmount ?? 0);
    const amount =
      percent > 0
        ? this.round2((seatPrice * totalSeats * percent) / 100)
        : this.round2(legacyFlat);

    return {
      amount,
      seatPrice,
      totalSeats,
      percent,
      currency: row?.currency ?? basis.currency ?? 'JOD',
    };
  }

  /**
   * Publish-time guard. The driver must be able to cover the whole fee before
   * the trip goes live, because nothing is reserved between publish and start.
   */
  async assertDriverCanCoverTripFee(
    driverId: string,
    basis: TripFeeBasis,
  ): Promise<TripFeeQuote> {
    const quote = await this.computeExpectedFee(basis);
    const summary = await this.walletService.getWalletSummary(
      driverId,
      WalletAccountType.DRIVER,
    );

    if (summary.balance < quote.amount) {
      throw new ForbiddenException({
        code: ErrorCodes.INSUFFICIENT_BALANCE_FOR_TRIP_FEE,
        message: `رصيد محفظتك (${summary.balance.toFixed(2)}) لا يغطي رسوم الرحلة (${quote.amount.toFixed(2)}). اشحن محفظتك قبل نشر الرحلة.`,
        balance: summary.balance,
        requiredAmount: quote.amount,
        currency: quote.currency,
      });
    }

    return quote;
  }

  private round2(value: number): number {
    return Math.round((value + Number.EPSILON) * 100) / 100;
  }
}
```

- [ ] **Step 4: Write the module**

Create `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.module.ts`:

```typescript
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  BookingEntity,
  CommunicationFeeEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletTransactionEntity,
} from '../../database/entities';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { PendingChargesModule } from '../pending-charges/pending-charges.module';
import { WalletModule } from '../wallet/wallet.module';
import { DriverTripFeeService } from './driver-trip-fee.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      TripEntity,
      BookingEntity,
      UserEntity,
      WalletAccountEntity,
      WalletTransactionEntity,
      CommunicationFeeEntity,
    ]),
    WalletModule,
    PendingChargesModule,
  ],
  providers: [DriverTripFeeService, PlatformPricingService],
  exports: [DriverTripFeeService],
})
export class DriverTripFeeModule {}
```

`PlatformPricingService` is provided directly rather than imported from `PaymentsModule` — this matches how `WalletModule` and `TripTimeModule` already wire it, and it needs `CommunicationFeeEntity` in `forFeature`.

- [ ] **Step 5: Run test to verify it passes**

Run: `npm test -- driver-trip-fee.service.spec`
Expected: PASS, 6 tests.

- [ ] **Step 6: Lint and commit**

```bash
cd rideshare-backend && npm run lint
git add src/modules/driver-trip-fee/
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(fee): add DriverTripFeeService quoting and publish guard

Fee is seatPrice * totalSeats * percent, quoted from a plain basis so it
can be checked before the trip row exists.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `chargeAtTripStart` — the single debit

**Files:**
- Modify: `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.service.ts`
- Test: `rideshare-backend/src/modules/driver-trip-fee/driver-trip-fee.service.spec.ts`

**Interfaces:**
- Consumes: `PendingChargesService.record(params: { userId: string; kind: PendingChargeKind; amount: number; bookingId?: string | null; tripId?: string | null }): Promise<PendingChargeEntity>`; `WalletService.syncUserLegacyWalletMirror(userId: string, accountType: WalletAccountType, manager: EntityManager): Promise<void>`; `pickPrimaryWalletLedgerAccount(accounts: WalletAccountEntity[]): WalletAccountEntity | null` exported from `../wallet/wallet.service`.
- Produces:

```typescript
export interface TripFeeChargeResult {
  tripId: string;
  charged: number;          // actually debited from the wallet
  pendingRemainder: number; // recorded as a PendingCharge, 0 when fully paid
  currency: string;
  applied: boolean;         // false when short-circuited by idempotency
  reason?: 'already-charged' | 'no-bookings' | 'free-trip';
}

chargeAtTripStart(trip: TripEntity): Promise<TripFeeChargeResult>;
```

`PendingChargesService.record` already attempts an immediate wallet deduction and leaves the row `PENDING` when the balance is short (`deductFromWallet` returns `null` rather than going negative). Passing the remainder after the wallet has been drained therefore always lands as a `PENDING` row, which is exactly what blocks the driver's next publish through the existing `getOutstandingSummary` check in `TripsService.create`.

- [ ] **Step 1: Write the failing tests**

Append to `driver-trip-fee.service.spec.ts`. This suite drives the real ledger arithmetic through an in-memory manager, in the style of the existing `wallet-hold.service.spec.ts`.

```typescript
import { PendingChargeKind } from '../../database/entities/pending-charge.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { BookingStatus } from '../../database/entities/booking.entity';

describe('DriverTripFeeService.chargeAtTripStart', () => {
  let service: DriverTripFeeService;
  let account: any;
  let driver: any;
  let savedTxs: any[];
  let savedTrips: any[];
  let confirmedBookings: any[];
  let pendingCharges: { record: jest.Mock };

  const trip = () =>
    ({
      id: 'trip-1',
      driverId: 'driver-1',
      price: 4,
      totalSeats: 4,
      currency: 'JOD',
      status: TripStatus.IN_PROGRESS,
      driverWalletChargeApplied: false,
    }) as any;

  beforeEach(async () => {
    account = {
      id: 'acc-1',
      userId: 'driver-1',
      accountType: WalletAccountType.DRIVER,
      currency: 'JOD',
      balance: '10.00',
    };
    driver = { id: 'driver-1', hasUsedLifetimeFreeTrip: true };
    savedTxs = [];
    savedTrips = [];
    confirmedBookings = [{ id: 'b-1' }, { id: 'b-2' }];
    pendingCharges = { record: jest.fn().mockResolvedValue({ id: 'pc-1' }) };

    const manager = {
      createQueryBuilder: () => ({
        setLock: () => ({
          where: () => ({
            andWhere: () => ({
              orderBy: () => ({ getMany: async () => [account] }),
            }),
          }),
        }),
      }),
      findOne: async (entity: any) =>
        entity === UserEntity ? driver : null,
      find: async () => confirmedBookings,
      create: (_entity: any, data: any) => ({ ...data }),
      save: async (entity: any, obj?: any) => {
        const row = obj ?? entity;
        if (row?.type) savedTxs.push(row);
        if (row?.driverWalletChargeApplied !== undefined) savedTrips.push(row);
        return row;
      },
      update: async () => ({ affected: 1 }),
    };

    const dataSource = {
      transaction: async (cb: any) => cb(manager),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DriverTripFeeService,
        {
          provide: WalletService,
          useValue: {
            getWalletSummary: jest.fn(),
            syncUserLegacyWalletMirror: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: PlatformPricingService,
          useValue: {
            getActiveFeeRow: jest.fn().mockResolvedValue({
              driverUnlockPercent: 10,
              feeAmount: 0,
              currency: 'JOD',
            }),
          },
        },
        { provide: PendingChargesService, useValue: pendingCharges },
        { provide: DataSource, useValue: dataSource },
        {
          provide: getRepositoryToken(TripEntity),
          useValue: {
            save: async (t: any) => {
              savedTrips.push(t);
              return t;
            },
          },
        },
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: {
            find: async () => confirmedBookings,
            update: async () => ({ affected: confirmedBookings.length }),
          },
        },
        { provide: getRepositoryToken(UserEntity), useValue: {} },
        { provide: getRepositoryToken(WalletAccountEntity), useValue: {} },
        { provide: getRepositoryToken(WalletTransactionEntity), useValue: {} },
      ],
    }).compile();

    service = module.get(DriverTripFeeService);
  });

  it('debits the full all-seats fee when the balance covers it', async () => {
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(1.6);
    expect(result.pendingRemainder).toBe(0);
    expect(account.balance).toBe('8.40');
    expect(pendingCharges.record).not.toHaveBeenCalled();
  });

  it('charges on all four seats even though only two are booked', async () => {
    confirmedBookings = [{ id: 'b-1' }, { id: 'b-2' }];
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(1.6);
  });

  it('stamps the trip so a second run is a no-op', async () => {
    const t = trip();
    await service.chargeAtTripStart(t);
    const balanceAfterFirst = account.balance;

    // No manual flag flip — the first call must have stamped the trip itself.
    expect(t.driverWalletChargeApplied).toBe(true);

    const second = await service.chargeAtTripStart(t);

    expect(second.applied).toBe(false);
    expect(second.reason).toBe('already-charged');
    expect(account.balance).toBe(balanceAfterFirst);
  });

  it('charges nothing when no bookings were confirmed', async () => {
    confirmedBookings = [];
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(0);
    expect(result.reason).toBe('no-bookings');
    expect(account.balance).toBe('10.00');
    expect(savedTxs).toHaveLength(1);
    expect(savedTxs[0].amount).toBe('0.00');
  });

  it('consumes the lifetime free trip instead of charging', async () => {
    driver.hasUsedLifetimeFreeTrip = false;
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(0);
    expect(result.reason).toBe('free-trip');
    expect(driver.hasUsedLifetimeFreeTrip).toBe(true);
    expect(account.balance).toBe('10.00');
    expect(savedTxs[0].metadata.freeTripApplied).toBe(true);
  });

  it('debits what it can and records the remainder as a pending charge', async () => {
    account.balance = '1.00';
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(1.0);
    expect(result.pendingRemainder).toBe(0.6);
    expect(account.balance).toBe('0.00');
    expect(pendingCharges.record).toHaveBeenCalledWith({
      userId: 'driver-1',
      kind: PendingChargeKind.DRIVER_TRIP_FEE,
      amount: 0.6,
      tripId: 'trip-1',
    });
  });

  it('records the whole fee as pending on a zero balance', async () => {
    account.balance = '0.00';
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(0);
    expect(result.pendingRemainder).toBe(1.6);
    expect(pendingCharges.record).toHaveBeenCalledWith(
      expect.objectContaining({ amount: 1.6 }),
    );
  });

  it('snapshots the pricing basis onto the transaction metadata', async () => {
    await service.chargeAtTripStart(trip());
    expect(savedTxs[0].metadata).toMatchObject({
      seatPrice: 4,
      totalSeats: 4,
      percent: 10,
      formula: 'seatPrice * totalSeats * percent%',
    });
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm test -- driver-trip-fee.service.spec`
Expected: FAIL — `service.chargeAtTripStart is not a function`.

- [ ] **Step 3: Implement `chargeAtTripStart`**

Add to `DriverTripFeeService`, after `assertDriverCanCoverTripFee`. Add these imports at the top of the file:

```typescript
import { BookingStatus } from '../../database/entities/booking.entity';
import {
  WalletEntryDirection,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../../database/entities';
import { PendingChargeKind } from '../../database/entities/pending-charge.entity';
import { pickPrimaryWalletLedgerAccount } from '../wallet/wallet.service';
import { In } from 'typeorm';
```

```typescript
export interface TripFeeChargeResult {
  tripId: string;
  charged: number;
  pendingRemainder: number;
  currency: string;
  applied: boolean;
  reason?: 'already-charged' | 'no-bookings' | 'free-trip';
}

  /**
   * The one and only debit. Called when the trip flips to IN_PROGRESS.
   *
   * Idempotent by trip.driverWalletChargeApplied, so a replayed BullMQ job or a
   * reconciliation sweep cannot double-charge. Never throws for a business
   * reason — the caller must be able to start the trip regardless.
   */
  async chargeAtTripStart(trip: TripEntity): Promise<TripFeeChargeResult> {
    const quote = await this.computeExpectedFee({
      seatPrice: Number(trip.price ?? 0),
      totalSeats: trip.totalSeats ?? 0,
      currency: trip.currency,
    });

    if (trip.driverWalletChargeApplied) {
      return {
        tripId: trip.id,
        charged: Number(trip.capturedFeeAmount ?? 0),
        pendingRemainder: 0,
        currency: quote.currency,
        applied: false,
        reason: 'already-charged',
      };
    }

    const confirmedBookings = await this.bookingRepo.find({
      where: {
        tripId: trip.id,
        status: In([BookingStatus.CONFIRMED, BookingStatus.IN_PROGRESS]),
      },
      select: { id: true },
    });

    const metadataBase = {
      seatPrice: quote.seatPrice,
      totalSeats: quote.totalSeats,
      percent: quote.percent,
      formula: 'seatPrice * totalSeats * percent%',
    };

    const outcome = await this.dataSource.transaction(async (manager) => {
      const driver = await manager.findOne(UserEntity, {
        where: { id: trip.driverId },
        lock: { mode: 'pessimistic_write' },
      });

      const writeAuditRow = async (
        accountId: string | null,
        amount: number,
        metadata: Record<string, unknown>,
      ) => {
        if (!accountId) return;
        await manager.save(
          WalletTransactionEntity,
          manager.create(WalletTransactionEntity, {
            accountId,
            type: WalletTransactionType.TRIP_DEBIT,
            direction: WalletEntryDirection.DEBIT,
            status: WalletTransactionStatus.POSTED,
            amount: amount.toFixed(2),
            currency: quote.currency,
            referenceType: 'trip',
            referenceId: trip.id,
            idempotencyKey: `trip-fee:${trip.id}`,
            metadata,
          }),
        );
      };

      const lockedAccounts = await manager
        .createQueryBuilder(WalletAccountEntity, 'wa')
        .setLock('pessimistic_write')
        .where('wa.userId = :userId', { userId: trip.driverId })
        .andWhere('wa.accountType = :accountType', {
          accountType: WalletAccountType.DRIVER,
        })
        .orderBy('wa.id', 'ASC')
        .getMany();
      const account = pickPrimaryWalletLedgerAccount(lockedAccounts);

      if (confirmedBookings.length === 0) {
        await writeAuditRow(account?.id ?? null, 0, {
          ...metadataBase,
          reason: 'no-bookings',
        });
        return { charged: 0, remainder: 0, reason: 'no-bookings' as const };
      }

      if (driver && !driver.hasUsedLifetimeFreeTrip) {
        driver.hasUsedLifetimeFreeTrip = true;
        await manager.save(UserEntity, driver);
        await writeAuditRow(account?.id ?? null, 0, {
          ...metadataBase,
          freeTripApplied: true,
          discountPercent: 100,
        });
        return { charged: 0, remainder: 0, reason: 'free-trip' as const };
      }

      if (!account) {
        return { charged: 0, remainder: quote.amount, reason: undefined };
      }

      const available = Math.max(Number(account.balance), 0);
      const charged = this.round2(Math.min(available, quote.amount));
      const remainder = this.round2(quote.amount - charged);

      if (charged > 0) {
        account.balance = this.round2(
          Number(account.balance) - charged,
        ).toFixed(2);
        await manager.save(WalletAccountEntity, account);
        await writeAuditRow(account.id, charged, {
          ...metadataBase,
          feeAmount: quote.amount,
          shortfall: remainder,
        });
        await this.walletService.syncUserLegacyWalletMirror(
          trip.driverId,
          WalletAccountType.DRIVER,
          manager,
        );
      }

      return { charged, remainder, reason: undefined };
    });

    if (outcome.remainder > 0) {
      await this.pendingCharges.record({
        userId: trip.driverId,
        kind: PendingChargeKind.DRIVER_TRIP_FEE,
        amount: outcome.remainder,
        tripId: trip.id,
      });
    }

    await this.stampTripCharged(trip, outcome.charged);

    this.logger.log(
      `Trip ${trip.id} fee: charged ${outcome.charged.toFixed(2)} ${quote.currency}` +
        (outcome.remainder > 0
          ? `, ${outcome.remainder.toFixed(2)} carried forward`
          : '') +
        (outcome.reason ? ` (${outcome.reason})` : ''),
    );

    return {
      tripId: trip.id,
      charged: outcome.charged,
      pendingRemainder: outcome.remainder,
      currency: quote.currency,
      applied: true,
      reason: outcome.reason,
    };
  }

  /**
   * Audit stamp. These columns no longer gate anything — they record when and
   * how much the platform took, and the admin dashboard reads them.
   */
  private async stampTripCharged(
    trip: TripEntity,
    charged: number,
  ): Promise<void> {
    const now = new Date();
    trip.driverWalletChargeApplied = true;
    trip.driverWalletChargeAt = now;
    trip.communicationFeeStatus = 'paid';
    trip.capturedFeeAmount = charged.toFixed(2);
    await this.tripRepo.save(trip);

    await this.bookingRepo.update(
      {
        tripId: trip.id,
        status: In([
          BookingStatus.PENDING,
          BookingStatus.CONFIRMED,
          BookingStatus.IN_PROGRESS,
        ]),
      },
      { hasDriverPaidToContact: true },
    );
  }
```

`stampTripCharged` runs outside the ledger transaction on purpose: if the stamp fails, the reconciliation sweep in Task 9 re-runs the charge, and the `idempotencyKey` on the audit row plus the balance check keep that safe.

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm test -- driver-trip-fee.service.spec`
Expected: PASS, 14 tests (6 from Task 2 + 8 here).

- [ ] **Step 5: Lint and commit**

```bash
cd rideshare-backend && npm run lint
git add src/modules/driver-trip-fee/
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(fee): charge the driver trip fee once at trip start

Idempotent by trip.driverWalletChargeApplied. Debits what the wallet
holds and carries any shortfall forward as a pending charge; free trips
and zero-booking trips write a 0.00 audit row.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Publish-time guard and the pre-publish fee quote endpoint

**Files:**
- Modify: `rideshare-backend/src/modules/trips/trips.service.ts:157`
- Modify: `rideshare-backend/src/modules/trips/trips.controller.ts` (insert above `@Get(':id/pricing-preview')`)
- Modify: `rideshare-backend/src/modules/trips/trips.module.ts`
- Test: `rideshare-backend/src/modules/trips/trips.service.spec.ts` (already exists — append)

**Interfaces:**
- Consumes: `DriverTripFeeService.assertDriverCanCoverTripFee(driverId, basis)` and `computeExpectedFee(basis)` (Task 2).
- Produces:
  - Publishing rejects with HTTP 403 and code `INSUFFICIENT_BALANCE_FOR_TRIP_FEE` when the driver cannot cover the fee.
  - `GET /trips/fee-quote?seatPrice={n}&totalSeats={n}` → `{ amount, seatPrice, totalSeats, percent, currency }`. Task 11 consumes this.

The existing `GET /trips/:id/pricing-preview` cannot serve the create-trip screen — it needs a trip that does not exist yet. Without the new route the app would have to hardcode the percentage, which is exactly the `'5%'` bug this plan removes.

- [ ] **Step 1: Read the current guard**

Run: `sed -n '135,175p' rideshare-backend/src/modules/trips/trips.service.ts`

The relevant lines are the outstanding-charges check followed by `await this.walletService.assertNonNegativeDriverBalance(driverId);`. Note the exact name of the DTO fields carrying seat price and seat count (`createTripDto.price` and the resolved seat count) before editing — the seat count is derived from the vehicle layout a few lines below, so the guard must compute it the same way.

- [ ] **Step 2: Write the failing test**

Append to `rideshare-backend/src/modules/trips/trips.service.spec.ts`, reusing that file's existing `beforeEach` and adding a `DriverTripFeeService` mock provider (`{ assertDriverCanCoverTripFee: jest.fn().mockResolvedValue({ amount: 1.6 }), computeExpectedFee: jest.fn() }`) to its testing module:

```typescript
it('rejects publishing when the driver cannot cover the trip fee', async () => {
  driverTripFee.assertDriverCanCoverTripFee.mockRejectedValue(
    new ForbiddenException({
      code: ErrorCodes.INSUFFICIENT_BALANCE_FOR_TRIP_FEE,
    }),
  );

  await expect(
    service.create('driver-1', validCreateTripDto),
  ).rejects.toBeInstanceOf(ForbiddenException);
});

it('passes the seat price and total seat count to the fee guard', async () => {
  await service.create('driver-1', { ...validCreateTripDto, price: 4 });

  expect(driverTripFee.assertDriverCanCoverTripFee).toHaveBeenCalledWith(
    'driver-1',
    expect.objectContaining({ seatPrice: 4 }),
  );
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `npm test -- trips.service.spec`
Expected: FAIL — `assertDriverCanCoverTripFee` is never called.

- [ ] **Step 4: Wire the guard**

In `trips.service.ts`, inject `private readonly driverTripFee: DriverTripFeeService` and replace the bare balance assertion:

```typescript
    // Nothing is reserved between publish and start, so the driver must be able
    // to cover the whole fee up front or the trip does not go live.
    await this.driverTripFee.assertDriverCanCoverTripFee(driverId, {
      seatPrice: Number(createTripDto.price ?? 0),
      totalSeats: resolvedTotalSeats,
      currency: createTripDto.currency ?? 'JOD',
    });
```

`resolvedTotalSeats` must be computed before this call using the same vehicle-layout resolution the trip row uses further down — hoist that computation above the guard rather than duplicating it.

Keep the existing `getOutstandingSummary` check above it untouched: it is what blocks a driver who carries a shortfall from a previous trip.

In `trips.module.ts`, add `DriverTripFeeModule` to `imports`.

- [ ] **Step 5: Add the pre-publish quote endpoint**

In `trips.controller.ts`, insert **above** `@Get(':id/pricing-preview')` — a literal path declared after `@Get(':id')` would be swallowed by the parameter route:

```typescript
  @Get('fee-quote')
  @ApiOperation({
    summary: 'Platform fee a driver will be charged for a trip of this shape',
  })
  @ApiResponse({ status: 200, description: 'Fee quote' })
  async feeQuote(
    @Query('seatPrice') seatPrice: string,
    @Query('totalSeats') totalSeats: string,
  ) {
    return this.driverTripFee.computeExpectedFee({
      seatPrice: Number(seatPrice ?? 0),
      totalSeats: Number(totalSeats ?? 0),
    });
  }
```

Inject `private readonly driverTripFee: DriverTripFeeService` into the controller and add `Query` to the `@nestjs/common` import list.

- [ ] **Step 6: Run tests to verify they pass**

Run: `npm test -- trips.service.spec`
Expected: PASS.

Verify the route ordering by hand:
```bash
cd rideshare-backend && npm run start:dev
curl "http://localhost:3000/trips/fee-quote?seatPrice=4&totalSeats=4"
```
Expected: `{"amount":1.6,"seatPrice":4,"totalSeats":4,"percent":10,"currency":"JOD"}` — **not** a 404 "Trip not found", which would mean the route landed below `@Get(':id')`.

- [ ] **Step 7: Verify the app still boots (catches DI cycles)**

Run: `npm run build`
Expected: build succeeds. A `Nest can't resolve dependencies` or circular-import error here means `DriverTripFeeModule` was wired into a cycle — check that it is not imported by `WalletModule` or `PendingChargesModule`.

- [ ] **Step 8: Lint and commit**

```bash
cd rideshare-backend && npm run lint
git add src/modules/trips/trips.service.ts src/modules/trips/trips.controller.ts \
        src/modules/trips/trips.module.ts src/modules/trips/trips.service.spec.ts
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(trips): block publishing when the wallet cannot cover the trip fee

Also adds GET /trips/fee-quote so the create-trip screen can show the
real percentage before a trip row exists.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Charge on trip auto-start

**Files:**
- Modify: `rideshare-backend/src/modules/bookings/processors/trip-auto-start.processor.ts`
- Modify: `rideshare-backend/src/modules/bookings/bookings.module.ts`
- Create: `rideshare-backend/src/modules/bookings/processors/trip-auto-start.processor.spec.ts`

**Interfaces:**
- Consumes: `DriverTripFeeService.chargeAtTripStart(trip): Promise<TripFeeChargeResult>` (Task 3).
- Produces: nothing downstream.

- [ ] **Step 1: Write the failing test**

Create `rideshare-backend/src/modules/bookings/processors/trip-auto-start.processor.spec.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { getQueueToken } from '@nestjs/bull';
import { TripEntity } from '../../../database/entities/trip.entity';
import { BookingEntity, BookingStatus } from '../../../database/entities/booking.entity';
import { TripStatus } from '../../../database/entities/shared.enums';
import { NotificationsService } from '../../notifications/notifications.service';
import { DriverTripFeeService } from '../../driver-trip-fee/driver-trip-fee.service';
import { TripAutoStartProcessor } from './trip-auto-start.processor';

describe('TripAutoStartProcessor — fee charging', () => {
  let processor: TripAutoStartProcessor;
  let trip: any;
  let driverTripFee: { chargeAtTripStart: jest.Mock };

  beforeEach(async () => {
    trip = {
      id: 'trip-1',
      driverId: 'driver-1',
      status: TripStatus.PUBLISHED,
      departureTime: new Date(),
      toName: 'الطفيلة',
      price: 4,
      totalSeats: 4,
    };
    driverTripFee = {
      chargeAtTripStart: jest
        .fn()
        .mockResolvedValue({ charged: 1.6, pendingRemainder: 0, applied: true }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TripAutoStartProcessor,
        {
          provide: getRepositoryToken(TripEntity),
          useValue: { findOne: async () => trip, save: async (t: any) => t },
        },
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: { find: async () => [], save: async (b: any) => b },
        },
        { provide: getQueueToken('trip-auto-complete'), useValue: { add: jest.fn() } },
        { provide: NotificationsService, useValue: { create: jest.fn().mockResolvedValue({}) } },
        { provide: DriverTripFeeService, useValue: driverTripFee },
      ],
    }).compile();

    processor = module.get(TripAutoStartProcessor);
  });

  it('charges the fee once the trip has started', async () => {
    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(trip.status).toBe(TripStatus.IN_PROGRESS);
    expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledTimes(1);
    expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledWith(trip);
  });

  it('still starts the trip when the fee charge throws', async () => {
    driverTripFee.chargeAtTripStart.mockRejectedValue(new Error('ledger down'));

    await expect(
      processor.handle({ data: { tripId: 'trip-1' } } as any),
    ).resolves.toBeUndefined();

    expect(trip.status).toBe(TripStatus.IN_PROGRESS);
  });

  it('does not charge a trip that was already in progress', async () => {
    trip.status = TripStatus.IN_PROGRESS;

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
  });

  it('does not charge a cancelled trip', async () => {
    trip.status = TripStatus.CANCELLED;

    await processor.handle({ data: { tripId: 'trip-1' } } as any);

    expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- trip-auto-start.processor.spec`
Expected: FAIL — Nest cannot resolve `DriverTripFeeService` for `TripAutoStartProcessor`.

- [ ] **Step 3: Wire the charge into the processor**

In `trip-auto-start.processor.ts`, add the constructor dependency:

```typescript
    private readonly driverTripFee: DriverTripFeeService,
```

and, immediately after the booking-status loop and before the notification loop, insert:

```typescript
    // The one debit for this trip. A failure here must not stop the trip: the
    // reconciliation sweep re-runs any trip left with driverWalletChargeApplied
    // still false.
    try {
      await this.driverTripFee.chargeAtTripStart(trip);
    } catch (err) {
      this.logger.error(
        `trip-auto-start: fee charge failed for trip ${tripId}: ${(err as Error).message}`,
      );
    }
```

Note the early-return branch for `TripStatus.IN_PROGRESS` above it already prevents a double charge for a trip started by another path — leave it as it is.

In `bookings.module.ts`, add `DriverTripFeeModule` to `imports`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm test -- trip-auto-start.processor.spec`
Expected: PASS, 4 tests.

- [ ] **Step 5: Build and commit**

```bash
cd rideshare-backend && npm run build && npm run lint
git add src/modules/bookings/processors/trip-auto-start.processor.ts \
        src/modules/bookings/processors/trip-auto-start.processor.spec.ts \
        src/modules/bookings/bookings.module.ts
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(trips): debit the driver fee when the trip auto-starts

A failed debit is logged and never blocks the trip from starting.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Remove the contact gate

**Files:**
- Modify: `rideshare-backend/src/modules/calls/calls.service.ts:49`
- Modify: `rideshare-backend/src/modules/chat/chat-postgres.service.ts:62,158,217,242,318`
- Modify: `rideshare-backend/src/modules/chat/chat.service.ts:119`
- Modify: `rideshare-backend/src/modules/bookings/serializers/booking-viewer.serializer.ts`
- Create: `rideshare-backend/src/modules/bookings/serializers/booking-viewer.serializer.spec.ts` (does not exist today)
- Create: `rideshare-backend/src/modules/calls/calls.service.spec.ts` (does not exist today)

**Interfaces:**
- Consumes: nothing.
- Produces: `BookingViewerSerializer.serialize<T>(data: T, viewer?: ViewerRole): T` keeps its signature; `MaskableBookingView` loses `hasDriverPaidToContact` and `settledAt`.

- [ ] **Step 1: Write the failing tests**

Create `rideshare-backend/src/modules/bookings/serializers/booking-viewer.serializer.spec.ts`:

```typescript
import { BookingViewerSerializer } from './booking-viewer.serializer';

describe('BookingViewerSerializer', () => {
  const raw = {
    chatEnabled: false,
    callEnabled: false,
    otherParty: {
      displayName: 'أحمد محمود',
      phone: '0790000000',
      phoneNumber: '+962790000000',
      photoUrl: 'https://cdn/x.jpg',
    },
  };

  it('reveals contact details to the driver with no payment', () => {
    const out = BookingViewerSerializer.serialize({ ...raw }, 'driver');

    expect(out.otherParty?.displayName).toBe('أحمد محمود');
    expect(out.otherParty?.phone).toBe('0790000000');
    expect(out.otherParty?.phoneNumber).toBe('+962790000000');
    expect(out.otherParty?.photoUrl).toBe('https://cdn/x.jpg');
  });

  it('enables chat and call for every viewer role', () => {
    for (const role of ['driver', 'passenger', 'admin'] as const) {
      const out = BookingViewerSerializer.serialize({ ...raw }, role);
      expect(out.chatEnabled).toBe(true);
      expect(out.callEnabled).toBe(true);
    }
  });

  it('never emits the *** mask', () => {
    const out = BookingViewerSerializer.serialize({ ...raw }, 'driver');
    expect(JSON.stringify(out)).not.toContain('***');
  });
});
```

Create `rideshare-backend/src/modules/calls/calls.service.spec.ts`. Read `calls.service.ts` first to mirror its constructor dependencies in the testing module, and to get the real name of the initiate method and its DTO:

```typescript
it('allows a call on a confirmed booking that was never paid for', async () => {
  bookingRepo.findOne.mockResolvedValue({
    id: 'b-1',
    status: BookingStatus.CONFIRMED,
    hasDriverPaidToContact: false,
    trip: { driverId: 'driver-1' },
    userId: 'rider-1',
  });

  await expect(
    service.initiateCall('driver-1', { bookingId: 'b-1' } as any),
  ).resolves.toBeDefined();
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm test -- booking-viewer.serializer.spec calls.service.spec`
Expected: FAIL — the serializer masks to `***`, and the call is rejected with `hasDriverPaidToContact` false.

- [ ] **Step 3: Rewrite the serializer**

Replace the whole body of `booking-viewer.serializer.ts`:

```typescript
/**
 * BookingViewerSerializer
 *
 * Contact details are no longer gated behind a driver payment — the platform
 * fee is charged at trip start and unlocks nothing. This serializer is kept as
 * the single seam where a future access rule would live; today it only asserts
 * that chat and call are enabled for every viewer.
 */

export type ViewerRole = 'passenger' | 'driver' | 'admin';

/** Minimum shape the serializer touches. */
export interface MaskableBookingView {
  chatEnabled?: boolean;
  callEnabled?: boolean;
  otherParty?: {
    displayName?: string | null;
    phone?: string | null;
    phoneNumber?: string | null;
    photoUrl?: string | null;
    [key: string]: unknown;
  };
}

export class BookingViewerSerializer {
  static serialize<T extends MaskableBookingView>(
    data: T,
    _viewer?: ViewerRole,
  ): T {
    return {
      ...data,
      chatEnabled: true,
      callEnabled: true,
    };
  }
}
```

- [ ] **Step 4: Delete the four gate checks**

- `calls.service.ts:49` — delete the `if (!booking.hasDriverPaidToContact) { throw ... }` block.
- `chat-postgres.service.ts` — delete the guards at L62, L158, L242 and L318. At L217, the `.filter((b) => b.hasDriverPaidToContact || trip.driverWalletChargeApplied)` becomes no filter at all: every confirmed booking gets a room.
- `chat.service.ts:119` — delete the `if (!hasPaidFee && !(trip as any).driverWalletChargeApplied)` block and the now-unused `hasPaidFee` local.

Remove any imports left unused by the deletions.

- [ ] **Step 5: Confirm nothing else gates on the flag**

Run: `grep -rn "hasDriverPaidToContact\|driverWalletChargeApplied" rideshare-backend/src --include=*.ts | grep -v spec | grep -v migrations`

Expected remaining hits only: the entity column definitions, `driver-trip-fee.service.ts` (writes), `admin-dashboard.service.ts` (reads for display), `bookings.service.ts` (keeps the columns in sync), and the response schemas. No `if`/`filter`/`throw` on either flag.

`bookings.service.ts` lines 256, 318, 762, 948 and the 541-560 backfill block set these columns from `trip.driverWalletChargeApplied` — leave them; they now mean "the fee was already taken for this trip", which stays true.

- [ ] **Step 6: Run tests to verify they pass**

Run: `npm test -- booking-viewer.serializer.spec calls.service.spec chat`
Expected: PASS. Existing chat/call specs asserting the *locked* behaviour will fail — delete those specific assertions; they encode a rule this plan removes.

- [ ] **Step 7: Lint and commit**

```bash
cd rideshare-backend && npm run lint
git add src/modules/calls src/modules/chat src/modules/bookings/serializers
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(contact): open passenger contact without a payment gate

Chat, calls and the booking serializer no longer read
hasDriverPaidToContact. The column stays as an audit stamp.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Delete the hold machinery and strip presence of its financial role

**Files:**
- Delete: `rideshare-backend/src/modules/wallet/wallet-hold.service.ts`, `wallet-hold.service.spec.ts`
- Modify: `rideshare-backend/src/modules/wallet/wallet.module.ts`
- Modify: `rideshare-backend/src/modules/wallet/wallet.service.ts` (delete `chargeDriverTripFee`, `presenceBillingEnabled`), `wallet.service.spec.ts`
- Modify: `rideshare-backend/src/modules/wallet/wallet.controller.ts:52-60`
- Modify: `rideshare-backend/src/modules/trip-time/presence.service.ts:174-200, 507-600`, `presence.service.spec.ts`
- Modify: `rideshare-backend/src/modules/trip-time/trip-time.module.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: `PresenceService.settleTripPresence(tripId: string, manager?: EntityManager): Promise<SettlementOutcome>` keeps its signature and its `captured`/`released` fields, which are now always `0`.

- [ ] **Step 1: Update the presence tests first**

In `presence.service.spec.ts`, replace every assertion about `settleHold`, `captured` and `released` with:

```typescript
it('records presence without moving any money', async () => {
  const outcome = await service.settleTripPresence('trip-1');

  expect(outcome.captured).toBe(0);
  expect(outcome.released).toBe(0);
  expect(outcome.billableSeats).toBe(2);
  expect(trip.presenceSettledAt).toBeInstanceOf(Date);
});

it('leaves capturedFeeAmount alone — it belongs to the trip-start charge', async () => {
  trip.capturedFeeAmount = '1.60';

  await service.settleTripPresence('trip-1');

  expect(trip.capturedFeeAmount).toBe('1.60');
});

it('flags a trip for review when seats existed but nobody confirmed', async () => {
  seats.forEach((s) => (s.passengerSelfConfirmedAt = null));

  await service.settleTripPresence('trip-1');

  expect(trip.presenceReviewFlagged).toBe(true);
});
```

Remove the `WalletHoldService` provider from the spec's testing module.

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm test -- presence.service.spec`
Expected: FAIL — the service still injects `WalletHoldService`.

- [ ] **Step 3: Strip `PresenceService`**

- Remove the `WalletHoldService` import and constructor parameter.
- `pricingFor(trip)`: delete the hold-metadata branch; read `PlatformPricingService.getActiveFeeRow('JO')` then `driverUnlockPricing(trip, row)` directly.
- `settleTripPresence`: delete the `try/catch` around `settleHold` and the `result` variable. Keep the `presenceSettledAt`, `billableSeatCount` and `presenceReviewFlagged` writes; **delete the `trip.capturedFeeAmount = ...` assignment**. Return `captured: 0, released: 0, applied: false`.
- `buildRoster`: keep `estimatedFee` but compute it as the fixed all-seats fee (`seatPrice * (trip.totalSeats ?? 0) * percent / 100`, i.e. the existing `maxFee`), and delete `estimatedRelease` from the `summary` object.
- Update the method docblock: it settles presence, not money.

- [ ] **Step 4: Delete the hold service and the unlock endpoint**

```bash
cd rideshare-backend
git rm src/modules/wallet/wallet-hold.service.ts src/modules/wallet/wallet-hold.service.spec.ts
```

- `wallet.module.ts`: drop `WalletHoldService` from `providers` and `exports`, drop its import. Keep `WalletHoldEntity` in `forFeature` — `getActiveHolds` still reads historical rows.
- `wallet.service.ts`: delete `chargeDriverTripFee` in full, delete `presenceBillingEnabled()`, delete the `WalletHoldService` import and constructor parameter. Keep `assertNonNegativeDriverBalance` — `driver-availability.service.ts:224` still calls it for going online.
- `wallet.controller.ts`: delete the `@Post('driver/trip-charge')` route and its `chargeDriverTrip` handler. Delete the now-unused DTO import; delete the DTO file if nothing else references it.
- `trip-time.module.ts`: `WalletModule` is still imported for other reasons — verify with `grep -n "walletService\|WalletService" src/modules/trip-time/*.ts` and drop the import only if there are no hits.
- Remove the `PRESENCE_BILLING_ENABLED` entry from `.env.example` / `docker-compose.yml` if present.

- [ ] **Step 5: Run the full suite**

Run: `npm test`
Expected: PASS. Anything still importing `WalletHoldService` fails to compile — fix each by deleting the usage, not by re-adding the service.

- [ ] **Step 6: Build, lint and commit**

```bash
cd rideshare-backend && npm run build && npm run lint
git add -A src/modules/wallet src/modules/trip-time
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "refactor(wallet): delete wallet holds and the pay-to-unlock endpoint

Presence settlement keeps its bookkeeping and loses all money movement;
the fee is now a single debit at trip start.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Migration — return reserved money and stamp settled trips

**Files:**
- Create: `rideshare-backend/src/database/migrations/1747100000000-release-wallet-holds-fee-at-trip-start.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: no active `wallet_holds` rows remain; drivers' balances are restored; trips already charged under the old model are stamped so Task 3 never double-charges them.

Without this task, every driver with a live trip loses the reserved amount permanently — the code that would have released it is deleted in Task 7.

- [ ] **Step 1: Inspect the live schema**

Run:
```bash
grep -n "status\|reservedBalance\|capturedAmount\|releasedAmount" rideshare-backend/src/database/entities/wallet-hold.entity.ts
grep -n "WalletHoldStatus" -A 8 rideshare-backend/src/database/entities/wallet-hold.entity.ts
```

Record the exact table name, the enum values for an *active* hold, and the column names. The SQL below uses `'active'` — replace it with whatever the enum actually holds.

- [ ] **Step 2: Write the migration**

```typescript
import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Fee-at-trip-start cutover.
 *
 * The hold mechanism is gone, so every still-active hold would otherwise strand
 * a driver's money in reservedBalance with no code left to release it. This
 * returns the reservation and closes the row.
 *
 * Trips that already had their fee captured under the old presence-settlement
 * model are stamped as charged so the new trip-start debit skips them.
 */
export class ReleaseWalletHoldsFeeAtTripStart1747100000000
  implements MigrationInterface
{
  name = 'ReleaseWalletHoldsFeeAtTripStart1747100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Give back every reservation still sitting on an account.
    await queryRunner.query(`
      UPDATE "wallet_accounts" wa
      SET "reservedBalance" = '0.00'
      WHERE wa."reservedBalance" <> '0.00'
    `);

    // 2. Close the open holds with an audit note. Balance is untouched: an
    //    active hold only ever moved reservedBalance, never balance.
    await queryRunner.query(`
      UPDATE "wallet_holds"
      SET "status" = 'released',
          "releasedAmount" = "amount",
          "capturedAmount" = '0.00',
          "metadata" = COALESCE("metadata", '{}'::jsonb)
                       || '{"migration":"fee-at-trip-start"}'::jsonb
      WHERE "status" = 'active'
    `);

    // 3. Reverse the pending ledger rows those holds created.
    await queryRunner.query(`
      UPDATE "wallet_transactions"
      SET "status" = 'reversed'
      WHERE "type" = 'hold' AND "status" = 'pending'
    `);

    // 4. Any trip already past its departure that was charged under the old
    //    model keeps that charge and is stamped so the new debit skips it.
    await queryRunner.query(`
      UPDATE "trips"
      SET "driverWalletChargeApplied" = true
      WHERE "presenceSettledAt" IS NOT NULL
        AND "driverWalletChargeApplied" = false
    `);
  }

  public async down(): Promise<void> {
    // Releasing money to drivers is not reversible by migration. Restore from a
    // backup if this cutover has to be undone.
  }
}
```

- [ ] **Step 3: Verify against a real database**

```bash
cd rideshare-backend
docker compose up -d postgres    # if not already running
npm run typeorm -- migration:run -d ./src/database/data-source.ts
```

(Check the actual migration script name with `grep -n "typeorm\|migration" package.json` — use whatever the repo defines.)

Then confirm:
```sql
SELECT count(*) FROM wallet_holds WHERE status = 'active';        -- expect 0
SELECT count(*) FROM wallet_accounts WHERE "reservedBalance" <> '0.00';  -- expect 0
```

- [ ] **Step 4: Commit**

```bash
git add src/database/migrations/1747100000000-release-wallet-holds-fee-at-trip-start.ts
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(db): release live wallet holds for the fee-at-trip-start cutover

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Reconciliation sweep for failed debits

**Files:**
- Modify: `rideshare-backend/src/modules/bookings/processors/trip-auto-complete.processor.ts`
- Test: `rideshare-backend/src/modules/bookings/processors/trip-auto-complete.processor.spec.ts`

**Interfaces:**
- Consumes: `DriverTripFeeService.chargeAtTripStart(trip)` (Task 3).
- Produces: nothing downstream.

Task 5 deliberately swallows a debit failure so the trip can start. This is the net that catches it.

- [ ] **Step 1: Read the processor**

Run: `sed -n '1,80p' rideshare-backend/src/modules/bookings/processors/trip-auto-complete.processor.ts`

Note where it calls `settleTripPresence` — the sweep goes right before it.

- [ ] **Step 2: Write the failing test**

```typescript
it('charges a trip whose start-time debit never landed', async () => {
  trip.driverWalletChargeApplied = false;

  await processor.handle({ data: { tripId: 'trip-1' } } as any);

  expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledWith(trip);
});

it('does not re-charge a trip already stamped', async () => {
  trip.driverWalletChargeApplied = true;

  await processor.handle({ data: { tripId: 'trip-1' } } as any);

  expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `npm test -- trip-auto-complete.processor.spec`
Expected: FAIL — `chargeAtTripStart` never called.

- [ ] **Step 4: Add the sweep**

Inject `DriverTripFeeService` and add before the presence settlement:

```typescript
    // Net for a debit that failed at trip start. chargeAtTripStart is itself
    // idempotent; this guard just avoids a pointless round-trip.
    if (!trip.driverWalletChargeApplied) {
      try {
        await this.driverTripFee.chargeAtTripStart(trip);
      } catch (err) {
        this.logger.error(
          `trip-auto-complete: fee reconciliation failed for ${trip.id}: ${(err as Error).message}`,
        );
      }
    }
```

- [ ] **Step 5: Run tests and commit**

```bash
cd rideshare-backend && npm test && npm run lint
git add src/modules/bookings/processors/trip-auto-complete.processor.ts \
        src/modules/bookings/processors/trip-auto-complete.processor.spec.ts
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(fee): reconcile trips whose start-time debit failed

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Mobile — delete both pay-to-unlock flows and open the contact rows

**Files:**
- Modify: `rideshare/lib/screens/driver/trip_management_screen.dart` (L391-497, L754-756, L1049-1140, L1158, L1174-1180, L2177-2215)
- Modify: `rideshare/lib/screens/driver/my_trips_screen.dart` (L256-L340)
- Modify: `rideshare/lib/screens/driver/widgets/passengers_card.dart` (L72, L78, L98)
- Modify: `rideshare/lib/screens/driver/passenger_details_screen.dart:49`
- Modify: `rideshare/lib/screens/home/widgets/booking_card.dart:251`
- Modify: `rideshare/lib/core/services/payment_service.dart`, `rideshare/lib/providers/trip_provider.dart`
- Modify: `rideshare/lib/l10n/app_ar.arb`, `rideshare/lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: nothing.
- Produces: `BookingModel.hasDriverPaidToContact` still parses from JSON but no widget branches on it.

`my_trips_screen.dart` carries a **second complete copy** of the invoice-and-pay flow (`_tripFeeAmount` L256, the dialog L260-305, `_invoiceRow` L309, `_payTripFee` L325). Missing it leaves a live payment path in the app.

- [ ] **Step 1: Write the failing widget test**

Create `rideshare/test/driver/passengers_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('passenger contact and call button show without payment',
      (tester) async {
    final booking = BookingModel(
      id: 'b-1',
      hasDriverPaidToContact: false,
      userPopulated: UserModel(
        id: 'u-1',
        name: 'أحمد محمود',
        phoneNumber: '0790000000',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PassengersCard(booking: booking))),
    );

    expect(find.text('أحمد محمود'), findsOneWidget);
    expect(find.text('***'), findsNothing);
    expect(find.byIcon(IconsaxPlusLinear.call), findsOneWidget);
  });
}
```

Adapt the constructor arguments to the real `BookingModel` and `PassengersCard` signatures — read them first with `sed -n '80,120p' rideshare/lib/models/booking_model.dart` and `sed -n '1,45p' rideshare/lib/screens/driver/widgets/passengers_card.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd rideshare && flutter test test/driver/passengers_card_test.dart`
Expected: FAIL — the name is masked and the call button is absent.

- [ ] **Step 3: Delete the fee UI in `trip_management_screen.dart`**

Remove: `_isPayingTripFee` (L54), `_baseTripFeeAmount` (L379), `_tripFeeAmount` (L386), `_showTripFeeInvoice` (L391), `_invoiceRow`, `_payTripFee` (L475), `_buildTripFeePaymentCard` (L1049) and its call site (L755), the `confirmBookingUnlocksDetails` hint (L1158), and the `chatAvailableAfterFee` fallback (L1174-1180).

- [ ] **Step 4: Delete the duplicate fee UI in `my_trips_screen.dart`**

Remove `_tripFeeAmount` (L256), the invoice dialog it feeds (L260-305), `_invoiceRow` (L309) and `_payTripFee` (L325), plus the button that opens the dialog. Follow the compiler: `flutter analyze` names every orphaned reference.

- [ ] **Step 5: Open the contact rows**

Delete the `hasDriverPaidToContact` condition at each site, keeping the "unlocked" branch:

| File | Lines |
|---|---|
| `trip_management_screen.dart` | 1174, 2177, 2183, 2209 |
| `passengers_card.dart` | 72, 78, 98 |
| `passenger_details_screen.dart` | 49 (`hasData` becomes `user != null`) |
| `booking_card.dart` | 251 (keep the `!isPastTrip` half) |

- [ ] **Step 6: Remove the client-side charge call**

In `payment_service.dart` and `trip_provider.dart`, delete the method that posts to `/wallet/driver/trip-charge` and any provider state it fed. `flutter analyze` will point at the leftovers.

- [ ] **Step 7: Delete the dead strings**

From both `app_ar.arb` and `app_en.arb` remove: `chatAvailableAfterFee`, `tripFeeInvoiceTitle`, `tripFeePaidSuccess`, `tripFeeReady`, `tripFeeBreakdown`, `tripFeeBreakdownWithFreeTrip`, `tripFeeFullExplanation`, `tripFeePaidLabel`, `confirmBookingUnlocksDetails`, and `payFees`/`feePercentage` **only if** `grep -rn "payFees\|feePercentage" rideshare/lib --include=*.dart` returns nothing outside the generated files. Delete each key's `@`-metadata block too.

Regenerate: `cd rideshare && flutter gen-l10n`

- [ ] **Step 8: Run tests to verify they pass**

```bash
cd rideshare && flutter analyze && flutter test
```
Expected: analyze clean, tests PASS.

- [ ] **Step 9: Commit**

```bash
git add rideshare/lib rideshare/test
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(mobile): remove pay-to-unlock and open passenger contact

Deletes both copies of the fee invoice flow (trip management and my
trips) and shows name, phone, call and chat unconditionally.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Mobile — fee notice at publish time and the insufficient-balance path

**Files:**
- Modify: `rideshare/lib/screens/driver/create_trip/` (the review step widget)
- Modify: `rideshare/lib/screens/driver/create_trip_screen.dart`
- Modify: `rideshare/lib/l10n/app_ar.arb`, `rideshare/lib/l10n/app_en.arb`
- Modify: `rideshare/lib/screens/driver/trip_summary_screen.dart`
- Test: `rideshare/test/driver/create_trip_fee_notice_test.dart`

**Interfaces:**
- Consumes: `GET /trips/fee-quote?seatPrice={n}&totalSeats={n}` → `{ amount, seatPrice, totalSeats, percent, currency }` (Task 4); the trip-create endpoint's 403 body `{ code: 'INSUFFICIENT_BALANCE_FOR_TRIP_FEE', balance, requiredAmount, currency }` (Task 2).
- Produces: nothing downstream.

With the payment step gone, the review step is the only place the driver sees the number before committing. The percentage must come from `/trips/fee-quote` — both deleted invoices hardcoded `'5%'` while the backend charges `driverUnlockPercent`.

- [ ] **Step 1: Add the endpoint to the API client**

Add `feeQuote` to `rideshare/lib/core/api/api_endpoints.dart` as `'/trips/fee-quote'`, and a `getTripFeeQuote({required double seatPrice, required int totalSeats})` method to `rideshare/lib/core/services/trip_service.dart` returning a small `TripFeeQuote` model with `amount`, `percent` and `currency`. Follow the request/parse shape of the neighbouring methods in that file.

- [ ] **Step 2: Add the strings**

`app_ar.arb`:
```json
  "createTripFeeNotice": "رسوم الرحلة ({percent}%): {amount} {currency} — تُخصم من محفظتك عند انطلاق الرحلة.",
  "@createTripFeeNotice": {
    "placeholders": {
      "percent": {},
      "amount": {},
      "currency": {}
    }
  },
  "insufficientBalanceForTripFee": "رصيد محفظتك ({balance}) لا يغطي رسوم الرحلة ({required}). اشحن محفظتك قبل نشر الرحلة.",
  "@insufficientBalanceForTripFee": {
    "placeholders": {
      "balance": {},
      "required": {}
    }
  },
  "topUpWallet": "اشحن المحفظة",
```

`app_en.arb`:
```json
  "createTripFeeNotice": "Trip fee ({percent}%): {amount} {currency} — deducted from your wallet when the trip starts.",
  "@createTripFeeNotice": {
    "placeholders": {
      "percent": {},
      "amount": {},
      "currency": {}
    }
  },
  "insufficientBalanceForTripFee": "Your wallet balance ({balance}) does not cover the trip fee ({required}). Top up before publishing.",
  "@insufficientBalanceForTripFee": {
    "placeholders": {
      "balance": {},
      "required": {}
    }
  },
  "topUpWallet": "Top up wallet",
```

- [ ] **Step 3: Fix the stale end-of-trip copy**

In both ARB files, change `tripSummaryFeeDeducted`:

```json
  "tripSummaryFeeDeducted": "تم خصم رسوم الرحلة ({amount}) من محفظتك عند انطلاق الرحلة. تأكد من وجود رصيد كافٍ في محفظتك لإنشاء رحلات جديدة."
```

and the English equivalent. The design mock the feature came from says «عند انتهاء الرحلة» — that wording is superseded by the spec.

Regenerate: `flutter gen-l10n`

- [ ] **Step 4: Write the failing test**

Create `rideshare/test/driver/create_trip_fee_notice_test.dart`. Replace `Step3Review` and its argument names with the real review-step widget — find it with `ls rideshare/lib/screens/driver/create_trip/` and read its constructor.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('review step shows the fee and when it will be charged',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Step3Review(
            seatPrice: 4.0,
            totalSeats: 4,
            feeQuote: const TripFeeQuote(
              amount: 1.6,
              percent: 10,
              currency: 'JOD',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1.60'), findsOneWidget);
    expect(find.textContaining('عند انطلاق الرحلة'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run test to verify it fails**

Run: `cd rideshare && flutter test test/driver/create_trip_fee_notice_test.dart`
Expected: FAIL — no fee line rendered.

- [ ] **Step 6: Render the notice and handle the 403**

Add the notice row to the review step, computing `amount = seatPrice * totalSeats * percent / 100` with the percent fetched in Step 1 — never a literal.

In the publish handler, catch the 403 and, when `code == 'INSUFFICIENT_BALANCE_FOR_TRIP_FEE'`, show a dialog with `insufficientBalanceForTripFee` and a `topUpWallet` action routing to the driver wallet screen.

- [ ] **Step 7: Run tests and commit**

```bash
cd rideshare && flutter analyze && flutter test
git add rideshare/lib rideshare/test
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(mobile): show the trip fee before publishing

Reads the percentage from the API instead of the hardcoded 5% both
deleted invoices used, and offers a top-up when the balance is short.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Dashboard — relabel the flag

**Files:**
- Modify: `rideshare-dashboard/src/pages/trips/trip-detail.tsx:375`
- Modify: `rideshare-dashboard/src/i18n/translations.ts`

**Interfaces:**
- Consumes: `hasDriverPaidToContact` from `admin-dashboard.service.ts:661`; the type stays declared at `rideshare-dashboard/src/types/models.ts:149`.
- Produces: nothing downstream.

- [ ] **Step 1: Read the render site and its label keys**

Run:
```bash
sed -n '365,390p' rideshare-dashboard/src/pages/trips/trip-detail.tsx
```

Note the translation keys used in the ternary's two branches.

- [ ] **Step 2: Relabel in `translations.ts`**

The flag now means "the platform fee was charged for this trip", not "the driver unlocked contact". Change the two labels the ternary renders to «الرسوم مخصومة» / "Fee charged" and «الرسوم غير مخصومة» / "Fee not charged". Do not remove the column — it is the admin's view of whether a trip was billed.

- [ ] **Step 3: Verify and commit**

```bash
cd rideshare-dashboard && npm run build
git add rideshare-dashboard/src/pages/trips/trip-detail.tsx rideshare-dashboard/src/i18n/translations.ts
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "chore(dashboard): relabel hasDriverPaidToContact as fee charged

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: Mobile — rebuild the pre-departure state to match the design mock

**Files:**
- Modify: `rideshare/lib/screens/driver/trip_management_screen.dart`
- Create: `rideshare/lib/screens/driver/widgets/trip_route_card.dart`
- Create: `rideshare/lib/screens/driver/widgets/trip_facts_strip.dart`
- Create: `rideshare/lib/screens/driver/widgets/trip_fare_breakdown_card.dart`
- Modify: `rideshare/lib/screens/driver/widgets/passengers_card.dart`
- Modify: `rideshare/lib/l10n/app_ar.arb`, `rideshare/lib/l10n/app_en.arb`
- Test: `rideshare/test/driver/trip_management_pre_departure_test.dart`

**Interfaces:**
- Consumes: `TripModel` (`from`/`to` as `LocationModel` with `name` + `address`, `departureTime`, `distanceKm`, `price`, `currency`, `totalSeats`, `availableSeats`, `status`, `tripStartedAt`), `BookingModel.seats` (`BookingSeatModel.seatNumber`, `displayName`), `BookingModel.userPopulated` (`UserModel.name`, `rating`, `photoUrl`, `phoneNumber`). All verified to exist.
- Produces: nothing downstream.

**Locked decisions:**
- This is the **pre-departure state of the existing screen**, not a new screen and not a full replacement. When `trip.tripStartedAt == null` the body renders exactly the mock's sections in the mock's order. Once the trip starts, the existing live-tracking and "وصلت" cards return.
- **Colours come from the app theme, not the mock.** The mock's forest green is replaced by `Theme.of(context).colorScheme.primary` (`teal600 #0D9488`). Never hardcode the mock's green.

**Pre-departure body, top to bottom — the mock's exact order:**

1. **Header** — a circular white back button at the screen's start edge; centred title `tripBookedTitle` with a filled check-circle icon in `colorScheme.primary`; subtitle `tripBookedSubtitle` in `textSecondary`.
2. **Route card** (`trip_route_card.dart`) — white, `borderRadius: 16`, soft shadow. Origin at the start edge with a small filled `primary` dot above `trip.from.name`; destination at the end edge with a red map-pin above `trip.to.name`; between them a dashed connector with a car glyph in a filled `primary` circle at its centre. Labels «من» / «إلى» sit above the names in `textTertiary`.
3. **Facts strip** (`trip_facts_strip.dart`) — inside the same card, below a `divider`. Five equal columns, each an icon over a label over a value: `tripDayLabel` (calendar), `tripTimeLabel` (clock), `tripMeetingPointLabel` (pin), `tripDistanceLabel` (route), `tripSeatsLabel` (people). Values: formatted weekday + date, formatted time, `trip.from.address` (see the fallback below), `'${trip.distanceKm!.round()} كم'`, `'${booked} من ${trip.totalSeats}'` with «مكتملة» beneath in `success` when `trip.availableSeats == 0`.
4. **Section header** — `bookedPassengersTitle(count)`.
5. **Passenger rows** — one per seat, not per booking: a booking of 2 seats renders 2 rows. Avatar, name, `star` icon + `rating.toStringAsFixed(1)`, a seat chip `seatLabel(seatNumber)` on a `primaryContainer` background, then a `chat` outlined button and a `call` outlined button. Contact is unconditional — Task 10 removed the gate.
6. **Fare card** (`trip_fare_breakdown_card.dart`) — three rows: `passengerFareLabel` → `trip.price`; `passengersTotalLabel(count)` → `price × bookedSeats`; `tripFeePercentLabel(percent)` → the fee, rendered in `colorScheme.error`. The percent and amount come from the `/trips/fee-quote` client added in Task 11 — never a literal.
7. **Fee notice** — an info box on `primaryContainer` with an info icon, showing `tripFeeChargedAtStartNotice`.
8. **Contact bar** — a white bar with a chat icon button at the start edge and a `primary`-tinted action at the end edge: `contactPassengersTitle` over `contactPassengersSubtitle`.
9. **Primary CTA** — full-width filled `primary` button, `confirmYourPresenceCta`, wired to the existing driver presence-confirmation call.

**One data gap:** the mock's «مكان التجمع» has no dedicated field. `trip.from.address` (backed by `trips.fromAddress`, nullable) is the closest match. When it is null, render `trip.from.name` rather than an empty cell. Do **not** add a new column for this — it is out of scope.

- [ ] **Step 1: Read the current screen before touching it**

```bash
cd rideshare
sed -n '600,800p' lib/screens/driver/trip_management_screen.dart
grep -n "Widget _build" lib/screens/driver/trip_management_screen.dart
```

Note which cards guard on trip status already, and how the driver presence-confirmation action is currently invoked — Step 9's CTA reuses it rather than adding a new call.

- [ ] **Step 2: Add the strings**

`app_ar.arb`:
```json
  "tripBookedTitle": "تم حجز رحلتك المشتركة",
  "tripBookedSubtitle": "تم حجز جميع المقاعد بنجاح",
  "tripDayLabel": "يوم الرحلة",
  "tripTimeLabel": "موعد الرحلة",
  "tripMeetingPointLabel": "مكان التجمع",
  "tripDistanceLabel": "المسافة",
  "tripSeatsLabel": "عدد المقاعد",
  "tripSeatsComplete": "مكتملة",
  "tripSeatsBookedOf": "{booked} من {total}",
  "@tripSeatsBookedOf": {
    "placeholders": { "booked": {}, "total": {} }
  },
  "tripDistanceKm": "{km} كم",
  "@tripDistanceKm": { "placeholders": { "km": {} } },
  "bookedPassengersTitle": "الركاب المحجوزون ({count})",
  "@bookedPassengersTitle": { "placeholders": { "count": {} } },
  "seatLabel": "مقعد {number}",
  "@seatLabel": { "placeholders": { "number": {} } },
  "passengerFareLabel": "أجرة الراكب",
  "passengersTotalLabel": "المجموع من الركاب ({count}) ركاب",
  "@passengersTotalLabel": { "placeholders": { "count": {} } },
  "tripFeePercentLabel": "رسوم الرحلة ({percent}%)",
  "@tripFeePercentLabel": { "placeholders": { "percent": {} } },
  "tripFeeChargedAtStartNotice": "سيتم خصم رسوم الرحلة من محفظتك عند انطلاق الرحلة. حافظ على وجود رصيد في محفظتك لضمان قدرتك على إنشاء رحلات جديدة.",
  "contactPassengersTitle": "التواصل مع الركاب",
  "contactPassengersSubtitle": "اتصال أو دردشة حية",
  "confirmYourPresenceCta": "قم بتأكيد تواجدك في الوقت والمكان المحدد",
```

Add the English equivalents in `app_en.arb` with the same keys and placeholders.

`tripFeeChargedAtStartNotice` is the **one place this screen deliberately departs from the mock.** The mock reads «عند انتهاء الرحلة»; the fee is charged at trip start, so the mock's wording would be factually wrong and would produce exactly the driver disputes this work exists to prevent.

Regenerate: `flutter gen-l10n`

- [ ] **Step 3: Write the failing test**

Create `rideshare/test/driver/trip_management_pre_departure_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('route card shows origin and destination names',
      (tester) async {
    await tester.pumpWidget(wrap(
      TripRouteCard(
        from: LocationModel(name: 'عمان', latitude: 0, longitude: 0),
        to: LocationModel(name: 'الطفيلة', latitude: 0, longitude: 0),
      ),
    ));

    expect(find.text('عمان'), findsOneWidget);
    expect(find.text('الطفيلة'), findsOneWidget);
  });

  testWidgets('facts strip falls back to the origin name with no address',
      (tester) async {
    await tester.pumpWidget(wrap(
      TripFactsStrip(
        departureTime: DateTime(2024, 7, 26, 7, 0),
        meetingPoint: null,
        originName: 'عمان',
        distanceKm: 181,
        bookedSeats: 4,
        totalSeats: 4,
      ),
    ));

    expect(find.text('عمان'), findsOneWidget);
    expect(find.textContaining('181'), findsOneWidget);
    expect(find.text('4 من 4'), findsOneWidget);
    expect(find.text('مكتملة'), findsOneWidget);
  });

  testWidgets('facts strip hides the complete badge when seats remain',
      (tester) async {
    await tester.pumpWidget(wrap(
      TripFactsStrip(
        departureTime: DateTime(2024, 7, 26, 7, 0),
        meetingPoint: 'دوار المدينة الرياضية',
        originName: 'عمان',
        distanceKm: 181,
        bookedSeats: 2,
        totalSeats: 4,
      ),
    ));

    expect(find.text('دوار المدينة الرياضية'), findsOneWidget);
    expect(find.text('2 من 4'), findsOneWidget);
    expect(find.text('مكتملة'), findsNothing);
  });

  testWidgets('fare breakdown multiplies by booked seats and shows the fee',
      (tester) async {
    await tester.pumpWidget(wrap(
      TripFareBreakdownCard(
        seatPrice: 4.0,
        bookedSeats: 4,
        feeAmount: 1.6,
        feePercent: 10,
        currency: 'JOD',
      ),
    ));

    expect(find.textContaining('4.00'), findsWidgets);
    expect(find.textContaining('16.00'), findsOneWidget);
    expect(find.textContaining('1.60'), findsOneWidget);
    expect(find.textContaining('10'), findsWidgets);
  });

  testWidgets('the fee notice says at trip start, not at trip end',
      (tester) async {
    await tester.pumpWidget(wrap(const TripFeeNotice()));

    expect(find.textContaining('عند انطلاق الرحلة'), findsOneWidget);
    expect(find.textContaining('عند انتهاء الرحلة'), findsNothing);
  });
}
```

Add the imports for the three new widgets and `LocationModel` once they exist.

- [ ] **Step 4: Run tests to verify they fail**

Run: `cd rideshare && flutter test test/driver/trip_management_pre_departure_test.dart`
Expected: FAIL — the three widgets do not exist.

- [ ] **Step 5: Build the three widgets**

Write `trip_route_card.dart`, `trip_facts_strip.dart` and `trip_fare_breakdown_card.dart` as stateless widgets taking plain values, never a `TripModel` — that keeps them testable without model fixtures, which is what the test above assumes.

Every colour reads from `Theme.of(context).colorScheme` or `AppColors`. Use `Directionality`-aware edges (`start`/`end`), never `left`/`right`: the screen is Arabic-first and must not break in English.

- [ ] **Step 6: Recompose the screen body**

In `trip_management_screen.dart`, split the body on trip state:

```dart
final isPreDeparture = _trip!.tripStartedAt == null;
```

When `isPreDeparture`, render sections 1–9 in the order listed above and render **none** of `_buildWalletCard`, `_buildLiveTrackingCard`, `_buildArrivedCard`, `_buildStatisticsRow`, `_buildSeatLayoutCard`, `_buildCarImageCard` or `_buildQuickActionsCard`. When the trip has started, keep today's composition unchanged.

Do not delete those builders — they are still the post-departure body.

- [ ] **Step 7: Run tests and the analyzer**

```bash
cd rideshare && flutter analyze && flutter test
```
Expected: analyze clean, all tests PASS.

- [ ] **Step 8: Compare against the mock side by side**

Run the app on a device or emulator, open a fully-booked trip as the driver, and check against `screenshot/` — spacing, order, the seat chips, the «مكتملة» badge, and the red fee amount. Fix any drift before committing.

- [ ] **Step 9: Commit**

```bash
git add rideshare/lib rideshare/test
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "feat(mobile): rebuild the pre-departure driver screen to the design mock

Route card, facts strip, per-seat passenger rows with open contact, fare
breakdown and the presence CTA, in the app's teal palette. Post-departure
composition is unchanged.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: Full-stack verification

**Files:** none modified.

- [ ] **Step 1: Backend suite and build**

```bash
cd rideshare-backend && npm test && npm run lint && npm run build
```
Expected: all PASS, zero lint errors, build succeeds.

- [ ] **Step 2: Mobile suite**

```bash
cd rideshare && flutter analyze && flutter test
```
Expected: analyze clean, all tests PASS.

- [ ] **Step 3: Prove no gate survives**

```bash
grep -rn "hasDriverPaidToContact\|driverWalletChargeApplied" rideshare-backend/src rideshare/lib rideshare-dashboard/src \
  | grep -v spec | grep -v migrations | grep -v generated
```

Every remaining hit must be a column definition, a write, or a display read. No `if`, `filter`, or `throw`.

```bash
grep -rn "WalletHoldService\|placeHold\|settleHold\|PRESENCE_BILLING_ENABLED\|trip-charge" \
  rideshare-backend/src rideshare/lib | grep -v migrations
```
Expected: no hits.

- [ ] **Step 4: Manual smoke test against a running stack**

1. Driver with 10.00 JOD publishes a 4-seat trip at 4.00 JOD/seat → publish succeeds; the review step shows 1.60.
2. Driver with 1.00 JOD attempts the same → 403, dialog offers a top-up.
3. Passenger books one seat → driver sees the name, phone, call and chat immediately, with the wallet still at 10.00.
4. Wait for `departureTime` (or trigger the `trip-auto-start` job) → wallet drops to 8.40, one `TRIP_DEBIT` row for 1.60.
5. Complete the trip with only one of two passengers confirming presence → wallet stays at 8.40, no refund, no second debit.
6. Re-run the auto-start job for the same trip → wallet unchanged.

- [ ] **Step 5: Commit any fixes and finish**

```bash
git -c user.email="zeinsaad657@gmail.com" -c user.name="zeinsaad657" commit -m "test: verify fee-at-trip-start end to end

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```
