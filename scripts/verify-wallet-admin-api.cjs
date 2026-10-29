// Integration checks against the isolated verification database/API only.
const assert = require('node:assert/strict');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
if (!/^wisoway_revenue_verify_/.test(process.env.POSTGRES_DB || '')) throw Error('Isolated verification database required');
const load = p => require(path.join(process.cwd(), 'dist/src', p));
const { AppDataSource: db } = load('database/data-source.js');
const E = load('database/entities/index.js');
const bcrypt = require(path.join(process.cwd(), 'node_modules/bcrypt'));
const jwt = require(path.join(process.cwd(), 'node_modules/jsonwebtoken'));
async function call(route, token, method = 'GET', body, expected = 200) {
  const response = await fetch('http://127.0.0.1:3000/api/v1' + route, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(15000) });
  assert.equal(response.status, expected, `${method} ${route} returned ${response.status}`);
  const json = await response.json();
  return json.data ?? json;
}
(async () => {
  await db.initialize();
  const users = db.getRepository(E.UserEntity);
  const password = randomUUID();
  const admin = await users.save(users.create({ name: 'Isolated wallet verification', role: 'admin', email: `verify-${randomUUID()}@example.com`, passwordHash: await bcrypt.hash(password, 10), isActive: true }));
  const driver = await users.save(users.create({ name: 'Isolated wallet verification', role: 'driver', isDriverApproved: true, walletCurrency: 'JOD' }));
  const login = await call('/auth/login', null, 'POST', { email: admin.email, password });
  assert.ok(login.accessToken);
  assert.equal(login.user.role, 'admin');
  const driverToken = jwt.sign({ sub: driver.id, role: 'driver' }, process.env.JWT_ACCESS_SECRET, { expiresIn: 300 });
  await call('/wallet/driver/trip-eligibility?country=JO', driverToken, 'GET', undefined, 403);
  const payment = await call('/payments/wallet/topup', driverToken, 'POST', { amount: 5, currency: 'JOD', method: 'manual', proofImageUrl: '/uploads/isolated-proof.png' }, 201);
  assert.equal(payment.status, 'pending');
  const queue = await call('/admin/payments/pending?limit=100', login.accessToken);
  assert.ok(queue.data.some(p => p.id === payment.id));
  await call(`/payments/${payment.id}/approve`, driverToken, 'PATCH', {}, 403);
  const approved = await call(`/payments/${payment.id}/approve`, login.accessToken, 'PATCH', {});
  assert.equal(approved.status, 'approved');
  const wallet = await call('/wallet/me?country=JO', driverToken);
  assert.equal(wallet.balance, 5);
  assert.equal(wallet.rechargeRequired, false);
  assert.equal((await call('/wallet/driver/trip-eligibility?country=JO', driverToken)).eligible, true);
  await call('/wallet/driver/trip-eligibility?country=SA', driverToken, 'GET', undefined, 403);
  await call(`/payments/${payment.id}/approve`, login.accessToken, 'PATCH', {}, 400);
  const count = await db.getRepository(E.WalletTransactionEntity).count({ where: { idempotencyKey: `payment-topup:${payment.id}` } });
  assert.equal(count, 1);
  assert.equal((await call('/wallet/me?country=JO', driverToken)).balance, 5);
  console.log('WALLET_ADMIN_API_OK: password login, pending queue, approval, role guard, JOD 5 credit, no duplicate credit');
})().catch(e => { console.error(e.message); process.exitCode = 1; }).finally(async () => { if (db.isInitialized) await db.destroy(); });
