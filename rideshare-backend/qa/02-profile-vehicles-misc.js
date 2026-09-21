/* QA 02 — profile, vehicles, locations, notifications, support, devices. */
const L = require('./lib');
const { req, data, errMsg, config } = L;
const A = require('./accounts.json');

const P1 = A.accounts.passenger1;
const P2 = A.accounts.passenger2;
const D1 = A.accounts.driver1;
const D2 = A.accounts.driver2;
const AD = A.accounts.admin;

async function main() {
  L.setSection('Profile — read & update');
  const me = await req('GET', '/users/me', { token: P1.token });
  L.expectStatus('GET /users/me', me, 200);

  const upd = await req('PATCH', '/users/me', {
    token: P1.token,
    body: { name: 'QA Passenger One Renamed', city: 'Amman' },
  });
  if (L.expectStatus('PATCH /users/me (name + city)', upd, 200)) {
    const d = data(upd);
    if (d.name === 'QA Passenger One Renamed') L.pass('name persisted');
    else L.fail('name persisted', JSON.stringify(d.name));
    if (d.city === 'Amman') L.pass('city persisted');
    else L.fail('city persisted', JSON.stringify(d.city));
  }

  const pub = await req('GET', `/users/${D1.id}`, { token: P1.token });
  L.expectStatus('GET /users/:id (public profile of a driver)', pub, 200);

  const stats = await req('GET', `/users/${D1.id}/stats`, { token: P1.token });
  L.expectStatus('GET /users/:id/stats', stats, 200);

  const fcm = await req('PATCH', '/users/me/fcm-token', {
    token: P1.token,
    body: { fcmToken: 'qa-fcm-token-abc123' },
  });
  L.expectStatus('PATCH /users/me/fcm-token', fcm, 200);

  L.setSection('Vehicles');
  const types = await req('GET', '/vehicles/types', { token: D1.token });
  let typeIds = [];
  if (L.expectStatus('GET /vehicles/types', types, 200)) {
    const t = data(types);
    const arr = Array.isArray(t) ? t : t.items || t.types || [];
    typeIds = arr.map((x) => x.id || x.key || x.code || x.value || x);
    if (arr.length) L.pass('vehicle types returned', `${arr.length}: ${typeIds.join(',')}`);
    else L.fail('vehicle types returned', 'empty list');
  }

  const myVeh = await req('GET', '/vehicles/my', { token: D1.token });
  let vId = null;
  if (L.expectStatus('GET /vehicles/my (driver)', myVeh, 200)) {
    const v = data(myVeh);
    const arr = Array.isArray(v) ? v : v.items || [v];
    vId = arr[0]?.id;
    if (vId) L.pass('driver has the vehicle created at registration', arr[0].plateNumber);
    else L.fail('driver has the vehicle created at registration', JSON.stringify(v).slice(0, 200));
  }

  if (vId) {
    const pv = await req('PATCH', `/vehicles/${vId}`, {
      token: D1.token,
      body: { model: 'Toyota Corolla 2023', seats: 4 },
    });
    L.expectStatus('PATCH /vehicles/:id (own vehicle)', pv, 200);

    const foreign = await req('PATCH', `/vehicles/${vId}`, {
      token: D2.token,
      body: { model: 'Hacked' },
    });
    L.expectStatus('PATCH /vehicles/:id by another driver is rejected', foreign, [403, 404]);
  }

  const passVeh = await req('POST', '/vehicles', {
    token: P1.token,
    body: { vehicleType: typeIds[0] || 'sedan', plateNumber: 'PX1234', model: 'X', carImageUrl: 'https://e.com/c.jpg' },
  });
  L.expectStatus('passenger cannot create a vehicle', passVeh, [403, 401]);

  L.setSection('Locations');
  const cities = await req('GET', '/locations/cities', { token: P1.token });
  if (L.expectStatus('GET /locations/cities', cities, 200)) {
    const c = data(cities);
    const arr = Array.isArray(c) ? c : c.items || c.cities || [];
    if (arr.length) L.pass('cities list is populated', `${arr.length}`);
    else L.fail('cities list is populated', 'empty');
  }

  const ac = await req('GET', '/locations/autocomplete', {
    token: P1.token,
    query: { q: 'Amman', lang: 'en' },
  });
  L.expectStatus('GET /locations/autocomplete', ac, [200, 424, 502, 503]);

  const dist = await req('GET', '/locations/distance', {
    token: P1.token,
    query: { fromLatitude: 31.9539, fromLongitude: 35.9106, toLatitude: 32.0727, toLongitude: 36.0879 },
  });
  L.expectStatus('GET /locations/distance', dist, [200, 400, 424, 502, 503]);

  const rev = await req('GET', '/locations/reverse', {
    token: P1.token, query: { lat: 31.9539, lng: 35.9106, lang: 'en' },
  });
  L.expectStatus('GET /locations/reverse', rev, [200, 400, 424, 502, 503]);

  L.setSection('Notifications');
  const nl = await req('GET', '/notifications', { token: P1.token });
  L.expectStatus('GET /notifications', nl, 200);

  const uc = await req('GET', '/notifications/unread-count', { token: P1.token });
  L.expectStatus('GET /notifications/unread-count', uc, 200);

  const regDev = await req('POST', '/notifications/devices', {
    token: P1.token,
    body: { token: 'qa-device-token-1', platform: 'android' },
  });
  L.expectStatus('POST /notifications/devices', regDev, [200, 201]);

  const webTok = await req('POST', '/notifications/web-token', {
    token: AD.token,
    body: { token: 'qa-web-token-1' },
  });
  L.expectStatus('POST /notifications/web-token (dashboard FCM)', webTok, [200, 201]);

  const readAll = await req('PATCH', '/notifications/read-all', { token: P1.token });
  L.expectStatus('PATCH /notifications/read-all', readAll, 200);

  L.setSection('Auth — devices, refresh, password');
  const devs = await req('GET', '/auth/devices', { token: P1.token });
  let deviceRows = [];
  if (L.expectStatus('GET /auth/devices', devs, 200)) {
    const d = data(devs);
    deviceRows = Array.isArray(d) ? d : d.items || d.devices || [];
    if (deviceRows.length) L.pass('registered devices are listed', `${deviceRows.length}`);
    else L.fail('registered devices are listed', 'empty');
  }

  const rf = await req('POST', '/auth/refresh', { body: { refreshToken: P2.refreshToken } });
  if (L.expectStatus('POST /auth/refresh', rf, [200, 201])) {
    const d = data(rf);
    if (d.accessToken) {
      L.pass('refresh returns a new access token');
      const check = await req('GET', '/users/me', { token: d.accessToken });
      L.expectStatus('refreshed token is accepted', check, 200);
    } else L.fail('refresh returns a new access token', JSON.stringify(d).slice(0, 200));
  }

  const badRf = await req('POST', '/auth/refresh', { body: { refreshToken: 'garbage.token.here' } });
  L.expectStatus('POST /auth/refresh rejects a bogus token', badRf, [400, 401]);

  // Change password on passenger 2, then confirm login with the new one.
  // Re-runs of this suite start from the rotated password, so try both.
  let p2Pw = config.passenger.password;
  let p2Token = P2.token;
  for (const cand of [config.passenger.password, config.passenger.altPassword]) {
    const li = await req('POST', '/auth/login', {
      body: { phoneNumber: P2.phone, password: cand },
    });
    if (li.status === 200 || li.status === 201) {
      p2Pw = cand;
      p2Token = data(li).accessToken;
      break;
    }
  }
  const nextPw =
    p2Pw === config.passenger.password
      ? config.passenger.altPassword
      : config.passenger.password;
  const cp = await req('POST', '/auth/change-password', {
    token: p2Token,
    body: { currentPassword: p2Pw, newPassword: nextPw },
  });
  if (L.expectStatus('POST /auth/change-password', cp, [200, 201])) {
    const relog = await req('POST', '/auth/login', {
      body: { phoneNumber: P2.phone, password: nextPw },
    });
    L.expectStatus('login with the new password', relog, [200, 201]);
    const oldPw = await req('POST', '/auth/login', {
      body: { phoneNumber: P2.phone, password: p2Pw },
    });
    L.expectStatus('login with the old password is rejected', oldPw, [400, 401]);
  }

  L.setSection('Password reset (forgot → verify → reset)');
  const fp = await req('POST', '/auth/forgot-password', { body: { phoneNumber: P1.phone } });
  if (L.expectStatus('POST /auth/forgot-password', fp, [200, 201])) {
    const code = await L.latestOtp(P1.phone);
    const vr = await req('POST', '/auth/verify-reset-otp', {
      body: { phoneNumber: P1.phone, code },
    });
    if (L.expectStatus('POST /auth/verify-reset-otp', vr, [200, 201])) {
      const resetToken = data(vr).resetToken || data(vr).token;
      const rp = await req('POST', '/auth/reset-password', {
        body: { resetToken, newPassword: config.passenger.resetPassword },
      });
      if (L.expectStatus('POST /auth/reset-password', rp, [200, 201])) {
        const li = await req('POST', '/auth/login', {
          body: { phoneNumber: P1.phone, password: config.passenger.resetPassword },
        });
        L.expectStatus('login with the reset password', li, [200, 201]);
        if (li.status === 200 || li.status === 201) {
          // the reset invalidated P1's old token; refresh it for later suites
          const fs = require('fs');
          A.accounts.passenger1.token = data(li).accessToken;
          A.accounts.passenger1.refreshToken = data(li).refreshToken;
          fs.writeFileSync(__dirname + '/accounts.json', JSON.stringify(A, null, 2));
          L.pass('passenger1 token refreshed for later suites');
        }
      }
    }
  }

  L.setSection('Support & role guards');
  const sc = await req('GET', '/support/config', { token: P1.token });
  L.expectStatus('GET /support/config', sc, 200);

  // P2's password changed above, which invalidates its token — log in again.
  const p2Fresh = await req('POST', '/auth/login', {
    body: { phoneNumber: P2.phone, password: nextPw },
  });
  const guard = await req('GET', '/admin/users', { token: data(p2Fresh).accessToken });
  L.expectStatus('passenger cannot reach /admin/users', guard, 403);

  const noAuth = await req('GET', '/users/me');
  L.expectStatus('unauthenticated /users/me is rejected', noAuth, 401);

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
