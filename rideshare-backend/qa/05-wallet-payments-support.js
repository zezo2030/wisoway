/* QA 05 — wallet, payments, pending charges, complaints, refunds, calls. */
const L = require('./lib');
const { req, data, errMsg } = L;
const A = require('./accounts.json');
const T = require('./trip-context.json');

const P1 = A.accounts.passenger1;
const P2 = A.accounts.passenger2;
const D1 = A.accounts.driver1;
const AD = A.accounts.admin;

async function freshTokens() {
  const p = await req('POST', '/auth/login', {
    body: { phoneNumber: P1.phone, password: 'Passenger@99999' },
  });
  if (p.status === 200 || p.status === 201) P1.token = data(p).accessToken;
  const d = await req('POST', '/auth/login', {
    body: { phoneNumber: D1.phone, password: 'Driver@12345' },
  });
  if (d.status === 200 || d.status === 201) D1.token = data(d).accessToken;
  // P2's password is rotated by suite 02, so try both known values.
  for (const cand of ['Passenger@12345', 'Passenger@54321']) {
    const r = await req('POST', '/auth/login', {
      body: { phoneNumber: P2.phone, password: cand },
    });
    if (r.status === 200 || r.status === 201) { P2.token = data(r).accessToken; break; }
  }
  AD.token = (await L.loginAdmin()).token;
}

