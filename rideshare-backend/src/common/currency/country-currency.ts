/**
 * Country (ISO 3166-1 alpha-2) → ISO 4217 currency code.
 *
 * Used to derive a trip's currency from the country of its departure point,
 * so fares are always shown in the local currency of where the ride starts.
 * Covers the Arab region (the app's primary markets) plus a few common
 * fallbacks. Unknown countries fall back to {@link DEFAULT_CURRENCY}.
 */
export const DEFAULT_CURRENCY = 'JOD';

export const COUNTRY_CURRENCY: Readonly<Record<string, string>> = {
  // Levant
  JO: 'JOD',
  SY: 'SYP',
  LB: 'LBP',
  PS: 'ILS',
  IQ: 'IQD',
  // Gulf
  SA: 'SAR',
  AE: 'AED',
  QA: 'QAR',
  KW: 'KWD',
  BH: 'BHD',
  OM: 'OMR',
  YE: 'YER',
  // North Africa
  EG: 'EGP',
  LY: 'LYD',
  SD: 'SDG',
  DZ: 'DZD',
  MA: 'MAD',
  TN: 'TND',
  MR: 'MRU',
  // Common non-regional fallbacks
  US: 'USD',
  GB: 'GBP',
  TR: 'TRY',
};

/**
 * Resolve the currency for a country code. Accepts ISO alpha-2 codes in any
 * case; returns {@link DEFAULT_CURRENCY} for null/unknown input.
 */
export function currencyForCountry(countryCode?: string | null): string {
  const code = countryCode?.trim().toUpperCase();
  if (!code) return DEFAULT_CURRENCY;
  return COUNTRY_CURRENCY[code] ?? DEFAULT_CURRENCY;
}
