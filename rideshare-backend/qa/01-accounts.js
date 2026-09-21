/* QA 01 — create one account per role and verify the basics of each. */
const L = require('./lib');
const { req, data, errMsg } = L;

const RUN = process.env.QA_RUN || String(Date.now()).slice(-7);
// Jordanian mobile format: +9627XXXXXXXX
const phone = (n) => `+9627${String(RUN).padStart(7, '0').slice(-7)}${n}`;

async function main() {
  const accounts = {};

  L.setSection('Admin login');
  const admin = await L.loginAdmin();
  accounts.admin = admin;
  L.pass('admin logs in with seeded credentials', admin.user.email);
  if (admin.user.role === 'admin') L.pass('admin has admin role');
  else L.fail('admin has admin role', admin.user.role);

  L.setSection('Passenger registration (OTP)');
  const p1 = await L.createPassenger(phone(1), 'QA Passenger One', 'male');
  accounts.passenger1 = p1;
  L.pass('passenger 1 registered', p1.user.id);
  if (p1.user.role === 'passenger') L.pass('passenger 1 role is passenger');
  else L.fail('passenger 1 role is passenger', p1.user.role);
  if (p1.user.isPhoneVerified) L.pass('passenger 1 phone marked verified');
  else L.fail('passenger 1 phone marked verified', 'isPhoneVerified=false');

  const p2 = await L.createPassenger(phone(2), 'QA Passenger Two', 'female');
  accounts.passenger2 = p2;
  L.pass('passenger 2 registered', p2.user.id);

  L.setSection('Passenger re-login (existing account)');
  const relog = await L.createPassenger(phone(1), 'QA Passenger One', 'male');
  if (relog.user.id === p1.user.id) L.pass('re-login returns the same account');
  else L.fail('re-login returns the same account', `${relog.user.id} != ${p1.user.id}`);
  accounts.passenger1.token = relog.token;

  L.setSection('Driver registration (two-step)');
  const d1 = await L.createDriver(phone(3), 'QA Driver One');
  accounts.driver1 = d1;
  L.pass('driver 1 registered', d1.user.id);
  if (d1.user.role === 'driver') L.pass('driver 1 role is driver');
  else L.fail('driver 1 role is driver', d1.user.role);
  if (d1.user.isDriverApproved === false) L.pass('driver 1 starts unapproved');
  else L.fail('driver 1 starts unapproved', `isDriverApproved=${d1.user.isDriverApproved}`);

  const d2 = await L.createDriver(phone(4), 'QA Driver Two');
  accounts.driver2 = d2;
  L.pass('driver 2 registered', d2.user.id);

  L.setSection('Duplicate-phone guard');
  const dup = await req('POST', '/auth/send-otp', { body: { phoneNumber: phone(3) } });
  if (dup.status === 200) {
    const code = await L.latestOtp(phone(3));
    const vp = await req('POST', '/auth/driver/verify-phone', {
      body: { phoneNumber: phone(3), code },
    });
    L.expectStatus('driver/verify-phone rejects an already-registered phone', vp, 409);
  } else {
    L.fail('send-otp for existing driver phone', errMsg(dup));
  }

  L.setSection('Profile reads');
  for (const [k, a] of Object.entries(accounts)) {
    const me = await req('GET', '/users/me', { token: a.token });
    if (me.status === 200) L.pass(`GET /users/me as ${k}`, data(me).role);
    else L.fail(`GET /users/me as ${k}`, `${me.status} ${errMsg(me)}`);
  }

  L.setSection('Admin approves driver 1 + verifies vehicle');
  const pend = await req('GET', '/admin/drivers/pending', { token: admin.token });
  if (pend.status === 200) {
    const list = data(pend);
    const arr = Array.isArray(list) ? list : list.items || list.data || [];
    const found = arr.some((u) => u.id === d1.user.id);
    if (found) L.pass('driver 1 appears in /admin/drivers/pending');
    else L.fail('driver 1 appears in /admin/drivers/pending', `count=${arr.length}`);
  } else {
    L.fail('GET /admin/drivers/pending', `${pend.status} ${errMsg(pend)}`);
  }

  const appr = await req('PATCH', `/admin/users/${d1.user.id}/approve-driver`, {
    token: admin.token,
    body: { approved: true },
  });
  L.expectStatus('admin approves driver 1', appr, [200, 201]);

  const veh = await req('GET', '/admin/vehicles', { token: admin.token });
  let vehicleId = null;
  if (veh.status === 200) {
    const vl = data(veh);
    const arr = Array.isArray(vl) ? vl : vl.items || vl.data || [];
    const mine = arr.find((v) => (v.driverId || v.driver?.id) === d1.user.id);
    vehicleId = mine?.id || null;
    if (mine) L.pass('driver 1 vehicle listed in admin', mine.plateNumber);
    else L.fail('driver 1 vehicle listed in admin', `count=${arr.length}`);
  } else {
    L.fail('GET /admin/vehicles', `${veh.status} ${errMsg(veh)}`);
  }
  if (vehicleId) {
    const vv = await req('PATCH', `/admin/vehicles/${vehicleId}/verify`, {
      token: admin.token,
      body: { isVerified: true },
    });
    L.expectStatus('admin verifies driver 1 vehicle', vv, [200, 201]);
  }

  // also approve driver 2 so instant-ride tests have a second driver
  await req('PATCH', `/admin/users/${d2.user.id}/approve-driver`, {
    token: admin.token,
    body: { approved: true },
  });

  L.setSection('Post-approval driver state');
  const dme = await req('GET', '/users/me', { token: d1.token });
  if (dme.status === 200 && data(dme).isDriverApproved) {
    L.pass('driver 1 reads back as approved');
  } else {
    L.fail('driver 1 reads back as approved', `${dme.status} ${JSON.stringify(data(dme)?.isDriverApproved)}`);
  }

  // persist for the later suites
  const fs = require('fs');
  const out = {
    run: RUN,
    phones: { p1: phone(1), p2: phone(2), d1: phone(3), d2: phone(4) },
    accounts: Object.fromEntries(
      Object.entries(accounts).map(([k, v]) => [
        k,
        { token: v.token, refreshToken: v.refreshToken, id: v.user.id, role: v.user.role, phone: v.phone },
      ]),
    ),
    vehicleId,
  };
  fs.writeFileSync(__dirname + '/accounts.json', JSON.stringify(out, null, 2));
  console.log(`\n(accounts written to qa/accounts.json)`);

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
