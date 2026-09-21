/* QA 03 — the scheduled-trip lifecycle: publish, search, book, accept,
   chat, presence, complete, rate. */
const L = require('./lib');
const { req, data, errMsg } = L;
const A = require('./accounts.json');
const fs = require('fs');

const P1 = A.accounts.passenger1;
const P2 = A.accounts.passenger2;
const D1 = A.accounts.driver1;
const AD = A.accounts.admin;

// Amman → Zarqa
const FROM = { name: 'Amman — Abdali', latitude: 31.9539, longitude: 35.9106, address: 'Abdali Boulevard, Amman' };
const TO = { name: 'Zarqa — Downtown', latitude: 32.0727, longitude: 36.0879, address: 'King Hussein St, Zarqa' };

/** Tokens rotate across suites; re-login the ones whose password we know. */
async function freshTokens() {
  const li = await req('POST', '/auth/login', {
    body: { phoneNumber: P1.phone, password: 'Passenger@99999' },
  });
  if (li.status === 200 || li.status === 201) P1.token = data(li).accessToken;
  for (const cand of ['Passenger@12345', 'Passenger@54321']) {
    const r = await req('POST', '/auth/login', { body: { phoneNumber: P2.phone, password: cand } });
    if (r.status === 200 || r.status === 201) { P2.token = data(r).accessToken; break; }
  }
  const dl = await req('POST', '/auth/login', {
    body: { phoneNumber: D1.phone, password: 'Driver@12345' },
  });
  if (dl.status === 200 || dl.status === 201) D1.token = data(dl).accessToken;
  const al = await L.loginAdmin();
  AD.token = al.token;
}

