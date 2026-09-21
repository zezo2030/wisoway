/* QA 04 — instant rides: driver availability, quote, request, dispatch,
   fare negotiation, accept, and the resulting trip. */
const L = require('./lib');
const { req, data, errMsg, config } = L;
const A = require('./accounts.json');

const P1 = A.accounts.passenger1;
const D1 = A.accounts.driver1;
const D2 = A.accounts.driver2;
const AD = A.accounts.admin;

// Pickup in Amman; the driver sits ~600 m away so it lands in the first wave.
const PICKUP = { name: 'Amman — Sweifieh', latitude: 31.9454, longitude: 35.8674, address: 'Sweifieh, Amman' };
const DEST = { name: 'Amman — Downtown', latitude: 31.9515, longitude: 35.9239, address: 'Downtown, Amman' };
const DRIVER_AT = { latitude: 31.9500, longitude: 35.8700 };

async function freshTokens() {
  const p = await req('POST', '/auth/login', {
    body: { phoneNumber: P1.phone, password: config.passenger.resetPassword },
  });
  if (p.status === 200 || p.status === 201) P1.token = data(p).accessToken;
  for (const d of [D1, D2]) {
    const r = await req('POST', '/auth/login', {
      body: { phoneNumber: d.phone, password: config.driver.password },
    });
    if (r.status === 200 || r.status === 201) d.token = data(r).accessToken;
  }
  AD.token = (await L.loginAdmin()).token;
}

/**
 * Poll for the driver's outstanding offer. The endpoint returns
 * `{ offer, request }` (or `{ offer: null }`), not a list.
 */
async function waitForOffer(token, timeoutMs = 40000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const r = await req('GET', '/instant-rides/offers/pending', { token });
    const offer = data(r) && data(r).offer;
    if (offer && offer.id) return offer;
    await new Promise((res) => setTimeout(res, 1000));
  }
  return null;
}

/**
 * A passenger may hold only one live instant request, so an earlier run would
 * otherwise block this one with 409 "لديك طلب رحلة نشط بالفعل".
 */
async function cancelLiveRequests() {
  const rows = await L.sql(
    `SELECT id FROM instant_ride_requests
      WHERE "passengerId" = $1 AND status IN ('searching','offered')`,
    [P1.id],
  );
  for (const row of rows) {
    await req('DELETE', `/instant-rides/requests/${row.id}`, { token: P1.token });
  }
  if (rows.length) console.log(`(cleaned up ${rows.length} live instant request(s))`);
}

