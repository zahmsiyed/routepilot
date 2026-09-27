const test = require('node:test');
const assert = require('node:assert/strict');
const U = require('../routepilot/static/units.js');
test('known imperial conversions and labels', () => {
  assert.equal(U.speedToDisplay(1.609344, 'imperial'), 1);
  assert.equal(U.speedToCanonical(60, 'imperial'), 96.56064);
  assert.equal(U.lateralToDisplay(.3048, 'imperial'), 1);
  assert.equal(U.lateralToCanonical(1, 'imperial'), .3048);
  assert.equal(U.distanceToDisplay(1609.344, 'imperial'), 1);
  assert.equal(U.speedLabel('imperial'), 'mph');
  assert.equal(U.distanceLabel('imperial'), 'mi');
  assert.equal(U.lateralLabel('imperial'), 'ft');
});
test('unit conversion round trips retain the same canonical settings', () => {
  for (const unit of ['metric', 'imperial']) {
    for (const speed of [.1, 10, 100, 250]) assert.ok(Math.abs(U.speedToCanonical(U.speedToDisplay(speed,unit),unit)-speed) < 1e-12);
    for (const offset of [0, .75, 2]) assert.ok(Math.abs(U.lateralToCanonical(U.lateralToDisplay(offset,unit),unit)-offset) < 1e-12);
  }
  assert.equal(U.format(U.speedToDisplay(10, 'imperial')), '6.21');
  assert.equal(U.format(U.lateralToDisplay(.75, 'imperial')), '2.46');
  assert.equal(U.distanceToDisplay(2000, 'metric'), 2);
});
