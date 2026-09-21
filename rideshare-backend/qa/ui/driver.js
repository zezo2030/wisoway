/* Minimal UI driver for the Flutter app on an Android emulator.
 *
 * Flutter publishes its semantics tree to Android accessibility, so
 * `uiautomator dump` gives every widget's label in `content-desc` plus its
 * on-screen `bounds`. That lets us tap elements by label instead of guessing
 * pixel coordinates off screenshots.
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ADB =
  process.env.ADB ||
  'C:/Users/zezos/AppData/Local/Android/Sdk/platform-tools/adb.exe';
const SERIAL = process.env.ANDROID_SERIAL || 'emulator-5554';
const APP_PKG = process.env.QA_APP_PKG || 'com.abdelaziz.visionway';
const OUT = process.env.QA_UI_OUT || path.join(__dirname, '.tmp');
if (!fs.existsSync(OUT)) fs.mkdirSync(OUT, { recursive: true });

function adb(args, opts = {}) {
  return execFileSync(ADB, ['-s', SERIAL, ...args], {
    encoding: opts.encoding === null ? 'buffer' : 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    ...opts,
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Parse `bounds="[x1,y1][x2,y2]"` into a center point. */
function centerOf(bounds) {
  const m = /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/.exec(bounds);
  if (!m) return null;
  const [, x1, y1, x2, y2] = m.map(Number);
  return { x: Math.round((x1 + x2) / 2), y: Math.round((y1 + y2) / 2), x1, y1, x2, y2 };
}

/** Dump the current screen's semantics tree as a list of nodes. */
async function dump() {
  // uiautomator occasionally races with an in-flight frame; retry briefly.
  let xml = '';
  for (let i = 0; i < 4; i++) {
    try {
      adb(['shell', 'uiautomator', 'dump', '/sdcard/ui.xml'], { stdio: 'pipe' });
      xml = adb(['exec-out', 'cat', '/sdcard/ui.xml']);
      if (xml && xml.includes('<node')) break;
    } catch {
      /* retry */
    }
    await sleep(700);
  }
  const nodes = [];
  const re = /<node([^>]*)\/?>/g;
  let m;
  while ((m = re.exec(xml))) {
    const attrs = m[1];
    const get = (k) => {
      const a = new RegExp(`${k}="([^"]*)"`).exec(attrs);
      return a ? a[1] : '';
    };
    const desc = decode(get('content-desc'));
    const pkg = get('package');
    const text = decode(get('text'));
    const bounds = get('bounds');
    const c = centerOf(bounds);
    if (!c) continue;
    nodes.push({
      desc,
      text,
      label: desc || text,
      clickable: get('clickable') === 'true',
      pkg,
      bounds,
      ...c,
    });
  }
  return nodes;
}

