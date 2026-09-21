/* Poll the driver screen and accept the first instant offer that appears. */
const U = require('./driver');
(async () => {
  const deadline = Date.now() + 240000;
  while (Date.now() < deadline) {
    const n = await U.dump();
    const b = n.find((x) => x.clickable && x.label.includes('قبول الرحلة'));
    if (b) {
      await U.tapPoint(b.x, b.y, 6000);
      console.log('ACCEPTED');
      console.log((await U.screenText()).slice(0, 800));
      return;
    }
    await U.sleep(500);
  }
  console.log('no offer appeared');
})();
