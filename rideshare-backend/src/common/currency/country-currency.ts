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
  return knownCurrencyForCountry(countryCode) ?? DEFAULT_CURRENCY;
}

/** Like {@link currencyForCountry}, but null for unknown input instead of the default. */
export function knownCurrencyForCountry(
  countryCode?: string | null,
): string | null {
  const code = countryCode?.trim().toUpperCase();
  if (!code) return null;
  return COUNTRY_CURRENCY[code] ?? null;
}

/**
 * Country whose currency this is, or null. Each currency above belongs to a
 * single country, so this is the exact inverse of {@link COUNTRY_CURRENCY}.
 */
export function countryForCurrency(currency?: string | null): string | null {
  const code = currency?.trim().toUpperCase();
  if (!code) return null;
  return (
    Object.keys(COUNTRY_CURRENCY).find((c) => COUNTRY_CURRENCY[c] === code) ??
    null
  );
}

/** International dialling prefix → ISO alpha-2, for every country above. */
const DIAL_CODE_COUNTRY: Readonly<Record<string, string>> = {
  '962': 'JO',
  '963': 'SY',
  '961': 'LB',
  '970': 'PS',
  '964': 'IQ',
  '966': 'SA',
  '971': 'AE',
  '974': 'QA',
  '965': 'KW',
  '973': 'BH',
  '968': 'OM',
  '967': 'YE',
  '20': 'EG',
  '218': 'LY',
  '249': 'SD',
  '213': 'DZ',
  '212': 'MA',
  '216': 'TN',
  '222': 'MR',
  '1': 'US',
  '44': 'GB',
  '90': 'TR',
};

/**
 * Country of an international phone number (`+966…` or `00966…`), or null
 * when the number is local-format or its prefix is not in the table.
 */
export function countryForPhone(phone?: string | null): string | null {
  const raw = phone?.trim() ?? '';
  if (!raw.startsWith('+') && !raw.startsWith('00')) return null;
  const digits = raw.replace(/\D/g, '').replace(/^00/, '');
  for (const len of [3, 2, 1]) {
    const country = DIAL_CODE_COUNTRY[digits.slice(0, len)];
    if (country) return country;
  }
  return null;
}
