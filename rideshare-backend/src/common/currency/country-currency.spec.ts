import {
  COUNTRY_CURRENCY,
  DEFAULT_CURRENCY,
  countryForCurrency,
  countryForPhone,
  currencyForCountry,
  knownCurrencyForCountry,
} from './country-currency';

describe('knownCurrencyForCountry', () => {
  it('returns null instead of the default for unknown input', () => {
    expect(knownCurrencyForCountry('SA')).toBe('SAR');
    expect(knownCurrencyForCountry('XX')).toBeNull();
    expect(knownCurrencyForCountry(undefined)).toBeNull();
  });
});

describe('countryForCurrency', () => {
  it('inverts the country → currency table', () => {
    expect(countryForCurrency('SAR')).toBe('SA');
    expect(countryForCurrency('jod')).toBe('JO');
    expect(countryForCurrency('EUR')).toBeNull();
    expect(countryForCurrency(null)).toBeNull();
  });

  it('has one country per currency', () => {
    const currencies = Object.values(COUNTRY_CURRENCY);
    expect(new Set(currencies).size).toBe(currencies.length);
  });
});

describe('countryForPhone', () => {
  it('maps international numbers by their dialling prefix', () => {
    expect(countryForPhone('+966501234567')).toBe('SA');
    expect(countryForPhone('+962791234567')).toBe('JO');
    expect(countryForPhone('00971501234567')).toBe('AE');
    expect(countryForPhone('+201001234567')).toBe('EG');
    expect(countryForPhone('+212612345678')).toBe('MA');
  });

  it('returns null for local-format, unknown or missing numbers', () => {
    expect(countryForPhone('0791234567')).toBeNull();
    expect(countryForPhone('+86123456789')).toBeNull();
    expect(countryForPhone(null)).toBeNull();
  });
});

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
