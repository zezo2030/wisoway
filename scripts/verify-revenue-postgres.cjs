// Run inside the candidate backend image against a dedicated, empty verification DB.
// Never starts Nest schedulers, queues, notifications or banking integrations.
const assert = require('node:assert/strict');
const path = require('node:path');
const root = process.cwd();
const load = p => require(path.join(root, 'dist/src', p));
if (!/^wisoway_revenue_verify_/.test(process.env.POSTGRES_DB || '')) {
  throw new Error('Refusing to run financial fixtures outside the dedicated verification database');
}
const { AppDataSource: db } = load('database/data-source.js');
const E = load('database/entities/index.js');
const { WalletService } = load('modules/wallet/wallet.service.js');
const { PlatformSettingsService } = load('modules/platform-settings/platform-settings.service.js');
const { DriverWalletPolicyService } = load('modules/wallet/driver-wallet-policy.service.js');
const { pricePromotion } = load('modules/promotions/promotions.module.js');
let assertions = 0;
const eq = (actual, expected) => { assert.equal(actual, expected); assertions++; };
const repo = entity => db.getRepository(entity);
async function user(role) { return repo(E.UserEntity).save(repo(E.UserEntity).create({ name: 'Isolated revenue verification', role })); }
async function balance(id, type, currency='JOD') {
  const rows = await db.query('SELECT balance FROM wallet_accounts WHERE "userId" IS NOT DISTINCT FROM $1::uuid AND "accountType"=$2 AND currency=$3', [id,type,currency]);
  return Number(rows[0]?.balance ?? 0);
}
async function fixture(type, method, percent) {
  const driver = await user('driver'), rider = await user('passenger');
  await wallet.grantDriverWelcome(driver.id,'JOD');
  const promo = await pricePromotion(db.manager, percent ? `VERIFY${percent}` : undefined, 10, type === 'instant' ? 'instant':'shared');
  const trip = await repo(E.TripEntity).save(repo(E.TripEntity).create({
    driverId:driver.id, fromName:'Verification A',toName:'Verification B',
    fromPoint:{type:'Point',coordinates:[35.9,31.9]}, toPoint:{type:'Point',coordinates:[35.91,31.91]},
    departureTime:new Date(),tripCompletedAt:new Date(),price:'10.00',currency:'JOD',
    tripType:type, status:'completed',totalSeats:2,availableSeats:0,
  }));
  const booking = await repo(E.BookingEntity).save(repo(E.BookingEntity).create({
    tripId:trip.id,userId:rider.id,status:'completed',seatCount:2,seatPriceAtBooking:'5.00',
    paymentMethod:method,paymentStatus:'pending', ...promo,
  }));
  for(let i=0;i<2;i++) await repo(E.BookingSeatEntity).save(repo(E.BookingSeatEntity).create({
    bookingId:booking.id,seatNumber:`${i}-0`,displayName:'Verification rider',gender:'male',isMainBooker:i===0,passengerSelfConfirmedAt:new Date(),
  }));
  if(method==='wallet') await wallet.creditPostedTopup({userId:rider.id,accountType:'rider',currency:'JOD',amount:20,idempotencyKey:`verify-rider:${rider.id}`});
  return { driver,rider,trip,booking,promo };
}
let wallet;
(async()=> {
  await db.initialize();
  const applied=await db.runMigrations({transaction:'each'});
  console.log('MIGRATIONS_APPLIED', applied.map(m=>m.name).join(','));
  eq((await db.runMigrations({transaction:'each'})).length,0);
  const settings = new PlatformSettingsService(repo(E.PlatformSettingEntity));
  const policy = new DriverWalletPolicyService(repo(E.PlatformSettingEntity));
  wallet = new WalletService(db,repo(E.WalletAccountEntity),repo(E.WalletTransactionEntity),repo(E.PayoutRequestEntity),repo(E.TripEntity),repo(E.UserEntity),{},settings,policy,{create:async()=>undefined});
  for(const percent of [5,20,100]) await db.query(`INSERT INTO promotion_campaigns(code,percent,"tripType","startsAt","endsAt",active) VALUES ($1,$2,'all',now()-interval '1 day',now()+interval '1 day',true) ON CONFLICT (code) DO UPDATE SET active=true`, [`VERIFY${percent}`,percent]);
  await settings.update({instantCommissionPercent:10,sharedCommissionPercent:10});
  for(const type of ['instant','scheduled']) for(const method of ['cash','wallet','cliq']) for(const percent of [0,5,20,100]) {
    const f=await fixture(type,method,percent);
    const before=await balance(null,'system');
    // These calls use two real PostgreSQL transactions and row locks.
    await Promise.all([wallet.chargeCompletedTripCommission(f.trip.id),wallet.chargeCompletedTripCommission(f.trip.id)]);
    const discount=10*percent/100, payable=10-discount;
    if(method!=='cash' || payable===0) {
      await wallet.settleCollectedFare(f.booking.id,method);
      await wallet.settleCollectedFare(f.booking.id,method);
    }
    eq(await balance(f.driver.id,'driver'), method==='cash' ? 5-1+discount : 14);
    eq(Math.round(((await balance(null,'system'))-before)*100),Math.round((1-discount)*100));
    if(method==='wallet') eq(await balance(f.rider.id,'rider'),20-payable);
    eq(await repo(E.WalletTransactionEntity).count({where:{idempotencyKey:`commission:${f.trip.id}`}}),1);
    console.log('PASS', type,method,`discount=${percent}%`);
  }
  // A shared booking with one self-confirmed seat only owes half the commission.
  const partial=await fixture('scheduled','cash',0);
  await db.query('UPDATE booking_seats SET "passengerSelfConfirmedAt"=NULL, "presenceConfirmedAt"=now() WHERE "bookingId"=$1 AND "isMainBooker"=false',[partial.booking.id]);
  await wallet.chargeCompletedTripCommission(partial.trip.id);
  eq(await balance(partial.driver.id,'driver'),4.5);
  await settings.update({instantCommissionPercent:15,sharedCommissionPercent:5});
  for(const [type,expected] of [['instant',3.5],['scheduled',4.5]]) {
    const f=await fixture(type,'cash',0); await wallet.chargeCompletedTripCommission(f.trip.id); eq(await balance(f.driver.id,'driver'),expected);
  }
  await settings.update({instantCommissionPercent:10,sharedCommissionPercent:10});
  const zero=await fixture('instant','cash',0);
  await db.query('UPDATE wallet_accounts SET balance=1 WHERE "userId"=$1',[zero.driver.id]);
  await wallet.chargeCompletedTripCommission(zero.trip.id);
  await assert.rejects(()=>wallet.assertNonNegativeDriverBalance(zero.driver.id,'JOD')); assertions++;
  await wallet.creditPostedTopup({userId:zero.driver.id,accountType:'driver',amount:5,currency:'JOD',idempotencyKey:`verify-recharge:${zero.driver.id}`});
  await wallet.assertNonNegativeDriverBalance(zero.driver.id,'JOD'); assertions++;
  const payoutDriver=await user('driver'), admin=await user('admin');
  await wallet.creditPostedTopup({userId:payoutDriver.id,accountType:'driver',amount:50,currency:'JOD',idempotencyKey:`verify-payout:${payoutDriver.id}`});
  const payout=await wallet.createPayoutRequest(payoutDriver.id,{amount:45,currency:'JOD',bankAccountRef:'isolated-verification'});
  await assert.rejects(()=>wallet.createPayoutRequest(payoutDriver.id,{amount:1,currency:'JOD',bankAccountRef:'isolated-verification'})); assertions++;
  await wallet.processPayout(payout.id,admin.id,'paid');
  await wallet.processPayout(payout.id,admin.id,'paid');
  eq(await balance(payoutDriver.id,'driver'),5);
  const welcome=await user('driver');
  await wallet.grantDriverWelcome(welcome.id,'SAR'); await wallet.grantDriverWelcome(welcome.id,'SAR');
  eq(await balance(welcome.id,'driver','SAR'),25);
  await db.query("UPDATE promotion_campaigns SET active=false WHERE code='VERIFY20'");
  await assert.rejects(()=>pricePromotion(db.manager,'VERIFY20',10,'instant')); assertions++;
  console.log('VERIFICATION_OK',JSON.stringify({assertions,financialScenarios:24,database:process.env.POSTGRES_DB,bankCalls:0,productionUserChanges:0}));
})().catch(error=> { console.error(error); process.exitCode=1; }).finally(async()=> { if(db.isInitialized) await db.destroy(); });
