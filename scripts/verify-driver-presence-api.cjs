// Isolated PostgreSQL/API fixtures; no production users or banking calls.
const assert = require('node:assert/strict');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
if (!/^wisoway_revenue_verify_/.test(process.env.POSTGRES_DB || '')) throw Error('Isolated verification database required');
const load = p => require(path.join(process.cwd(), 'dist/src', p));
const { AppDataSource: db } = load('database/data-source.js');
const E = load('database/entities/index.js');
const jwt = require(path.join(process.cwd(), 'node_modules/jsonwebtoken'));
const message = 'اشحن محفظتك بحد أدنى 5 دنانير أو 25 ريالاً أو ما يعادلها وسدد أي مستحقات للاستمرار في استقبال الرحلات وإنشائها.';
let token;
async function call(route, method = 'GET', body, expected = 200) {
  const r = await fetch('http://127.0.0.1:3000/api/v1' + route, { method, headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(15000) });
  assert.equal(r.status, expected, `${method} ${route}: ${r.status}`);
  const j = await r.json(); return j.data ?? j;
}
(async () => {
  await db.initialize();
  const repo = e => db.getRepository(e);
  const driver = await repo(E.UserEntity).save(repo(E.UserEntity).create({ name: 'Isolated presence verification', role: 'driver', isDriverApproved: true, walletCurrency: 'JOD' }));
  await repo(E.VehicleEntity).save(repo(E.VehicleEntity).create({ driverId: driver.id, vehicleType: 'sedan', plateNumber: 'VERIFY', model: 'Verification', seats: 4, isVerified: true }));
  const account = await repo(E.WalletAccountEntity).save(repo(E.WalletAccountEntity).create({ userId: driver.id, accountType: 'driver', currency: 'JOD' }));
  token = jwt.sign({ sub: driver.id, role: 'driver' }, process.env.JWT_ACCESS_SECRET, { expiresIn: 300 });
  const lock = randomUUID();
  async function onlineSnapshot() {
    await db.query(`INSERT INTO driver_availability ("driverId","isOnline","currentRequestId","lastSeenAt",point)
      VALUES ($1,true,$2,now(),ST_SetSRID(ST_MakePoint(15.91,-55.95),4326)::geography)
      ON CONFLICT ("driverId") DO UPDATE SET "isOnline"=true,"currentRequestId"=$2,"lastSeenAt"=now()`, [driver.id, lock]);
  }
  for (const condition of [{ balance: '0.00', reservedBalance: '0.00', rechargeRequired: false }, { balance: '-1.00', reservedBalance: '0.00', rechargeRequired: false }, { balance: '5.00', reservedBalance: '5.00', rechargeRequired: false }, { balance: '5.00', reservedBalance: '0.00', rechargeRequired: true }]) {
    await repo(E.WalletAccountEntity).update(account.id, condition);
    await onlineSnapshot();
    assert.equal((await call('/instant-rides/nearby-drivers?latitude=-55.95&longitude=15.91')).length, 0);
    assert.equal((await call('/instant-rides/availability/me')).isOnline, false);
    const [saved] = await db.query('SELECT "isOnline","currentRequestId" FROM driver_availability WHERE "driverId"=$1', [driver.id]);
    assert.equal(saved.isOnline, false); assert.equal(saved.currentRequestId, lock);
    const rejected = await call('/instant-rides/availability', 'POST', { isOnline: true }, 403);
    assert.equal(rejected.error.message, message);
    const shared = await call('/wallet/driver/trip-eligibility?country=JO', 'GET', undefined, 403);
    assert.equal(shared.error.message, rejected.error.message);
    await onlineSnapshot();
    assert.equal((await call('/instant-rides/availability/heartbeat', 'POST', { latitude: -55.95, longitude: 15.91 }, 201)).isOnline, false);
  }
  await repo(E.WalletAccountEntity).update(account.id, { balance: '5.00', reservedBalance: '0.00', rechargeRequired: false });
  assert.equal((await call('/instant-rides/availability/me')).isOnline, false, 'top-up must not auto-enable online status');
  assert.equal((await call('/instant-rides/availability', 'POST', { isOnline: true }, 201)).isOnline, true);
  assert.equal((await call('/instant-rides/availability/me')).isOnline, true);
  assert.equal((await call('/instant-rides/nearby-drivers?latitude=-55.95&longitude=15.91')).length, 1);
  console.log('DRIVER_PRESENCE_API_OK: zero, debt, reserved balance, recharge lock; entry and heartbeat reconcile offline; shared/instant messages match; funded driver chooses when to reconnect; ride lock preserved');
})().catch(e => { console.error(e.message); process.exitCode = 1; }).finally(async () => { if (db.isInitialized) await db.destroy(); });
