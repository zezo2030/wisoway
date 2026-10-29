// Run from /app inside the backend container. Dry-run unless --apply is supplied.
// Reuses the normal locked, idempotent welcome grant; never approves a driver.
const assert = require('node:assert/strict');
const path = require('node:path');
const load = p => require(path.join(process.cwd(), 'dist/src', p));
const { AppDataSource: db } = load('database/data-source.js');
const E = load('database/entities/index.js');
const { WalletService } = load('modules/wallet/wallet.service.js');
const { PlatformSettingsService } = load('modules/platform-settings/platform-settings.service.js');
const { DriverWalletPolicyService } = load('modules/wallet/driver-wallet-policy.service.js');
const repo = e => db.getRepository(e);
const missingSql = `SELECT u.id, u."walletCurrency" AS currency FROM users u
 WHERE u.role='driver' AND u."isDriverApproved"=true
 AND NOT EXISTS (SELECT 1 FROM wallet_transactions t
 WHERE t."idempotencyKey"='driver-welcome:'||u.id::text)`;
(async () => {
  await db.initialize();
  const missing = await db.query(missingSql);
  console.log('APPROVED_DRIVERS_MISSING_WELCOME', missing.length);
  if (!process.argv.includes('--apply')) return;
  const policy = new DriverWalletPolicyService(repo(E.PlatformSettingEntity));
  const wallet = new WalletService(db, repo(E.WalletAccountEntity), repo(E.WalletTransactionEntity), repo(E.PayoutRequestEntity), repo(E.TripEntity), repo(E.UserEntity), {}, new PlatformSettingsService(repo(E.PlatformSettingEntity)), policy, { create: async () => undefined });
  for (const driver of missing) {
    const currency = driver.currency || await wallet.resolveLocalCurrency(driver.id) || 'JOD';
    await db.transaction(async manager => {
      const current = await manager.findOneOrFail(E.UserEntity, { where: { id: driver.id }, lock: { mode: 'pessimistic_write' } });
      if (current.role === 'driver' && current.isDriverApproved) {
        await wallet.grantDriverWelcome(driver.id, currency, manager);
      }
    });
  }
  assert.equal((await db.query(missingSql)).length, 0);
  console.log('WELCOME_BACKFILL_OK', missing.length);
})().catch(e => { console.error(e.message); process.exitCode = 1; }).finally(async () => { if (db.isInitialized) await db.destroy(); });
