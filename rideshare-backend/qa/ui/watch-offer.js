/* Foreground the driver app repeatedly so it refetches /offers/pending, then
   accept. Needed locally because offers normally arrive by FCM push, which
   cannot be delivered to these emulators. */
const U = require('./driver');
(async () => {
  const deadline = Date.now() + 120000;
  while (Date.now() < deadline) {
    U.adb(['shell', 'am', 'start', '-n', 'com.abdelaziz.visionway/.MainActivity']);
    await U.sleep(1200);
    const n = await U.dump();
    const b = n.find((x) => x.clickable && x.label.includes('قبول الرحلة'));
    if (b) {
      await U.tapPoint(b.x, b.y, 6000);
      console.log('ACCEPTED');
      console.log((await U.screenText()).slice(0, 700));
      return;
    }
  }
  console.log('no offer card surfaced');
})();