async function main() {
  await freshTokens();

  L.setSection('Pre-publish pricing helpers');
  const ps = await req('GET', '/trips/price-suggestion', {
    token: D1.token,
    query: { fromLat: FROM.latitude, fromLng: FROM.longitude, toLat: TO.latitude, toLng: TO.longitude },
  });
  L.expectStatus('GET /trips/price-suggestion', ps, 200);

  const fq = await req('GET', '/trips/fee-quote', {
    token: D1.token,
    query: { seatPrice: '3', totalSeats: '3' },
  });
  if (L.expectStatus('GET /trips/fee-quote', fq, 200)) {
    console.log('        fee quote:', JSON.stringify(data(fq)).slice(0, 220));
  }

  L.setSection('Driver publishes a trip');
  // Depart shortly so the auto-start job fires inside this run.
  const departureTime = new Date(Date.now() + 75 * 1000).toISOString();
  const create = await req('POST', '/trips', {
    token: D1.token,
    body: {
      from: FROM,
      to: TO,
      departureTime,
      price: 3,
      currency: 'JOD',
      availableSeats: 3,
      notes: 'QA scheduled trip — Amman to Zarqa',
      stops: [{ name: 'Russeifa', lat: 32.0181, lng: 36.0464, order: 1 }],
    },
  });
  if (!L.expectStatus('POST /trips', create, [200, 201])) {
    console.log('        body:', JSON.stringify(create.body).slice(0, 500));
    L.summary(); await L.closeDb(); process.exit(1);
  }
  const trip = data(create);
  const tripId = trip.id;
  L.pass('trip id issued', tripId);
  if (trip.status) L.pass('trip status on create', trip.status);

  const passengerPublish = await req('POST', '/trips', {
    token: P1.token,
    body: { from: FROM, to: TO, departureTime, price: 3, availableSeats: 2 },
  });
  L.expectStatus('passenger cannot publish a trip', passengerPublish, [403, 401]);

  L.setSection('Trip reads & search');
  const detail = await req('GET', `/trips/${tripId}`, { token: P1.token });
  L.expectStatus('GET /trips/:id', detail, 200);

  const mine = await req('GET', '/trips/my', { token: D1.token });
  if (L.expectStatus('GET /trips/my (driver)', mine, 200)) {
    const arr = L.list(mine);
    if (arr.some((t) => t.id === tripId)) L.pass('published trip appears in /trips/my');
    else L.fail('published trip appears in /trips/my', `count=${arr.length}`);
  }

  const search = await req('GET', '/trips', {
    token: P1.token,
    query: {
      fromLatitude: FROM.latitude, fromLongitude: FROM.longitude,
      toLatitude: TO.latitude, toLongitude: TO.longitude, limit: 50,
    },
  });
  if (L.expectStatus('GET /trips (search)', search, 200)) {
    const arr = L.list(search);
    if (arr.some((t) => t.id === tripId)) L.pass('trip is findable by route search');
    else L.fail('trip is findable by route search', `count=${arr.length}`);
  }

  const nearby = await req('GET', '/trips/nearby', {
    token: P1.token,
    query: { latitude: FROM.latitude, longitude: FROM.longitude, radiusKm: 25 },
  });
  if (L.expectStatus('GET /trips/nearby', nearby, 200)) {
    const arr = L.list(nearby);
    if (arr.some((t) => t.id === tripId)) L.pass('trip appears in PostGIS nearby search');
    else L.fail('trip appears in PostGIS nearby search', `count=${arr.length}`);
  }

  const preferred = await req('GET', '/trips/preferred', {
    token: P1.token,
    query: { latitude: FROM.latitude, longitude: FROM.longitude, radiusKm: 25 },
  });
  L.expectStatus('GET /trips/preferred', preferred, 200);

  const seats = await req('GET', `/trips/${tripId}/seats`, { token: P1.token });
  let seatIds = [];
  if (L.expectStatus('GET /trips/:id/seats', seats, 200)) {
    const arr = L.list(seats).length ? L.list(seats) : (data(seats)?.seats || []);
    seatIds = arr.map((x) => x.seatNumber || x.id || x).filter(Boolean);
    if (seatIds.length) L.pass('seat map returned', seatIds.join(','));
    else L.fail('seat map returned', JSON.stringify(s).slice(0, 300));
  }

  const preview = await req('GET', `/trips/${tripId}/pricing-preview`, { token: D1.token });
  L.expectStatus('GET /trips/:id/pricing-preview', preview, 200);

  L.setSection('Trip edit / hide / show / share');
  const patch = await req('PATCH', `/trips/${tripId}`, {
    token: D1.token,
    body: { notes: 'QA scheduled trip — updated notes' },
  });
  L.expectStatus('PATCH /trips/:id (own trip)', patch, 200);

  const hide = await req('PATCH', `/trips/${tripId}/hide`, { token: D1.token });
  L.expectStatus('PATCH /trips/:id/hide', hide, 200);
  const show = await req('PATCH', `/trips/${tripId}/show`, { token: D1.token });
  L.expectStatus('PATCH /trips/:id/show', show, 200);

  const shareLink = await req('POST', `/trips/${tripId}/share-link`, { token: D1.token });
  if (L.expectStatus('POST /trips/:id/share-link', shareLink, [200, 201])) {
    const token = data(shareLink).token || (data(shareLink).url || '').split('/').pop();
    if (token) {
      const pubView = await req('GET', `/share/${token}`);
      L.expectStatus('GET /share/:token (public, no auth)', pubView, 200);
    } else L.fail('share link token present', JSON.stringify(data(shareLink)).slice(0, 200));
  }

  L.setSection('Passenger books seats (v2)');
  const seat1 = seatIds[0] || '0-0';
  const book = await req('POST', '/v2/bookings', {
    token: P1.token,
    body: {
      tripId,
      seats: [{ seatNumber: seat1, displayName: 'QA Passenger One', gender: 'male', isMainBooker: true }],
      sharePhoneWithDriver: true,
    },
  });
  if (!L.expectStatus('POST /v2/bookings', book, [200, 201])) {
    console.log('        body:', JSON.stringify(book.body).slice(0, 500));
  }
  const booking = data(book);
  const bookingId = booking?.id || booking?.bookingId;
  if (bookingId) L.pass('booking id issued', bookingId);

  const dupSeat = await req('POST', '/v2/bookings', {
    token: P2.token,
    body: {
      tripId,
      seats: [{ seatNumber: seat1, displayName: 'QA Passenger Two', gender: 'female', isMainBooker: true }],
    },
  });
  L.expectStatus('double-booking the same seat is rejected', dupSeat, [400, 409]);

  const autoPick = await req('POST', '/v2/bookings/auto-pick', {
    token: P2.token,
    body: {
      tripId,
      seatCount: 1,
      passengers: [{ displayName: 'QA Passenger Two', gender: 'female', isMainBooker: true }],
      sharePhoneWithDriver: false,
    },
  });
  const booking2 = data(autoPick);
  const booking2Id = booking2?.id || booking2?.bookingId;
  if (!L.expectStatus('POST /v2/bookings/auto-pick', autoPick, [200, 201])) {
    console.log('        body:', JSON.stringify(autoPick.body).slice(0, 400));
  }

  L.setSection('Booking reads');
  const myB = await req('GET', '/bookings/my', { token: P1.token });
  if (L.expectStatus('GET /bookings/my (passenger)', myB, 200)) {
    const arr = L.list(myB);
    if (arr.some((x) => x.id === bookingId)) L.pass('booking appears in /bookings/my');
    else L.fail('booking appears in /bookings/my', `count=${arr.length}`);
  }

  const tripB = await req('GET', `/bookings/trip/${tripId}`, { token: D1.token });
  L.expectStatus('GET /bookings/trip/:tripId (driver roster)', tripB, 200);

  if (bookingId) {
    const one = await req('GET', `/bookings/${bookingId}`, { token: P1.token });
    L.expectStatus('GET /bookings/:id', one, 200);

    const foreign = await req('GET', `/bookings/${bookingId}`, { token: P2.token });
    L.expectStatus('another passenger cannot read the booking', foreign, [403, 404]);
  }

  L.setSection('Driver accepts / rejects');
  if (bookingId) {
    const acc = await req('PATCH', `/v2/bookings/${bookingId}/accept`, { token: D1.token });
    if (!L.expectStatus('PATCH /v2/bookings/:id/accept', acc, [200, 201])) {
      console.log('        body:', JSON.stringify(acc.body).slice(0, 400));
    }
    const wrongDriver = await req('PATCH', `/v2/bookings/${bookingId}/accept`, { token: P1.token });
    L.expectStatus('a passenger cannot accept a booking', wrongDriver, [401, 403]);
  }
  if (booking2Id) {
    const acc2 = await req('PATCH', `/v2/bookings/${booking2Id}/accept`, { token: D1.token });
    L.expectStatus('driver accepts the second booking', acc2, [200, 201]);
  }

  L.setSection('Chat');
  const room = await req('GET', `/chat/rooms/trip/${tripId}/passenger/${P1.id}`, { token: D1.token });
  let roomId = null;
  if (L.expectStatus('GET /chat/rooms/trip/:tripId/passenger/:id', room, 200)) {
    roomId = data(room)?.id || data(room)?.roomId;
    if (roomId) L.pass('1:1 chat room resolved', roomId);
    else L.fail('1:1 chat room resolved', JSON.stringify(data(room)).slice(0, 200));
  }
  const groupRoom = await req('GET', `/chat/rooms/trip/${tripId}/group`, { token: D1.token });
  L.expectStatus('GET /chat/rooms/trip/:tripId/group', groupRoom, 200);

  if (roomId) {
    const send = await req('POST', `/chat/rooms/${roomId}/messages`, {
      token: D1.token,
      body: { text: 'QA: I will be at the pickup point at 9:00.' },
    });
    if (!L.expectStatus('POST /chat/rooms/:id/messages (driver)', send, [200, 201])) {
      console.log('        body:', JSON.stringify(send.body).slice(0, 300));
    }
    const reply = await req('POST', `/chat/rooms/${roomId}/messages`, {
      token: P1.token,
      body: { text: 'QA: Understood, see you there.' },
    });
    L.expectStatus('POST /chat/rooms/:id/messages (passenger)', reply, [200, 201]);

    const msgs = await req('GET', `/chat/rooms/${roomId}/messages`, { token: P1.token });
    if (L.expectStatus('GET /chat/rooms/:id/messages', msgs, 200)) {
      const arr = L.list(msgs);
      if (arr.length >= 2) L.pass('both messages are readable', `${arr.length}`);
      else L.fail('both messages are readable', `count=${arr.length}`);
    }

    const outsider = await req('GET', `/chat/rooms/${roomId}/messages`, { token: P2.token });
    L.expectStatus('a non-participant cannot read the room', outsider, [403, 404]);
  }

  const rooms = await req('GET', '/chat/rooms', { token: P1.token });
  L.expectStatus('GET /chat/rooms', rooms, 200);

  L.setSection('Trip-time: presence & confirmations');
  const roster = await req('GET', `/trips/${tripId}/presence-roster`, { token: D1.token });
  L.expectStatus('GET /trips/:id/presence-roster', roster, 200);

  if (bookingId) {
    const prompt = await req('GET', `/bookings/${bookingId}/presence-prompt`, { token: P1.token });
    L.expectStatus('GET /bookings/:id/presence-prompt', prompt, 200);

    const declare = await req('POST', `/bookings/${bookingId}/presence-declare`, {
      token: P1.token,
      body: { status: 'in_vehicle' },
    });
    L.expectStatus('POST /bookings/:id/presence-declare', declare, [200, 201]);

    const pc = await req('POST', `/bookings/${bookingId}/passenger-confirm`, {
      token: P1.token, body: { driverPresent: true },
    });
    L.expectStatus('POST /bookings/:id/passenger-confirm', pc, [200, 201, 400]);

    const dc = await req('POST', `/bookings/${bookingId}/driver-confirm`, {
      token: D1.token, body: { seatNumber: seat1, present: true },
    });
    L.expectStatus('POST /bookings/:id/driver-confirm', dc, [200, 201, 400]);
  }

  L.setSection('Tracking');
  const latest = await req('GET', `/tracking/${tripId}/latest`, { token: P1.token });
  L.expectStatus('GET /tracking/:tripId/latest', latest, [200, 404]);
  const hist = await req('GET', `/tracking/${tripId}/history`, { token: P1.token });
  L.expectStatus('GET /tracking/:tripId/history', hist, [200, 404]);
  const nearbyTrips = await req('GET', '/tracking/nearby/trips', {
    token: P1.token,
    query: { latitude: FROM.latitude, longitude: FROM.longitude, radiusKm: 25 },
  });
  L.expectStatus('GET /tracking/nearby/trips', nearbyTrips, [200, 400]);

  L.setSection('Trip completion');
  // The trip auto-starts (PUBLISHED → IN_PROGRESS) via a delayed BullMQ job
  // that fires at departureTime. Wait for it rather than forcing the status.
  const deadline = Date.now() + 150000;
  let status = null;
  while (Date.now() < deadline) {
    const t = await req('GET', `/trips/${tripId}`, { token: D1.token });
    status = data(t)?.status;
    if (status === 'in_progress' || status === 'completed') break;
    await new Promise((r) => setTimeout(r, 5000));
  }
  if (status === 'in_progress' || status === 'completed') {
    L.pass('trip auto-started at departureTime', `status=${status}`);
  } else {
    L.fail('trip auto-started at departureTime', `status=${status} after 150s`);
  }

  const arrived = await req('POST', `/trips/${tripId}/arrived`, { token: D1.token, body: {} });
  L.expectStatus('POST /trips/:id/arrived', arrived, [200, 201]);

  // /complete is a legacy alias for /arrived — the same handler. Completing an
  // already-completed trip must be rejected rather than double-settled.
  const complete = await req('POST', `/trips/${tripId}/complete`, { token: D1.token, body: {} });
  L.expectStatus('POST /trips/:id/complete on an already-completed trip is rejected', complete, 400);

  const after = await req('GET', `/trips/${tripId}`, { token: D1.token });
  if (after.status === 200) {
    const st = data(after).status;
    if (st === 'completed') L.pass('trip status is completed');
    else L.fail('trip status is completed', `status=${st}`);
  }

  L.setSection('Ratings');
  const rate = await req('POST', '/ratings', {
    token: P1.token,
    body: { toUserId: D1.id, tripId, rating: 5, comment: 'QA: smooth ride, on time.' },
  });
  if (!L.expectStatus('POST /ratings (passenger rates driver)', rate, [200, 201])) {
    console.log('        body:', JSON.stringify(rate.body).slice(0, 300));
  }

  const dupRate = await req('POST', '/ratings', {
    token: P1.token,
    body: { toUserId: D1.id, tripId, rating: 1, comment: 'QA duplicate' },
  });
  L.expectStatus('the same rating cannot be submitted twice', dupRate, [400, 409]);

  const rateBack = await req('POST', '/ratings', {
    token: D1.token,
    body: { toUserId: P1.id, tripId, rating: 5, comment: 'QA: polite passenger.' },
  });
  L.expectStatus('POST /ratings (driver rates passenger)', rateBack, [200, 201]);

  const userRatings = await req('GET', `/ratings/user/${D1.id}`, { token: P1.token });
  L.expectStatus('GET /ratings/user/:userId', userRatings, 200);
  const tripRatings = await req('GET', `/ratings/trip/${tripId}`, { token: P1.token });
  L.expectStatus('GET /ratings/trip/:tripId', tripRatings, 200);
  const myRatings = await req('GET', '/ratings/my', { token: P1.token });
  L.expectStatus('GET /ratings/my', myRatings, 200);

  const drv = await req('GET', `/users/${D1.id}`, { token: P1.token });
  if (drv.status === 200) {
    const r = Number(data(drv).rating);
    if (r > 0) L.pass('driver aggregate rating updated', String(r));
    else L.fail('driver aggregate rating updated', `rating=${data(drv).rating}`);
  }

  fs.writeFileSync(__dirname + '/trip-context.json', JSON.stringify({ tripId, bookingId, booking2Id, roomId }, null, 2));

  const failures = L.summary();
  await L.closeDb();
  process.exit(failures ? 1 : 0);
}

main().catch(async (e) => {
  console.error('HARNESS ERROR:', e);
  L.summary();
  await L.closeDb();
  process.exit(2);
});
