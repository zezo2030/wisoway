// Real Socket.IO frames + HTTP against the isolated backend, never production fixtures.
const assert = require('node:assert/strict');
const path = require('node:path');
if (!/^wisoway_revenue_verify_/.test(process.env.POSTGRES_DB || '')) throw Error('Isolated verification database required');
const load = p => require(path.join(process.cwd(), 'dist/src', p));
const { AppDataSource: db } = load('database/data-source.js');
const E = load('database/entities/index.js');
const jwt = require(path.join(process.cwd(), 'node_modules/jsonwebtoken'));
const WebSocket = require(path.join(process.cwd(), 'node_modules/ws'));
const clients = [];
function connect(token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket('ws://127.0.0.1:3000/socket.io/?EIO=4&transport=websocket');
    const pending = new Map(), updates = new Set(); let sequence = 0;
    const timer = setTimeout(() => reject(Error('Tracking connection timeout')), 15000);
    clients.push(ws);
    ws.on('error', reject);
    ws.on('message', buffer => {
      const frame = String(buffer);
      if (frame.startsWith('0')) ws.send('40/tracking,' + JSON.stringify({ token }));
      if (frame === '2') ws.send('3');
      if (frame.startsWith('40/tracking,')) {
        clearTimeout(timer);
        resolve({
          close: () => ws.close(),
          request: (event, data) => new Promise((ok, fail) => {
            const id = ++sequence;
            const timeout = setTimeout(() => { pending.delete(id); fail(Error(`Tracking ack timeout: ${event}`)); }, 45000);
            pending.set(id, value => { clearTimeout(timeout); ok(value); });
            ws.send(`42/tracking,${id}` + JSON.stringify([event, data]));
          }),
          nextUpdate: tripId => new Promise((ok, fail) => {
            const handler = data => { if (data.tripId === tripId) { clearTimeout(timeout); updates.delete(handler); ok(data); } };
            const timeout = setTimeout(() => { updates.delete(handler); fail(Error('Passenger update timeout')); }, 45000);
            updates.add(handler);
          }),
        });
      }
      const ack = frame.match(/^43\/tracking,(\d+)(.*)$/);
      if (ack) { const done = pending.get(Number(ack[1])); pending.delete(Number(ack[1])); done?.(JSON.parse(ack[2])[0]); }
      if (frame.startsWith('42/tracking,')) {
        const [event, data] = JSON.parse(frame.slice('42/tracking,'.length));
        if (event === 'trip:tracking:update') for (const handler of [...updates]) handler(data);
      }
    });
  });
}
async function http(route, token) {
  const r = await fetch('http://127.0.0.1:3000/api/v1' + route, { headers: { Authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(45000) });
  assert.equal(r.status, 200, route);
  const j = await r.json(); return j.data ?? j;
}
(async () => {
  await db.initialize(); const repo = e => db.getRepository(e);
  const driver = await repo(E.UserEntity).save(repo(E.UserEntity).create({ name: 'Isolated tracking driver', role: 'driver' }));
  const rider = await repo(E.UserEntity).save(repo(E.UserEntity).create({ name: 'Isolated tracking passenger', role: 'passenger' }));
  const trip = await repo(E.TripEntity).save(repo(E.TripEntity).create({ driverId: driver.id, tripType: 'instant', status: 'in_progress', fromName: 'Verification pickup', toName: 'Verification destination', fromPoint: { type: 'Point', coordinates: [35.9106, 31.9539] }, toPoint: { type: 'Point', coordinates: [35.925, 31.9601] }, departureTime: new Date(), price: '10.00', currency: 'JOD', totalSeats: 1, availableSeats: 0 }));
  await repo(E.BookingEntity).save(repo(E.BookingEntity).create({ tripId: trip.id, userId: rider.id, status: 'confirmed', seatCount: 1, seatPriceAtBooking: '10.00', totalAmount: '10.00', paymentMethod: 'cash' }));
  const sign = user => jwt.sign({ sub: user.id, role: user.role }, process.env.JWT_ACCESS_SECRET, { expiresIn: 300 });
  const driverToken = sign(driver), riderToken = sign(rider);
  const driverSocket = await connect(driverToken);
  let passengerSocket = await connect(riderToken);
  assert.equal((await passengerSocket.request('trip:tracking:subscribe', { tripId: trip.id })).success, true);
  const received = passengerSocket.nextUpdate(trip.id);
  const ack = await driverSocket.request('driver:location:update', { tripId: trip.id, latitude: 31.950, longitude: 35.905, heading: 45, speedKph: 30 });
  assert.equal(ack.success, true);
  const update = await received;
  assert.equal(update.latitude, 31.950); assert.equal(update.longitude, 35.905);
  assert.equal(update.routeProgressPercent, 0); assert.ok(update.remainingDurationSeconds > 0);
  const route = await http('/locations/route?fromLatitude=31.950&fromLongitude=35.905&toLatitude=31.9539&toLongitude=35.9106', riderToken);
  assert.ok(route.overviewPolyline.length > 12); assert.ok(route.durationSeconds > 0);
  assert.ok(Math.abs(update.remainingDurationSeconds - route.durationSeconds) < Math.max(60, route.durationSeconds * .25));
  console.log('PICKUP_ROAD_ETA_OK', Math.ceil(update.remainingDurationSeconds / 60), 'minutes');
  await repo(E.TripEntity).update(trip.id, { tripStartedAt: new Date() });
  const next = passengerSocket.nextUpdate(trip.id);
  const started = await driverSocket.request('driver:location:update', { tripId: trip.id, latitude: 31.9539, longitude: 35.9106, heading: 70 });
  assert.equal(started.success, true); assert.ok((await next).remainingDurationSeconds > 0);
  passengerSocket.close();
  const final = await driverSocket.request('driver:location:update', { tripId: trip.id, latitude: 31.955, longitude: 35.914, heading: 80 });
  assert.equal(final.success, true);
  passengerSocket = await connect(riderToken);
  const snapshot = await passengerSocket.request('trip:tracking:subscribe', { tripId: trip.id });
  assert.equal(snapshot.snapshot.latitude, 31.955); assert.equal(snapshot.snapshot.longitude, 35.914);
  const latest = await http(`/tracking/${trip.id}/latest`, riderToken);
  assert.equal(latest.latitude, 31.955); assert.equal(latest.heading, 80);
  console.log('LIVE_TRACKING_OK: driver-to-passenger updates, road ETA to pickup before start, start transition, reconnect snapshot, HTTP recovery; no banking calls or production fixtures');
})().catch(e => { console.error(e.message); process.exitCode = 1; }).finally(async () => { for (const ws of clients) ws.terminate(); if (db.isInitialized) await db.destroy(); });