async function main() {
  await freshTokens();
  await cancelLiveRequests();

  L.setSection('Driver availability');
  const online = await req('POST', '/instant-rides/availability', {
    token: D1.token,
    body: { isOnline: true, acceptsInstant: true, ...DRIVER_AT },
  });
  if (!L.expectStatus('POST /instant-rides/availability (go online)', online, [200, 201])) {
    console.log('        body:', JSON.stringify(online.body).slice(0, 400));
  }

  const meAvail = await req('GET', '/instant-rides/availability/me', { token: D1.token });
  if (L.expectStatus('GET /instant-rides/availability/me', meAvail, 200)) {
    const d = data(meAvail);
    if (d?.isOnline) L.pass('driver reads back as online');
    else L.fail('driver reads back as online', JSON.stringify(d).slice(0, 200));
  }

  const hb = await req('POST', '/instant-rides/availability/heartbeat', {
    token: D1.token, body: DRIVER_AT,
  });
  L.expectStatus('POST /instant-rides/availability/heartbeat', hb, [200, 201]);

  const passengerAvail = await req('POST', '/instant-rides/availability', {
    token: P1.token, body: { isOnline: true },
  });
  L.expectStatus('passenger cannot set driver availability', passengerAvail, [403, 401]);

  L.setSection('Nearby drivers & quote');
  const nearby = await req('GET', '/instant-rides/nearby-drivers', {
    token: P1.token,
    query: { latitude: PICKUP.latitude, longitude: PICKUP.longitude },
  });
  if (L.expectStatus('GET /instant-rides/nearby-drivers', nearby, 200)) {
    const arr = L.list(nearby);
    if (arr.length) L.pass('the online driver is visible nearby', `${arr.length}`);
    else L.fail('the online driver is visible nearby', 'none returned');
  }

  const quote = await req('POST', '/instant-rides/quotes', {
    token: P1.token, body: { from: PICKUP, to: DEST },
  });
  let suggested = null;
  if (L.expectStatus('POST /instant-rides/quotes', quote, [200, 201])) {
    const q = data(quote);
    suggested = q?.recommendedFare ?? q?.suggestedFare ?? q?.fare ?? q?.amount;
    console.log('        quote:', JSON.stringify(q).slice(0, 250));
    if (suggested) L.pass('quote returns a suggested fare', String(suggested));
    else L.fail('quote returns a suggested fare', JSON.stringify(q).slice(0, 200));
  }

  const fare = Number(suggested) || 3;

  // Fare edits are only allowed while the request is SEARCHING (no offer
  // outstanding). With a driver online a request goes straight to OFFERED, so
  // this path is exercised with everyone offline.
  L.setSection('Fare negotiation while searching (manual, cash)');
  await req('POST', '/instant-rides/availability', {
    token: D1.token, body: { isOnline: false },
  });
  const r0 = await req('POST', '/instant-rides/requests', {
    token: P1.token,
    body: { from: PICKUP, to: DEST, seatCount: 1, passengerFare: fare },
  });
  if (L.expectStatus('POST /instant-rides/requests (no driver online)', r0, [200, 201])) {
    const id0 = data(r0).id;
    const st0 = await req('GET', `/instant-rides/requests/${id0}`, { token: P1.token });
    if (data(st0)?.status === 'searching') L.pass('request sits in searching with no driver online');
    else L.fail('request sits in searching with no driver online', `status=${data(st0)?.status}`);

    const newFare = Number((fare * 1.2).toFixed(2));
    const bump = await req('PATCH', `/instant-rides/requests/${id0}/fare`, {
      token: P1.token, body: { passengerFare: newFare },
    });
    if (!L.expectStatus('PATCH /instant-rides/requests/:id/fare (raise)', bump, [200, 201])) {
      console.log('        body:', JSON.stringify(bump.body).slice(0, 300));
    }

    const silly = await req('PATCH', `/instant-rides/requests/${id0}/fare`, {
      token: P1.token, body: { passengerFare: fare * 100 },
    });
    L.expectStatus('a fare above the allowed ceiling is rejected', silly, 400);

    const lower = await req('PATCH', `/instant-rides/requests/${id0}/fare`, {
      token: P1.token, body: { passengerFare: 0.5 },
    });
    L.expectStatus('lowering the fare is rejected', lower, 400);

    const del0 = await req('DELETE', `/instant-rides/requests/${id0}`, { token: P1.token });
    L.expectStatus('DELETE /instant-rides/requests/:id (passenger cancels)', del0, [200, 201, 204]);
  }

  // Back online for the dispatch test.
  await req('POST', '/instant-rides/availability', {
    token: D1.token,
    body: { isOnline: true, acceptsInstant: true, ...DRIVER_AT },
  });

  L.setSection('Passenger creates an instant request');
  const request = await req('POST', '/instant-rides/requests', {
    token: P1.token,
    body: { from: PICKUP, to: DEST, seatCount: 1, passengerFare: fare },
  });
  if (!L.expectStatus('POST /instant-rides/requests', request, [200, 201])) {
    console.log('        body:', JSON.stringify(request.body).slice(0, 500));
    L.summary(); await L.closeDb(); process.exit(1);
  }
  const reqId = data(request)?.id || data(request)?.requestId;
  L.pass('instant request created', reqId);

  const readReq = await req('GET', `/instant-rides/requests/${reqId}`, { token: P1.token });
  L.expectStatus('GET /instant-rides/requests/:id', readReq, 200);

  const foreignRead = await req('GET', `/instant-rides/requests/${reqId}`, { token: D2.token });
  L.expectStatus('an uninvolved driver cannot read the request', foreignRead, [403, 404]);

  L.setSection('Dispatch → driver offer');
  const offer = await waitForOffer(D1.token);
  if (!offer) {
    L.fail('driver receives a dispatch offer', 'no pending offer within 40s');
    const st = await req('GET', `/instant-rides/requests/${reqId}`, { token: P1.token });
    console.log('        request state:', JSON.stringify(data(st)).slice(0, 400));
    L.summary(); await L.closeDb(); process.exit(1);
  }
  L.pass('driver receives a dispatch offer', offer.id);

  const pend = await req('GET', '/instant-rides/offers/pending', { token: D2.token });
  if (pend.status === 200) {
    const other = data(pend) && data(pend).offer;
    if (!other || other.id !== offer.id) L.pass('the offer is not visible to another driver');
    else L.fail('the offer is not visible to another driver', 'leaked to driver 2');
  } else {
    L.fail('GET /instant-rides/offers/pending (driver 2)', `${pend.status} ${errMsg(pend)}`);
  }

  L.setSection('Driver counters, passenger accepts');
  const counter = await req('POST', `/instant-rides/offers/${offer.id}/respond`, {
    token: D1.token,
    body: { responseType: 'counter', amount: Number((fare * 1.1).toFixed(2)) },
  });
  if (!L.expectStatus('driver counters the fare', counter, [200, 201])) {
    console.log('        body:', JSON.stringify(counter.body).slice(0, 400));
  }

  const accept = await req('POST', `/instant-rides/requests/${reqId}/offers/${offer.id}/accept`, {
    token: P1.token, body: {},
  });
  if (!L.expectStatus('passenger accepts the countered offer', accept, [200, 201])) {
    console.log('        body:', JSON.stringify(accept.body).slice(0, 400));
  }

  L.setSection('Resulting instant trip');
  const after = await req('GET', `/instant-rides/requests/${reqId}`, { token: P1.token });
  let instantTripId = null;
  if (after.status === 200) {
    const d = data(after);
    instantTripId = d?.tripId || d?.trip?.id;
    console.log('        request status:', d?.status, 'tripId:', instantTripId);
    if (d?.status === 'matched' || d?.status === 'accepted' || instantTripId) {
      L.pass('request reached a matched state', String(d?.status));
    } else {
      L.fail('request reached a matched state', JSON.stringify(d).slice(0, 300));
    }
  }
  if (instantTripId) {
    const t = await req('GET', `/trips/${instantTripId}`, { token: P1.token });
    if (L.expectStatus('the instant trip is readable', t, 200)) {
      const tr = data(t);
      if (tr.tripType === 'instant' || tr.type === 'instant') L.pass('trip is typed instant');
      else L.fail('trip is typed instant', `tripType=${tr.tripType ?? tr.type}`);
    }
  } else {
    L.skip('the instant trip is readable', 'no tripId on the matched request');
  }

  L.setSection('Second request — cancellation path');
  const r2 = await req('POST', '/instant-rides/requests', {
    token: P1.token,
    body: { from: PICKUP, to: DEST, seatCount: 1, passengerFare: fare },
  });
  if (L.expectStatus('POST /instant-rides/requests (second)', r2, [200, 201, 400, 409])) {
    const id2 = data(r2)?.id;
    if (id2) {
      const del = await req('DELETE', `/instant-rides/requests/${id2}`, { token: P1.token });
      L.expectStatus('DELETE /instant-rides/requests/:id (passenger cancels)', del, [200, 201, 204]);
    } else {
      L.skip('DELETE /instant-rides/requests/:id', 'a second concurrent request was refused, which is valid');
    }
  }

  L.setSection('Driver goes offline');
  const offline = await req('POST', '/instant-rides/availability', {
    token: D1.token, body: { isOnline: false },
  });
  L.expectStatus('POST /instant-rides/availability (go offline)', offline, [200, 201]);

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
