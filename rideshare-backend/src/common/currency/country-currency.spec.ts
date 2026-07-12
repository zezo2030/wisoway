import {
  COUNTRY_CURRENCY,
  DEFAULT_CURRENCY,
  currencyForCountry,
} from './country-currency';

describe('currencyForCountry', () => {
  it('maps known countries to their currency', () => {
    expect(currencyForCountry('JO')).toBe('JOD');
    expect(currencyForCountry('EG')).toBe('EGP');
    expect(currencyForCountry('SA')).toBe('SAR');
    expect(currencyForCountry('AE')).toBe('AED');
    expect(currencyForCountry('QA')).toBe('QAR');
  });

  it('is case-insensitive and trims whitespace', () => {
    expect(currencyForCountry('jo')).toBe('JOD');
    expect(currencyForCountry(' eg ')).toBe('EGP');
  });

  it('falls back to the default for unknown / empty / null / undefined', () => {
    expect(currencyForCountry('XX')).toBe(DEFAULT_CURRENCY);
    expect(currencyForCountry('')).toBe(DEFAULT_CURRENCY);
    expect(currencyForCountry(null)).toBe(DEFAULT_CURRENCY);
    expect(currencyForCountry(undefined)).toBe(DEFAULT_CURRENCY);
  });

  it('uses JOD as the default currency', () => {
    expect(DEFAULT_CURRENCY).toBe('JOD');
    expect(COUNTRY_CURRENCY.JO).toBe('JOD');
  });
});
