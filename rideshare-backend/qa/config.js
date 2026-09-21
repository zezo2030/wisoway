/*
 * Credentials and connection settings for the manual QA harness.
 *
 * Nothing here is hard-coded: values come from the environment, optionally
 * seeded by a gitignored `qa/.env.qa`. Copy `.env.qa.example` to `.env.qa`
 * and fill it in before running any of the scripts.
 */
const fs = require('fs');
const path = require('path');

/** Minimal .env reader — the harness deliberately has no dependencies. */
function loadEnvFile(file) {
  if (!fs.existsSync(file)) return;
  for (const raw of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let val = line.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    // Real environment variables win over the file.
    if (process.env[key] === undefined) process.env[key] = val;
  }
}

loadEnvFile(path.join(__dirname, '.env.qa'));

const missing = [];
function required(name) {
  const v = process.env[name];
  if (!v) {
    missing.push(name);
    return '';
  }
  return v;
}
function optional(name, fallback) {
  return process.env[name] || fallback;
}

const config = {
  base: optional('QA_BASE', 'http://localhost:3003/api/v1'),

  db: {
    host: optional('QA_DB_HOST', 'localhost'),
    port: Number(optional('QA_DB_PORT', '5433')),
    user: optional('QA_DB_USER', 'postgres'),
    password: required('QA_DB_PASSWORD'),
    database: optional('QA_DB_NAME', 'rideshare'),
  },

  admin: {
    email: required('QA_ADMIN_EMAIL'),
    password: required('QA_ADMIN_PASSWORD'),
  },

  driver: {
    password: required('QA_DRIVER_PASSWORD'),
  },

  passenger: {
    /** Password new passengers are created with. */
    password: required('QA_PASSENGER_PASSWORD'),
    /** The other half of the change-password rotation in 02-*. */
    altPassword: required('QA_PASSENGER_ALT_PASSWORD'),
    /** What the forgot-password flow resets to, and later scripts log in with. */
    resetPassword: required('QA_PASSENGER_RESET_PASSWORD'),
  },
};

if (missing.length) {
  throw new Error(
    `QA harness is missing required settings: ${missing.join(', ')}.\n` +
      `Copy rideshare-backend/qa/.env.qa.example to rideshare-backend/qa/.env.qa ` +
      `and fill it in (or export the variables).`,
  );
}

module.exports = config;
