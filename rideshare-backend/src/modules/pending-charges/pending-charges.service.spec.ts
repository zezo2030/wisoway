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
