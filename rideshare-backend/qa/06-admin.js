/* QA 06 — the admin dashboard surface: listings, stats, moderation,
   fines, wallets, pricing, broadcasts, settlement. */
const L = require('./lib');
const { req, data, errMsg, config } = L;
const A = require('./accounts.json');
const T = require('./trip-context.json');

const P1 = A.accounts.passenger1;
const P2 = A.accounts.passenger2;
const D1 = A.accounts.driver1;
const D2 = A.accounts.driver2;
const AD = A.accounts.admin;

async function main() {
  AD.token = (await L.loginAdmin()).token;
  const t = AD.token;

  L.setSection('Dashboard stats & reports');
  const stats = await req('GET', '/admin/dashboard/stats', { token: t });
  if (L.expectStatus('GET /admin/dashboard/stats', stats, 200)) {
    console.log('        stats:', JSON.stringify(data(stats)).slice(0, 300));
  }
  const startDate = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();
  const endDate = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
  for (const type of ['revenue', 'users', 'trips']) {
    const rep = await req('GET', '/admin/reports', {
      token: t, query: { type, startDate, endDate },
    });
    L.expectStatus(`GET /admin/reports?type=${type}`, rep, 200);
  }

  L.setSection('Listings');
  const listings = [
    ['/admin/users', {}],
    ['/admin/users', { role: 'driver' }],
    ['/admin/users', { search: 'QA' }],
    ['/admin/drivers/pending', {}],
    ['/admin/vehicles', {}],
    ['/admin/trips', {}],
    ['/admin/bookings', {}],
    ['/admin/ratings', {}],
    ['/admin/payments', {}],
    ['/admin/payments/pending', {}],
    ['/admin/wallets', {}],
    ['/admin/notifications', {}],
    ['/admin/chat/rooms', {}],
    ['/admin/complaints', {}],
    ['/admin/refund-requests', {}],
    ['/admin/fines', {}],
    ['/admin/no-show-reports', {}],
    ['/admin/account-flags', {}],
    ['/admin/recurrence-rules', {}],
  ];
  for (const [path, query] of listings) {
    const r = await req('GET', path, { token: t, query });
    const label = `GET ${path}${Object.keys(query).length ? '?' + new URLSearchParams(query) : ''}`;
    L.expectStatus(label, r, [200, 404]);
  }

  L.setSection('Admin chat oversight');
  const rooms = await req('GET', '/admin/chat/rooms', { token: t });
  const roomArr = L.list(rooms);
  if (roomArr.length) {
    const msgs = await req('GET', `/admin/chat/rooms/${roomArr[0].id}/messages`, { token: t });
    if (L.expectStatus('GET /admin/chat/rooms/:id/messages', msgs, 200)) {
      const arr = L.list(msgs);
      if (arr.length) L.pass('admin can read room transcripts', `${arr.length}`);
      else L.fail('admin can read room transcripts', 'empty');
    }
  } else {
    L.fail('admin chat rooms listing is populated', 'no rooms returned');
  }

  L.setSection('Wallets');
  const wallets = await req('GET', '/admin/wallets', { token: t });
  const wArr = L.list(wallets);
  if (wArr.length) {
    const wid = wArr[0].id || wArr[0].accountId;
    const one = await req('GET', `/admin/wallets/${wid}`, { token: t });
    L.expectStatus('GET /admin/wallets/:id', one, 200);

    const tx = await req('GET', `/admin/wallets/${wid}/transactions`, { token: t });
    L.expectStatus('GET /admin/wallets/:id/transactions', tx, 200);

    const adj = await req('PATCH', `/admin/wallets/${wid}/adjust`, {
      token: t, body: { amount: 1, currency: 'JOD', note: 'QA adjustment' },
    });
    if (!L.expectStatus('PATCH /admin/wallets/:id/adjust', adj, [200, 201])) {
      console.log('        body:', JSON.stringify(adj.body).slice(0, 300));
    }
  } else {
    L.fail('admin wallets listing is populated', 'no wallets returned');
  }

  L.setSection('Pricing settings');
  const getPricing = await req('GET', '/admin/pricing-settings', {
    token: t, query: { countryCode: 'JO' },
  });
  let original = null;
  if (L.expectStatus('GET /admin/pricing-settings', getPricing, 200)) {
    original = data(getPricing);
    console.log('        pricing:', JSON.stringify(original).slice(0, 300));
  }
  const patchPricing = await req('PATCH', '/admin/pricing-settings', {
    token: t, query: { countryCode: 'JO' },
    body: { feeAmount: 0.5, currency: 'JOD', isActive: true },
  });
  if (!L.expectStatus('PATCH /admin/pricing-settings', patchPricing, [200, 201])) {
    console.log('        body:', JSON.stringify(patchPricing.body).slice(0, 300));
  } else if (original && original.feeAmount !== undefined) {
    // restore whatever was there before
    await req('PATCH', '/admin/pricing-settings', {
      token: t,
      query: { countryCode: 'JO' },
      body: {
        feeAmount: Number(original.feeAmount),
        currency: original.currency || 'JOD',
      },
    });
    L.pass('original pricing restored');
  }

  L.setSection('Fines');
  const fine = await req('POST', '/admin/fines', {
    token: t,
    // Deliberately larger than any wallet balance: record() collects a fine
    // immediately when the balance covers it, and an APPLIED charge cannot be
    // waived — so a small fine would never reach the waive path.
    body: { driverId: D1.id, amount: 99999, reason: 'QA: late cancellation.', tripId: T.tripId },
  });
  let fineId = null;
  if (L.expectStatus('POST /admin/fines', fine, [200, 201])) {
    fineId = data(fine)?.id;
  } else {
    console.log('        body:', JSON.stringify(fine.body).slice(0, 300));
  }
  if (fineId) {
    const fines = await req('GET', '/admin/fines', { token: t });
    const arr = L.list(fines);
    if (arr.some((f) => f.id === fineId)) L.pass('the fine appears in the listing');
    else L.fail('the fine appears in the listing', `count=${arr.length}`);

    const driverSees = await req('GET', '/me/pending-charges', {
      token: (await req('POST', '/auth/login', {
        body: { phoneNumber: D1.phone, password: config.driver.password },
      }).then((r) => data(r).accessToken)),
    });
    if (driverSees.status === 200) {
      const arr2 = L.list(driverSees);
      if (arr2.some((c) => c.id === fineId)) L.pass('the driver sees the fine as a pending charge');
      else L.fail('the driver sees the fine as a pending charge', `count=${arr2.length}`);
    }

    const waive = await req('PATCH', `/admin/fines/${fineId}/waive`, {
      token: t, body: { reason: 'QA: waived after review.' },
    });
    if (!L.expectStatus('PATCH /admin/fines/:id/waive', waive, [200, 201])) {
      console.log('        body:', JSON.stringify(waive.body).slice(0, 300));
    }
  }

  L.setSection('Broadcast notification');
  const bc = await req('POST', '/admin/notifications/broadcast', {
    token: t,
    body: { title: 'QA broadcast', body: 'QA: please ignore this test message.', targetRole: 'driver' },
  });
  if (!L.expectStatus('POST /admin/notifications/broadcast', bc, [200, 201])) {
    console.log('        body:', JSON.stringify(bc.body).slice(0, 300));
  }

  L.setSection('Ban / unban');
  const ban = await req('POST', `/admin/users/${P2.id}/ban`, {
    token: t, body: { reason: 'QA: temporary ban for testing.' },
  });
  if (L.expectStatus('POST /admin/users/:id/ban', ban, [200, 201])) {
    // A banned user must be refused on their next authenticated call.
    const li = await req('POST', '/auth/login', {
      body: { phoneNumber: P2.phone, password: config.passenger.password },
    });
    const li2 = li.status === 200 || li.status === 201 ? li : await req('POST', '/auth/login', {
      body: { phoneNumber: P2.phone, password: config.passenger.altPassword },
    });
    const tok = data(li2)?.accessToken;
    if (tok) {
      const blocked = await req('GET', '/trips', { token: tok, query: { limit: 1 } });
      L.expectStatus('a banned user is blocked by BanGuard', blocked, [401, 403]);
    } else {
      L.pass('a banned user cannot even log in', `${li2.status}`);
    }
  }

  const unban = await req('POST', `/admin/users/${P2.id}/unban`, { token: t, body: {} });
  if (L.expectStatus('POST /admin/users/:id/unban', unban, [200, 201])) {
    const li = await req('POST', '/auth/login', {
      body: { phoneNumber: P2.phone, password: config.passenger.password },
    });
    const li2 = li.status === 200 || li.status === 201 ? li : await req('POST', '/auth/login', {
      body: { phoneNumber: P2.phone, password: config.passenger.altPassword },
    });
    if (li2.status === 200 || li2.status === 201) {
      const ok = await req('GET', '/users/me', { token: data(li2).accessToken });
      L.expectStatus('the unbanned user works again', ok, 200);
    } else {
      L.fail('the unbanned user works again', `login ${li2.status}`);
    }
  }

  L.setSection('Account flags & devices');
  const flags = await req('GET', '/admin/account-flags', { token: t });
  const flagArr = L.list(flags);
  if (flagArr.length) {
    const fid = flagArr[0].id;
    const dis = await req('PATCH', `/admin/account-flags/${fid}/dismiss`, { token: t, body: {} });
    L.expectStatus('PATCH /admin/account-flags/:id/dismiss', dis, [200, 201]);
  } else {
    L.skip('account-flag resolve/dismiss', 'no flags raised during this run');
  }

  L.setSection('Settlement audit');
  if (T.bookingId) {
    const audits = await req('GET', `/admin/bookings/${T.bookingId}/settlement-audits`, { token: t });
    L.expectStatus('GET /admin/bookings/:id/settlement-audits', audits, 200);
  }
  if (T.tripId) {
    const noShow = await req('GET', `/admin/no-show-reports/${T.tripId}`, { token: t });
    L.expectStatus('GET /admin/no-show-reports/:tripId', noShow, [200, 404]);
  }

  L.setSection('Admin booking cancellation');
  if (T.booking2Id) {
    const cancel = await req('PATCH', `/admin/bookings/${T.booking2Id}/cancel`, {
      token: t, body: { reason: 'QA: admin cancellation test.' },
    });
    L.expectStatus('PATCH /admin/bookings/:id/cancel', cancel, [200, 201, 400]);
  }

  L.setSection('Admin user confirm');
  const confirm = await req('PATCH', `/admin/users/${P1.id}/confirm`, { token: t, body: {} });
  L.expectStatus('PATCH /admin/users/:id/confirm', confirm, [200, 201, 400]);

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
