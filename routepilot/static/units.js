(function(root) {
  'use strict';
  const KM_PER_MILE = 1.609344, METERS_PER_FOOT = 0.3048;
  const units = {
    speedLabel: unit => unit === 'imperial' ? 'mph' : 'km/h',
    distanceLabel: unit => unit === 'imperial' ? 'mi' : 'km',
    lateralLabel: unit => unit === 'imperial' ? 'ft' : 'm',
    speedToDisplay: (kmh, unit) => unit === 'imperial' ? kmh / KM_PER_MILE : kmh,
    speedToCanonical: (value, unit) => unit === 'imperial' ? value * KM_PER_MILE : value,
    lateralToDisplay: (meters, unit) => unit === 'imperial' ? meters / METERS_PER_FOOT : meters,
    lateralToCanonical: (value, unit) => unit === 'imperial' ? value * METERS_PER_FOOT : value,
    distanceToDisplay: (meters, unit) => meters / (unit === 'imperial' ? 1609.344 : 1000),
    format: value => String(Math.round(value * 100) / 100),
  };
  root.RouteUnits = units;
  if(typeof module !== 'undefined' && module.exports) module.exports = units;
})(globalThis);
