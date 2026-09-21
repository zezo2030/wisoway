/* UI QA — full driver sign-up through the app (device B).
 *
 *   welcome → account type → basics → OTP → documents → vehicle → submit
 */
const U = require('./driver');
const F = require('./flows');
const L = require('../lib');
const fs = require('fs');

const PHONE_LOCAL = '79' + String(Date.now()).slice(-7);
const PHONE = '+962' + PHONE_LOCAL;
const NAME = 'Omar UI Driver';
const PASSWORD = 'Driver@12345';

async function main() {
  L.setSection('Driver sign-up — start');
  await U.resetApp();
  await U.tap(['إنشاء حساب جديد'], { settleMs: 2500 });
  const typeScreen = await U.screenText();
  if (typeScreen.includes('اختر نوع الحساب')) L.pass('account-type chooser shown');
  else L.fail('account-type chooser shown', typeScreen.slice(0, 120));

  await U.tap(['سائق', 'أنشئ رحلات واستقبل الركاب'], { settleMs: 2500 });
  const step1 = await U.screenText();
  if (step1.includes('المعلومات الأساسية')) L.pass('driver wizard step 1 shown');
  else L.fail('driver wizard step 1 shown', step1.slice(0, 120));

  L.setSection('Step 1 — basics');
  await U.fillInput(0, NAME);
  await U.fillInput(1, PHONE_LOCAL);
  await U.fillInput(3, PASSWORD);
  await U.fillInput(4, PASSWORD);
  await U.tap(['ذكر']);
  const filled = await U.inputs();
  if (filled[0].label === NAME && filled[1].label === PHONE_LOCAL) {
    L.pass('step 1 fields accept input', `${NAME} / ${PHONE_LOCAL}`);
  } else {
    L.fail('step 1 fields accept input', JSON.stringify(filled.map((f) => f.label)));
  }
  await F.tapPrimary('متابعة', 6000);

  L.setSection('Step 1 — phone verification (OTP)');
  const otpScreen = await U.screenText();
  if (otpScreen.includes('التحقق من الرمز')) L.pass('OTP screen reached');
  else L.fail('OTP screen reached', otpScreen.slice(0, 150));

  const code = await F.otpFor(PHONE);
  L.pass('backend issued an OTP', code);
  await F.enterOtp(code);
  // The screen submits itself once the sixth digit lands, so only press the
  // button when it is still there.
  const stillOnOtp = await U.screenText();
  if (stillOnOtp.includes('التحقق من الرمز')) {
    await F.tapPrimary('تحقق', 7000);
  } else {
    L.pass('OTP auto-submits when the last digit is entered');
  }

  const afterOtp = await U.screenText();
  if (afterOtp.includes('الصورة الشخصية')) {
    L.pass('OTP accepted — documents step reached');
  } else {
    L.fail('OTP accepted — documents step reached', afterOtp.slice(0, 200));
    L.summary(); await L.closeDb(); process.exit(1);
  }

  L.setSection('Step 2 — identity & documents');
  await F.uploadVia('صورة الملف الشخصي');
  const afterPhoto = await U.dump();
  const hasPhoto = afterPhoto.some((n) => n.label.includes('صورة الملف الشخصي'));
  if (hasPhoto) L.pass('profile photo picker accepted a gallery image');

  await F.tapSelect('نوع المركبة', 'سيارة عادية');
  L.pass('vehicle-type picker opens');
  await U.tap(['سيارة عادية'], { settleMs: 2000 });
  const afterType = await U.screenText();
  if (afterType.includes('سيارة عادية')) L.pass('vehicle type selected', 'سيارة عادية');
  else L.fail('vehicle type selected', afterType.slice(0, 150));

  // Plate and model are the only editable inputs on this step; the vehicle
  // type above them is read-only and is not reported as an input.
  await U.fillInput(0, 'UI4477');
  await U.fillInput(1, 'Kia Cerato 2021');
  const vals = (await U.inputs()).map((f) => f.label);
  if (vals[0] === 'UI4477' && vals[1] === 'Kia Cerato 2021') {
    L.pass('plate and model accepted', vals.join(' / '));
  } else {
    L.fail('plate and model accepted', JSON.stringify(vals));
  }

  const seatsText = await U.screenText();
  if (/عدد المقاعد/.test(seatsText) && !/اختر نوع المركبة أولًا/.test(seatsText)) {
    L.pass('seat count derived from the vehicle type');
  } else {
    L.fail('seat count derived from the vehicle type', 'still prompting for a type');
  }

  await F.uploadVia('رفع رخصة القيادة');
  L.pass('driver licence uploaded');
  await F.tapPrimary('متابعة', 4000);

  L.setSection('Step 3 — vehicle documents');
  const step3 = await U.screenText();
  if (step3.includes('معلومات السيارة') && !step3.includes('الصورة الشخصية')) {
    L.pass('step 3 reached');
  } else {
    L.fail('step 3 reached', step3.replace(/\n/g, ' | ').slice(0, 300));
  }

  for (const [tile, what] of [
    ['رفع الاستمارة', 'vehicle registration'],
    ['رفع التأمين', 'insurance'],
    ['رفع صورة السيارة', 'car photo'],
  ]) {
    const node = await U.find(tile);
    if (!node) {
      const all = await U.screenText();
      L.fail(`${what} upload tile present`, all.replace(/\n/g, ' | ').slice(0, 300));
      continue;
    }
    await F.uploadVia(tile);
    L.pass(`${what} uploaded`);
  }

  L.setSection('Submit registration');
  await F.tapPrimary('إكمال', 12000);
  await U.sleep(6000);
  const done = await U.screenText();
  console.log('   after submit:', done.replace(/\n/g, ' | ').slice(0, 300));

  const row = await L.sql(
    'SELECT id, name, role, "isDriverApproved" FROM users WHERE "phoneNumber" = $1',
    [PHONE],
  );
  if (row.length) {
    L.pass('driver account created in the backend', `${row[0].name} / ${row[0].role}`);
    if (row[0].isDriverApproved === false) L.pass('new driver starts unapproved');
    else L.fail('new driver starts unapproved', String(row[0].isDriverApproved));
    const veh = await L.sql('SELECT "plateNumber", model, seats FROM vehicles WHERE "driverId" = $1', [row[0].id]);
    if (veh.length) L.pass('vehicle created with the driver', JSON.stringify(veh[0]));
    else L.fail('vehicle created with the driver', 'no vehicle row');
  } else {
    L.fail('driver account created in the backend', `no user row for ${PHONE}`);
  }

  if (/قيد المراجعة|بانتظار|مراجعة|pending/i.test(done)) {
    L.pass('app shows the pending-approval screen');
  }

  fs.writeFileSync(
    __dirname + '/.driver-account.json',
    JSON.stringify({ phone: PHONE, phoneLocal: PHONE_LOCAL, name: NAME, password: PASSWORD }, null, 2),
  );

  const failures = L.summary();
  await L.closeDb();
  process.exit(failures ? 1 : 0);
}

main().catch(async (e) => {
  console.error('UI FLOW ERROR:', e.message);
  try { console.log('screen:', (await U.screenText()).slice(0, 400)); } catch {}
  L.summary();
  await L.closeDb();
  process.exit(2);
});