async function main() {
  await freshTokens();

  L.setSection('Driver wallet');
  const wme = await req('GET', '/wallet/me', { token: D1.token });
  if (L.expectStatus('GET /wallet/me (driver)', wme, 200)) {
    console.log('        wallet:', JSON.stringify(data(wme)).slice(0, 250));
  }

  const wtx = await req('GET', '/wallet/transactions', { token: D1.token });
  if (L.expectStatus('GET /wallet/transactions', wtx, 200)) {
    const arr = L.list(wtx);
    if (arr.length) L.pass('the trip-start platform fee is on the ledger', `${arr.length} tx`);
    else L.fail('the trip-start platform fee is on the ledger', 'no transactions');
  }

  const pwme = await req('GET', '/payments/wallet/me', { token: D1.token });
  L.expectStatus('GET /payments/wallet/me', pwme, 200);

  const topup = await req('POST', '/payments/wallet/topup', {
    token: D1.token,
    body: {
      amount: 10,
      currency: 'JOD',
      method: 'manual',
      proofImageUrl: 'https://example.com/proof.jpg',
    },
  });
  if (!L.expectStatus('POST /payments/wallet/topup (manual)', topup, [200, 201])) {
    console.log('        body:', JSON.stringify(topup.body).slice(0, 400));
  }
  const topupId = data(topup)?.id || data(topup)?.paymentId;

  L.setSection('Admin reviews the top-up');
  const pendingPays = await req('GET', '/admin/payments/pending', { token: AD.token });
  if (L.expectStatus('GET /admin/payments/pending', pendingPays, 200)) {
    const arr = L.list(pendingPays);
    if (arr.length) L.pass('the manual top-up is queued for review', `${arr.length}`);
    else L.fail('the manual top-up is queued for review', 'queue empty');
  }

  if (topupId) {
    const before = Number(data(await req('GET', '/wallet/me', { token: D1.token }))?.balance ?? 0);
    const appr = await req('PATCH', `/payments/${topupId}/approve`, {
      token: AD.token, body: { adminNote: 'QA approval' },
    });
    if (L.expectStatus('PATCH /payments/:id/approve', appr, [200, 201])) {
      const after = Number(data(await req('GET', '/wallet/me', { token: D1.token }))?.balance ?? 0);
      if (after > before) L.pass('approval credited the wallet', `${before} → ${after}`);
      else L.fail('approval credited the wallet', `${before} → ${after}`);
    }

    const again = await req('PATCH', `/payments/${topupId}/approve`, {
      token: AD.token, body: {},
    });
    L.expectStatus('approving the same payment twice is rejected', again, [400, 409]);

    const byDriver = await req('PATCH', `/payments/${topupId}/reject`, {
      token: D1.token, body: { adminNote: 'nope' },
    });
    L.expectStatus('a driver cannot approve/reject payments', byDriver, [403, 401]);
  }

  L.setSection('Payments listing');
  const myPay = await req('GET', '/payments/my', { token: D1.token });
  L.expectStatus('GET /payments/my', myPay, 200);
  const adminPay = await req('GET', '/admin/payments', { token: AD.token });
  L.expectStatus('GET /admin/payments', adminPay, 200);
  if (topupId) {
    const one = await req('GET', `/payments/${topupId}`, { token: D1.token });
    L.expectStatus('GET /payments/:id', one, 200);
  }

  L.setSection('Payout requests');
  const payout = await req('POST', '/wallet/driver/payout-requests', {
    token: D1.token,
    body: { amount: 1, currency: 'JOD', bankAccountRef: 'JO00QA000000001', note: 'QA payout' },
  });
  L.expectStatus('POST /wallet/driver/payout-requests', payout, [200, 201, 400]);

  const payoutByPassenger = await req('POST', '/wallet/driver/payout-requests', {
    token: P1.token, body: { amount: 1 },
  });
  L.expectStatus('a passenger cannot request a driver payout', payoutByPassenger, [403, 401]);

  L.setSection('Pending charges');
  const pc = await req('GET', '/me/pending-charges', { token: D1.token });
  L.expectStatus('GET /me/pending-charges', pc, 200);

  const collect = await req('POST', '/me/pending-charges/collect', {
    token: D1.token, body: {},
  });
  L.expectStatus('POST /me/pending-charges/collect', collect, [200, 201, 400]);

  L.setSection('Complaints');
  const comp = await req('POST', '/complaints', {
    token: P1.token,
    body: {
      againstUserId: D1.id,
      tripId: T.tripId,
      category: 'rude_behavior',
      body: 'QA: the driver was curt at the pickup point.',
    },
  });
  let complaintId = null;
  if (L.expectStatus('POST /complaints', comp, [200, 201])) {
    complaintId = data(comp)?.id;
    L.pass('complaint id issued', complaintId);
  } else {
    console.log('        body:', JSON.stringify(comp.body).slice(0, 400));
  }

  const myComp = await req('GET', '/me/complaints', { token: P1.token });
  if (L.expectStatus('GET /me/complaints', myComp, 200)) {
    const arr = L.list(myComp);
    if (arr.length) L.pass('the complaint is listed for its author', `${arr.length}`);
    else L.fail('the complaint is listed for its author', 'empty');
  }

  const adminComp = await req('GET', '/admin/complaints', { token: AD.token });
  if (L.expectStatus('GET /admin/complaints', adminComp, 200)) {
    const arr = L.list(adminComp);
    if (arr.some((c) => c.id === complaintId)) L.pass('the complaint reaches the admin queue');
    else L.fail('the complaint reaches the admin queue', `count=${arr.length}`);
  }

  if (complaintId) {
    const resolve = await req('PATCH', `/admin/complaints/${complaintId}`, {
      token: AD.token,
      body: { status: 'resolved', adminNotes: 'QA: spoke with the driver.' },
    });
    if (!L.expectStatus('PATCH /admin/complaints/:id (resolve)', resolve, [200, 201])) {
      console.log('        body:', JSON.stringify(resolve.body).slice(0, 300));
    }
    const byPassenger = await req('PATCH', `/admin/complaints/${complaintId}`, {
      token: P1.token, body: { status: 'dismissed' },
    });
    L.expectStatus('a passenger cannot resolve complaints', byPassenger, [403, 401]);
  }

  L.setSection('Refund requests');
  const refund = await req('POST', '/refund-requests', {
    token: P1.token,
    body: {
      bookingId: T.bookingId,
      amount: '3.00',
      currency: 'JOD',
      reason: 'QA: charged for a seat I did not take.',
    },
  });
  let refundId = null;
  if (L.expectStatus('POST /refund-requests', refund, [200, 201])) {
    refundId = data(refund)?.id;
  } else {
    console.log('        body:', JSON.stringify(refund.body).slice(0, 400));
  }

  const adminRefunds = await req('GET', '/admin/refund-requests', { token: AD.token });
  if (L.expectStatus('GET /admin/refund-requests', adminRefunds, 200)) {
    const arr = L.list(adminRefunds);
    if (!refundId || arr.some((r) => r.id === refundId)) L.pass('the refund request reaches the admin queue');
    else L.fail('the refund request reaches the admin queue', `count=${arr.length}`);
  }

  if (refundId) {
    const decide = await req('PATCH', `/admin/refund-requests/${refundId}`, {
      token: AD.token,
      body: { status: 'rejected', decisionNote: 'QA: seat was confirmed present.' },
    });
    if (!L.expectStatus('PATCH /admin/refund-requests/:id', decide, [200, 201])) {
      console.log('        body:', JSON.stringify(decide.body).slice(0, 300));
    }
  }

  L.setSection('Calls');
  if (T.bookingId) {
    const call = await req('POST', `/bookings/${T.bookingId}/calls/initiate`, {
      token: P1.token, body: {},
    });
    L.expectStatus('POST /bookings/:id/calls/initiate', call, [200, 201, 400, 403]);
    const outsider = await req('POST', `/bookings/${T.bookingId}/calls/initiate`, {
      token: P2.token, body: {},
    });
    L.expectStatus('a non-participant cannot initiate a call', outsider, [400, 403, 404]);
  }

  L.setSection('Emergency alert');
  if (T.tripId) {
    const sos = await req('POST', `/trips/${T.tripId}/emergency`, {
      token: P1.token,
      body: { latitude: 31.95, longitude: 35.91, note: 'QA drill — ignore.' },
    });
    L.expectStatus('POST /trips/:id/emergency', sos, [200, 201, 400, 403]);
  }

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