function decode(s) {
  return s
    .replace(/&#10;/g, '\n')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

/** All labels on screen, newline-joined — handy for assertions and logging. */
async function screenText() {
  const nodes = await dump();
  return nodes.map((n) => n.label).filter(Boolean).join('\n');
}

/** Find the first node whose label contains every given needle. */
async function find(...needles) {
  const nodes = await dump();
  return (
    nodes.find((n) => needles.every((s) => n.label.includes(s))) || null
  );
}

/** Wait until a node matching the needles appears. */
async function waitFor(needles, timeoutMs = 20000, label = '') {
  const list = Array.isArray(needles) ? needles : [needles];
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const n = await find(...list);
    if (n) return n;
    await sleep(900);
  }
  throw new Error(
    `timed out waiting for ${label || list.join(' + ')} after ${timeoutMs}ms`,
  );
}

/**
 * Locate a text input by its visible label.
 *
 * Flutter exposes the label and the field as separate semantics nodes: the
 * field itself carries no text, so it can only be identified as the nearest
 * clickable unlabelled node starting at or below its label.
 */
async function field(labelNeedle, { index = 0 } = {}) {
  const nodes = await dump();
  const labels = nodes.filter((n) => n.label.includes(labelNeedle));
  if (!labels.length) throw new Error(`no label matching "${labelNeedle}"`);
  const anchor = labels[Math.min(index, labels.length - 1)];
  const candidates = nodes
    .filter(
      (n) =>
        n.clickable &&
        !n.label.trim() &&
        n.y2 - n.y1 < 400 &&
        n.y1 >= anchor.y1 - 10,
    )
    .sort((a, b) => a.y1 - b.y1 || a.x1 - b.x1);
  if (!candidates.length) {
    throw new Error(`no input found under "${labelNeedle}"`);
  }
  return candidates[0];
}

/** Tap a labelled input and type into it. */
async function fillField(labelNeedle, value, opts = {}) {
  const f = await field(labelNeedle, opts);
  await tapPoint(f.x, f.y, 800);
  await type(value);
  await hideKeyboard();
  return f;
}

/**
 * Every text input currently on screen, in visual order.
 *
 * Labels and inputs are separate nodes and a label may sit above *or* below its
 * field, so position-relative lookup is unreliable on these forms. Inputs are
 * instead recognised by shape: clickable, roughly one row tall, and wide.
 */
async function inputs() {
  const nodes = await dump();
  return nodes
    .filter(
      (n) =>
        n.clickable &&
        // Exclude the IME window: with the keyboard up its keys are dumped
        // alongside the app's widgets and look just like inputs.
        n.pkg === APP_PKG &&
        n.y2 - n.y1 >= 50 &&
        n.y2 - n.y1 <= 170 &&
        n.x2 - n.x1 >= 250 &&
        !/تابع|متابعة|التالي|رجوع|اللغة/.test(n.label),
    )
    .sort((a, b) => a.y1 - b.y1 || a.x1 - b.x1);
}

/**
 * Fill the n-th input on screen. The tree is re-read for every field because
 * the soft keyboard reflows the form, which invalidates earlier coordinates.
 */
async function fillInput(index, value) {
  const list = await inputs();
  const f = list[index];
  if (!f) throw new Error(`no input at index ${index} (found ${list.length})`);
  await tapPoint(f.x, f.y, 800);
  // Only clear when the field actually holds something: the delete burst costs
  // a second and can drop focus on an already-empty field.
  if (f.label && f.label.trim()) await clearFocused();
  await type(value);
  await hideKeyboard();
  await sleep(500);
  return f;
}

/** Empty the focused text field (select-all then delete). */
async function clearFocused() {
  adb(['shell', 'input', 'keyevent', '123']); // MOVE_END
  for (let i = 0; i < 3; i++) {
    adb([
      'shell',
      'input',
      'keyevent',
      ...Array(10).fill('67'), // DEL
    ]);
  }
  await sleep(300);
}

async function tapPoint(x, y, settleMs = 1200) {
  adb(['shell', 'input', 'tap', String(x), String(y)]);
  await sleep(settleMs);
}

/** Tap the first element whose label matches; throws when absent. */
async function tap(needles, { timeoutMs = 20000, settleMs = 1400 } = {}) {
  const node = await waitFor(needles, timeoutMs);
  await tapPoint(node.x, node.y, settleMs);
  return node;
}

/** Tap only if present; returns whether it was there. */
async function tapIfPresent(needles, settleMs = 1200) {
  const list = Array.isArray(needles) ? needles : [needles];
  const node = await find(...list);
  if (!node) return false;
  await tapPoint(node.x, node.y, settleMs);
  return true;
}

async function type(text, settleMs = 700) {
  // `input text` needs shell-safe escaping and uses %s for spaces.
  const escaped = String(text)
    .replace(/(["'\\$`&|;<>()])/g, '\\$1')
    .replace(/ /g, '%s');
  adb(['shell', 'input', 'text', escaped]);
  await sleep(settleMs);
}

async function key(code, settleMs = 700) {
  adb(['shell', 'input', 'keyevent', String(code)]);
  await sleep(settleMs);
}
const back = (ms) => key(4, ms ?? 1400);

/** True while the soft keyboard is on screen (it reflows the whole form). */
function keyboardShown() {
  try {
    const out = adb(['shell', 'dumpsys', 'input_method']);
    return /mInputShown=true/.test(out);
  } catch {
    return false;
  }
}

/** Package of the activity currently in the foreground. */
function foregroundPackage() {
  try {
    const out = adb(['shell', 'dumpsys', 'window']);
    const m = /mCurrentFocus=[^\s]*\s+[^\s]*\s+([\w.]+)\//.exec(out) ||
      /mCurrentFocus=.*?\{[^}]*\s([\w.]+)\//.exec(out);
    return m ? m[1] : '';
  } catch {
    return '';
  }
}

/**
 * Dismiss the soft keyboard.
 *
 * ESC does not close the IME on this image, so BACK is needed — but BACK with
 * no keyboard up navigates, and enough of them send the app to the launcher
 * (which resets an in-progress registration form). So: press at most once,
 * only while the IME really is up, and never once the app has lost focus.
 */
/**
 * Dismiss the soft keyboard with the IME action key (ENTER).
 *
 * ESC is ignored by this IME, and BACK injected over adb reaches the activity
 * rather than the IME, so it pops the route and destroys the half-filled form.
 * ENTER fires the field's IME action, which unfocuses and closes the keyboard
 * while leaving the screen and its state alone.
 */
async function hideKeyboard() {
  if (!keyboardShown()) return;
  await key(66, 1000);
  await sleep(500);
}

async function swipe(x1, y1, x2, y2, ms = 300, settleMs = 1000) {
  adb(['shell', 'input', 'swipe', ...[x1, y1, x2, y2, ms].map(String)]);
  await sleep(settleMs);
}
const scrollDown = (settle) => swipe(540, 1700, 540, 700, 400, settle);
const scrollUp = (settle) => swipe(540, 700, 540, 1700, 400, settle);

async function screenshot(name) {
  const buf = adb(['exec-out', 'screencap', '-p'], { encoding: null });
  const file = path.join(OUT, `${name}.png`);
  fs.writeFileSync(file, buf);
  return file;
}

const APP_PERMISSIONS = [
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.CAMERA',
  'android.permission.READ_MEDIA_IMAGES',
];

/**
 * Wipe app data and relaunch.
 *
 * A plain restart is not a clean slate: the app deliberately persists an
 * in-progress driver registration (and the signed-in session), so a cold start
 * drops you back into step 2 of the wizard. `pm clear` also drops the runtime
 * permission grants, so they are re-applied here.
 */
async function resetApp(pkg = 'com.abdelaziz.visionway') {
  adb(['shell', 'pm', 'clear', pkg]);
  await sleep(1500);
  for (const p of APP_PERMISSIONS) {
    try {
      adb(['shell', 'pm', 'grant', pkg, p]);
    } catch {
      /* not all permissions exist on every image */
    }
  }
  adb(['shell', 'am', 'start', '-n', `${pkg}/.MainActivity`]);
  await sleep(9000);
}

async function restartApp(pkg = 'com.abdelaziz.visionway') {
  adb(['shell', 'am', 'force-stop', pkg]);
  await sleep(1500);
  // `monkey` intermittently leaves the launcher in front; an explicit start of
  // the main activity is deterministic.
  adb(['shell', 'am', 'start', '-n', `${pkg}/.MainActivity`]);
  await sleep(9000);
}

module.exports = {
  adb, sleep, dump, find, waitFor, tap, tapIfPresent, tapPoint, type, key,
  field, fillField, inputs, fillInput, clearFocused, keyboardShown, foregroundPackage,
  back, hideKeyboard, swipe, scrollDown, scrollUp, screenshot, screenText,
  restartApp, resetApp, OUT, APP_PKG,
};
