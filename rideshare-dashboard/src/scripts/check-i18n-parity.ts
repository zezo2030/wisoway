import { translations } from "../i18n/translations.ts";

type TranslationRecord = Record<string, string>;

function collectKeys(record: TranslationRecord): Set<string> {
  return new Set(Object.keys(record));
}

function findEmptyValues(
  record: TranslationRecord,
  locale: string,
): string[] {
  return Object.entries(record)
    .filter(([, value]) => value.trim().length === 0)
    .map(([key]) => `${locale}.${key}`);
}

const enKeys = collectKeys(translations.en);
const arKeys = collectKeys(translations.ar);

const onlyEn = [...enKeys].filter((key) => !arKeys.has(key)).sort();
const onlyAr = [...arKeys].filter((key) => !enKeys.has(key)).sort();
const emptyValues = [
  ...findEmptyValues(translations.en, "en"),
  ...findEmptyValues(translations.ar, "ar"),
];

let failed = false;

if (onlyEn.length > 0) {
  failed = true;
  console.error("Keys in en missing from ar:");
  for (const key of onlyEn) {
    console.error(`  - ${key}`);
  }
}

if (onlyAr.length > 0) {
  failed = true;
  console.error("Keys in ar missing from en:");
  for (const key of onlyAr) {
    console.error(`  - ${key}`);
  }
}

if (emptyValues.length > 0) {
  failed = true;
  console.error("Empty translation values:");
  for (const key of emptyValues) {
    console.error(`  - ${key}`);
  }
}

if (failed) {
  process.exit(1);
}

console.log(
  `i18n parity OK: ${enKeys.size} keys matched between en and ar`,
);
