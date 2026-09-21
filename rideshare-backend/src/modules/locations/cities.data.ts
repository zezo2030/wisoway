import { CityDto } from './dto/cities.dto';

/**
 * Static catalog backing the city-first pickers (`GET /locations/cities`).
 *
 * Driver trips are intercity, so the route step asks for a city before an
 * address — the same shape as inDrive City to City. Cities come from a fixed
 * list rather than the places provider because the set is small, stable and
 * must render instantly and offline; the provider is only used for addresses
 * inside the chosen city.
 *
 * `popular` marks the cities listed first before the user types. Coordinates
 * are the city centre, used to bias address search and to open the map picker.
 * Extend this list (or replace it with a seeded table) when a new country is
 * launched; ids are stable and stored on trips, so never renumber them.
 */
export const CITY_CATALOG: readonly CityDto[] = [
  // --- Jordan (primary market) ---
  {
    id: 'jo-amman',
    nameAr: 'عمّان',
    nameEn: 'Amman',
    countryCode: 'JO',
    lat: 31.9539,
    lng: 35.9106,
    popular: true,
  },
  {
    id: 'jo-zarqa',
    nameAr: 'الزرقاء',
    nameEn: 'Zarqa',
    countryCode: 'JO',
    lat: 32.0728,
    lng: 36.0876,
    popular: true,
  },
  {
    id: 'jo-irbid',
    nameAr: 'إربد',
    nameEn: 'Irbid',
    countryCode: 'JO',
    lat: 32.5556,
    lng: 35.85,
    popular: true,
  },
  {
    id: 'jo-aqaba',
    nameAr: 'العقبة',
    nameEn: 'Aqaba',
    countryCode: 'JO',
    lat: 29.5321,
    lng: 35.0063,
    popular: true,
  },
  {
    id: 'jo-salt',
    nameAr: 'السلط',
    nameEn: 'Salt',
    countryCode: 'JO',
    lat: 32.0392,
    lng: 35.7272,
    popular: true,
  },
  {
    id: 'jo-madaba',
    nameAr: 'مادبا',
    nameEn: 'Madaba',
    countryCode: 'JO',
    lat: 31.7156,
    lng: 35.7939,
    popular: true,
  },
  {
    id: 'jo-mafraq',
    nameAr: 'المفرق',
    nameEn: 'Mafraq',
    countryCode: 'JO',
    lat: 32.3434,
    lng: 36.208,
    popular: false,
  },
  {
    id: 'jo-jerash',
    nameAr: 'جرش',
    nameEn: 'Jerash',
    countryCode: 'JO',
    lat: 32.2808,
    lng: 35.8991,
    popular: false,
  },
  {
    id: 'jo-ajloun',
    nameAr: 'عجلون',
    nameEn: 'Ajloun',
    countryCode: 'JO',
    lat: 32.3326,
    lng: 35.7517,
    popular: false,
  },
  {
    id: 'jo-karak',
    nameAr: 'الكرك',
    nameEn: 'Karak',
    countryCode: 'JO',
    lat: 31.1854,
    lng: 35.7047,
    popular: false,
  },
  {
    id: 'jo-tafilah',
    nameAr: 'الطفيلة',
    nameEn: 'Tafilah',
    countryCode: 'JO',
    lat: 30.8375,
    lng: 35.6042,
    popular: false,
  },
  {
    id: 'jo-maan',
    nameAr: 'معان',
    nameEn: "Ma'an",
    countryCode: 'JO',
    lat: 30.1962,
    lng: 35.7341,
    popular: false,
  },
  {
    id: 'jo-ramtha',
    nameAr: 'الرمثا',
    nameEn: 'Ramtha',
    countryCode: 'JO',
    lat: 32.5619,
    lng: 36.0086,
    popular: false,
  },
  {
    id: 'jo-petra',
    nameAr: 'وادي موسى - البتراء',
    nameEn: 'Wadi Musa - Petra',
    countryCode: 'JO',
    lat: 30.3221,
    lng: 35.4784,
    popular: false,
  },
  {
    id: 'jo-dead-sea',
    nameAr: 'البحر الميت',
    nameEn: 'Dead Sea',
    countryCode: 'JO',
    lat: 31.5,
    lng: 35.5667,
    popular: false,
  },
  {
    id: 'jo-fuheis',
    nameAr: 'الفحيص',
    nameEn: 'Fuheis',
    countryCode: 'JO',
    lat: 32.0111,
    lng: 35.7742,
    popular: false,
  },
  {
    id: 'jo-jubaiha',
    nameAr: 'صويلح',
    nameEn: 'Sweileh',
    countryCode: 'JO',
    lat: 32.0264,
    lng: 35.8339,
    popular: false,
  },
  {
    id: 'jo-russeifa',
    nameAr: 'الرصيفة',
    nameEn: 'Russeifa',
    countryCode: 'JO',
    lat: 32.0178,
    lng: 36.0464,
    popular: false,
  },
];

/** Fast id → city lookup for validating and resolving `cityId` on requests. */
export const CITY_BY_ID: ReadonlyMap<string, CityDto> = new Map(
  CITY_CATALOG.map((city) => [city.id, city]),
);
