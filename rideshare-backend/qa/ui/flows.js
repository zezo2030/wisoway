/* Reusable UI flows for the VisionWay app, built on qa/ui/driver.js. */
const U = require('./driver');
const L = require('../lib');

/**
 * Enter a 6-digit OTP.
 *
 * The code row is built with `textDirection: TextDirection.ltr` even in Arabic,
 * so box 0 is the LEFTMOST one. Each box holds a single character and does not
 * accept a bulk `input text`, so every digit is tapped and typed separately.
 */
async function enterOtp(code) {
  const nodes = await U.dump();
  const boxes = nodes
    .filter((n) => n.clickable && n.x2 - n.x1 < 200 && n.y2 - n.y1 > 80)
    .sort((a, b) => a.x1 - b.x1);
  if (boxes.length < 6) throw new Error(`found ${boxes.length} OTP boxes`);
  for (const b of boxes.slice(0, 6)) {
    await U.tapPoint(b.x, b.y, 200);
    await U.key(67, 120);
  }
  for (let i = 0; i < 6; i++) {
    await U.tapPoint(boxes[i].x, boxes[i].y, 250);
    await U.type(code[i], 300);
  }
  await U.sleep(800);
}

/** Tap the wide primary button at the bottom of the current screen. */
async function tapPrimary(labelNeedle, settleMs = 5000) {
  const nodes = await U.dump();
  const own = nodes.filter((n) => n.pkg === U.APP_PKG);
  const candidates = own.filter(
    (n) => n.clickable && n.x2 - n.x1 > 800 && n.label.includes(labelNeedle),
  );
  const btn =
    candidates.sort((a, b) => b.y1 - a.y1)[0] ||
    own
      .filter((n) => n.clickable && n.x2 - n.x1 > 800)
      .sort((a, b) => b.y1 - a.y1)[0];
  if (!btn) throw new Error(`no primary button for "${labelNeedle}"`);
  await U.tapPoint(btn.x, btn.y, settleMs);
  return btn;
}

/**
 * Tap a read-only "select" field.
 *
 * These are TextFormFields with `isDense: true` and no border, so the hit area
 * is a thin line well below the label and helper text that sit above it inside
 * the same card. Probe a few offsets until the expected sheet shows up.
 */
async function tapSelect(labelNeedle, expectInSheet) {
  for (const dy of [130, 160, 100, 190, 70]) {
    const nodes = await U.dump();
    const label = nodes.find((n) => n.label.includes(labelNeedle));
    if (!label) throw new Error(`no label "${labelNeedle}"`);
    await U.tapPoint(470, label.y2 + dy, 1300);
    const t = await U.screenText();
    if (t.includes(expectInSheet)) return true;
  }
  throw new Error(`select "${labelNeedle}" never opened`);
}

/** Pick an image from the gallery for the currently open picker sheet. */
async function pickFromGallery() {
  await U.tap(['من المعرض'], { settleMs: 4000 });
  await U.tap(['Photo taken on'], { settleMs: 2500 });
  await U.tap(['Done'], { settleMs: 5000 });
}

/** Tap an upload tile, then choose a gallery image. */
async function uploadVia(tileNeedle) {
  await U.tap([tileNeedle], { settleMs: 2500 });
  await pickFromGallery();
}

/** Read the most recent OTP the backend generated for a phone. */
async function otpFor(phone) {
  return L.latestOtp(phone);
}

/** Log in with phone + password on the sign-in screen. */
async function login(phoneLocal, password) {
  await U.tap(['تسجيل الدخول'], { settleMs: 2500 });
  const list = await U.inputs();
  // [0] = phone, [1] = country code chip, [2] = password (varies by layout)
  await U.tapPoint(list[0].x, list[0].y, 700);
  await U.clearFocused();
  await U.type(phoneLocal);
  await U.hideKeyboard();
  const list2 = await U.inputs();
  const pwd = list2[list2.length - 1];
  await U.tapPoint(pwd.x, pwd.y, 700);
  await U.type(password);
  await U.hideKeyboard();
  await tapPrimary('تسجيل الدخول', 7000);
}

module.exports = {
  enterOtp, tapPrimary, tapSelect, pickFromGallery, uploadVia, otpFor, login,
};
