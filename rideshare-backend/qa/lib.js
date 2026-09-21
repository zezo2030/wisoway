/* Shared helpers for the manual QA harness (not part of the app build). */
const { Client } = require('pg');

const BASE = process.env.QA_BASE || 'http://localhost:3003/api/v1';

const db = new Client({
  host: 'localhost',
  port: 5433,
  user: 'postgres',
  password: '203050',
  database: 'rideshare',
});
let dbReady = false;
async function sql(text, params = []) {
  if (!dbReady) {
    await db.connect();
    dbReady = true;
  }
  return (await db.query(text, params)).rows;
}
async function closeDb() {
  if (dbReady) await db.end();
}

async function req(method, path, opts = {}) {
  const url = new URL(BASE + path);
  for (const [k, v] of Object.entries(opts.query || {})) {
    if (v !== undefined && v !== null) url.searchParams.set(k, String(v));
  }
  const headers = { 'Content-Type': 'application/json', ...(opts.headers || {}) };
  if (opts.token) headers.Authorization = `Bearer ${opts.token}`;
  const res = await fetch(url, {
    method,
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { status: res.status, body: json, ok: res.ok };
}

/** Unwrap the {success,data} envelope the API uses. */
function data(r) {
  return r.body && typeof r.body === 'object' && 'data' in r.body ? r.body.data : r.body;
}
/**
 * Pull the array out of a list response. The API is not consistent: some
 * endpoints return a bare array, others {data:[...]}, {items:[...]},
 * {trips:[...]} and so on, all inside the {success,data} envelope.
 */
function list(r) {
  const d = data(r);
  if (Array.isArray(d)) return d;
  if (!d || typeof d !== 'object') return [];
  for (const k of ['data', 'items', 'results', 'trips', 'bookings', 'messages',
                   'rows', 'records', 'notifications', 'ratings', 'vehicles',
                   'users', 'payments', 'offers', 'requests', 'complaints']) {
    if (Array.isArray(d[k])) return d[k];
  }
  return [];
}
function errMsg(r) {
  const e = r.body && r.body.error;
  if (!e) return JSON.stringify(r.body).slice(0, 300);
  return typeof e === 'string' ? e : e.message || JSON.stringify(e).slice(0, 300);
}

// ── result tracking ────────────────────────────────────────────────────────
const results = [];
let section = 'general';
function setSection(s) {
  section = s;
  console.log(`\n===== ${s} =====`);
}
function pass(name, note = '') {
  results.push({ section, name, ok: true, note });
  console.log(`  PASS  ${name}${note ? ' — ' + note : ''}`);
}
function fail(name, note = '') {
  results.push({ section, name, ok: false, note });
  console.log(`  FAIL  ${name}${note ? ' — ' + note : ''}`);
}
function skip(name, note = '') {
  results.push({ section, name, ok: null, note });
  console.log(`  SKIP  ${name}${note ? ' — ' + note : ''}`);
}
/** Assert an HTTP call returned one of the expected statuses. */
function expectStatus(name, r, expected) {
  const list = Array.isArray(expected) ? expected : [expected];
  if (list.includes(r.status)) {
    pass(name, `${r.status}`);
    return true;
  }
  fail(name, `got ${r.status}, want ${list.join('/')} :: ${errMsg(r)}`);
  return false;
}
function summary() {
  const p = results.filter((r) => r.ok === true).length;
  const f = results.filter((r) => r.ok === false).length;
  const s = results.filter((r) => r.ok === null).length;
  console.log(`\n=============================================`);
  console.log(`TOTAL ${results.length}  PASS ${p}  FAIL ${f}  SKIP ${s}`);
  if (f) {
    console.log(`\n--- FAILURES ---`);
    for (const r of results.filter((x) => x.ok === false)) {
      console.log(`  [${r.section}] ${r.name} :: ${r.note}`);
    }
  }
  if (s) {
    console.log(`\n--- SKIPPED ---`);
    for (const r of results.filter((x) => x.ok === null)) {
      console.log(`  [${r.section}] ${r.name} :: ${r.note}`);
    }
  }
  return f;
}

// ── account helpers ────────────────────────────────────────────────────────
async function latestOtp(phone) {
  const rows = await sql(
    `SELECT code FROM otp_codes WHERE "phoneNumber" = $1 ORDER BY "createdAt" DESC LIMIT 1`,
    [phone],
  );
  if (!rows.length) throw new Error(`no OTP row for ${phone}`);
  return rows[0].code;
}

function device(label) {
  return {
    deviceId: `qa-${label}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    installSalt: `salt-${Math.random().toString(36).slice(2, 10)}`,
    platform: 'android',
    locale: 'en',
    label: `QA ${label}`,
  };
}

/** Register (or log in) a passenger through the OTP flow. */
async function createPassenger(phone, name, gender = 'male') {
  const s = await req('POST', '/auth/send-otp', { body: { phoneNumber: phone } });
  if (s.status !== 200) throw new Error(`send-otp ${s.status} ${errMsg(s)}`);
  const code = await latestOtp(phone);
  const v = await req('POST', '/auth/verify-otp', {
    body: {
      phoneNumber: phone,
      code,
      name,
      gender,
      role: 'passenger',
      password: 'Passenger@12345',
      device: device(name),
    },
  });
  if (v.status !== 200 && v.status !== 201) {
    throw new Error(`verify-otp ${v.status} ${errMsg(v)}`);
  }
  const d = data(v);
  return { token: d.accessToken, refreshToken: d.refreshToken, user: d.user, phone };
}

/** Register a driver through the two-step driver flow. */
async function createDriver(phone, name, extra = {}) {
  const s = await req('POST', '/auth/send-otp', { body: { phoneNumber: phone } });
  if (s.status !== 200) throw new Error(`send-otp ${s.status} ${errMsg(s)}`);
  const code = await latestOtp(phone);
  const vp = await req('POST', '/auth/driver/verify-phone', {
    body: { phoneNumber: phone, code },
  });
  if (vp.status !== 200) throw new Error(`driver/verify-phone ${vp.status} ${errMsg(vp)}`);
  const token = data(vp).registrationToken;
  const r = await req('POST', '/auth/driver/register', {
    body: {
      registrationToken: token,
      name,
      gender: 'male',
      photoUrl: 'https://example.com/driver.jpg',
      password: 'Driver@12345',
      vehicleType: extra.vehicleType || 'sedan',
      plateNumber: extra.plateNumber || `QA${Math.floor(Math.random() * 90000 + 10000)}`,
      model: extra.model || 'Toyota Corolla 2022',
      seats: extra.seats || 4,
      carImageUrl: 'https://example.com/car.jpg',
      insuranceImageUrl: 'https://example.com/ins.jpg',
      licenseImageUrl: 'https://example.com/lic.jpg',
      vehicleLicenseImageUrl: 'https://example.com/vlic.jpg',
      device: device(name),
    },
  });
  if (r.status !== 200 && r.status !== 201) {
    throw new Error(`driver/register ${r.status} ${errMsg(r)}`);
  }
  const d = data(r);
  return { token: d.accessToken, refreshToken: d.refreshToken, user: d.user, phone };
}

async function loginAdmin() {
  const r = await req('POST', '/auth/login', {
    body: { email: 'admin@rideshare.com', password: 'Admin@123456' },
  });
  if (r.status !== 200 && r.status !== 201) throw new Error(`admin login ${r.status} ${errMsg(r)}`);
  const d = data(r);
  return { token: d.accessToken, refreshToken: d.refreshToken, user: d.user };
}

module.exports = {
  BASE, req, data, list, errMsg, sql, closeDb,
  setSection, pass, fail, skip, expectStatus, summary, results,
  latestOtp, device, createPassenger, createDriver, loginAdmin,
};
