const assert = require('node:assert/strict');
const path = require('node:path');
const root = process.cwd();
const load = p => require(path.join(root,'dist/src',p));
if (!/^wisoway_revenue_verify_/.test(process.env.POSTGRES_DB || '')) throw Error('Verification database required');
const jwt = require(path.join(root,'node_modules/jsonwebtoken'));
const {AppDataSource:db}=load('database/data-source.js');
const E=load('database/entities/index.js');
async function call(route,token,method='GET',body,expected=200) {
  const response=await fetch('http://127.0.0.1:3000/api/v1'+route,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(60000)});
  const json=await response.json();
  assert.equal(response.status,expected,`${method} ${route}: ${JSON.stringify(json)}`);
  return json.data ?? json;
}
async function makeUser(role) {
  const u=await db.getRepository(E.UserEntity).save(db.getRepository(E.UserEntity).create({name:'API isolated verification',role}));
  return {id:u.id,token:jwt.sign({sub:u.id,role},process.env.JWT_ACCESS_SECRET,{expiresIn:300})};
}
(async()=>{
 await db.initialize();
 const admin=await makeUser('admin'),rider=await makeUser('passenger'),driver=await makeUser('driver');
 await call('/promotions/admin',null,'GET',undefined,401);
 await call('/promotions/admin',rider.token,'GET',undefined,403);
 const code='APIVERIFY'+Date.now();
 await call('/promotions/admin',admin.token,'POST',{code,percent:20,tripType:'all',startsAt:new Date(Date.now()-60000).toISOString(),endsAt:new Date(Date.now()+3600000).toISOString(),active:true},201);
 const preview=await call('/promotions/preview',rider.token,'POST',{code,amount:10,tripType:'shared'},201);
 assert.equal(preview.totalAmount,'8.00');
 const trip=await db.getRepository(E.TripEntity).save(db.getRepository(E.TripEntity).create({driverId:driver.id,fromName:'API verification A',toName:'API verification B',fromPoint:{type:'Point',coordinates:[35.9,31.9]},toPoint:{type:'Point',coordinates:[35.91,31.91]},departureTime:new Date(Date.now()+3600000),price:'10.00',currency:'JOD',status:'published',tripType:'scheduled',totalSeats:1,availableSeats:1,seats:[{seatNumber:'0-0',status:'available'}]}));
 const booking=await call('/v2/bookings',rider.token,'POST',{tripId:trip.id,promoCode:code,paymentMethod:'cash',seats:[{seatNumber:'0-0',displayName:'Verification',gender:'male',isMainBooker:true}]},201);
 assert.equal(booking.originalAmount,'10.00'); assert.equal(booking.discountAmount,'2.00'); assert.equal(booking.totalAmount,'8.00'); assert.equal(booking.promoCode,code);
 console.log('SHARED_BOOKING_API_OK');
 const instant=await call('/instant-rides/requests',rider.token,'POST',{from:{name:'Amman verification',latitude:31.9539,longitude:35.9106},to:{name:'Amman verification destination',latitude:31.9601,longitude:35.925},paymentMethod:'cash',promoCode:code},201);
 assert.equal(instant.promoCode,code);
 assert.equal(Math.round(Number(instant.originalAmount)*20),Math.round(Number(instant.discountAmount)*100));
 assert.equal(Math.round(Number(instant.passengerFare)*100),Math.round((Number(instant.originalAmount)-Number(instant.discountAmount))*100));
 console.log('INSTANT_REQUEST_API_OK');
 await call('/promotions/admin/'+code,admin.token,'PATCH',{active:false});
 await call('/promotions/preview',rider.token,'POST',{code,amount:10,tripType:'instant'},400);
 const settings=await call('/admin/platform-settings',admin.token);
 assert.equal(settings.instantCommissionPercent,10); assert.equal(settings.sharedCommissionPercent,10);
 console.log('PROMOTIONS_API_OK: auth, admin campaign create/disable, preview, shared booking, instant request, commission settings');
})().catch(e=>{console.error(e);process.exitCode=1}).finally(async()=>{if(db.isInitialized)await db.destroy()});
