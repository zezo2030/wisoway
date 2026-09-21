# Contract: Location search (backend proxy over the places provider)

Keeps the provider credentials server-side (constitution IV). Backs the app's
single place-search path: the full-screen route search, its map-pin picker and
the city-first pickers.

The provider is an internal choice behind these routes. Today it is Photon
(OpenStreetMap); `placeId` values are opaque and must never be parsed by the
client. The `osm:` prefix in current ids is an implementation detail.

## GET /locations/autocomplete

Returns ranked place suggestions for a partial query.

**Auth**: JWT (any authenticated user).

**Query params**:
| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `q` | string | yes | 2–200 chars after trimming; shorter is rejected as `400` |
| `lang` | `ar` \| `en` | no | defaults to `ar`; the app sends its own language, not the device's |
| `sessionToken` | string | no | one per field per selection; generated when omitted and echoed back |
| `lat`,`lng` | number | no | search context; **must be sent as a pair** — a lone value is ignored |
| `cityId` | string | no | id from `GET /locations/cities`; biases and re-ranks results toward that city |

**200 response**:
```json
{
  "sessionToken": "abc-123",
  "suggestions": [
    {
      "placeId": "osm:eyJ...",
      "primaryText": "مطار الملكة علياء الدولي",
      "secondaryText": "عمّان، الأردن",
      "description": "مطار الملكة علياء الدولي، عمّان، الأردن",
      "distanceMeters": 32140
    }
  ]
}
```

**Behavior / rules**:
- `distanceMeters` is the straight-line distance from the request's search
  context (`lat`/`lng`, else the `cityId` centre). It is `null` when no context
  was sent. It is derived from coordinates the provider already returns with
  each suggestion, so the distance label costs no extra request and never
  triggers a per-row place-details lookup.
- Ranking preserves the provider's relevance order within a distance band, and
  lifts nearby results above distant ones. With a `cityId`, results inside that
  city outrank everything else. Results outside are kept, not dropped, so an
  intercity search still works.
- At most 6 suggestions are returned. The provider is asked for more, because
  country and city filtering happens server-side and would otherwise be able to
  empty the list.
- **Arabic spelling variants.** The query is searched as typed and, when they
  differ, alongside a ta-marbuta form (ة→ه, ى→ي) and a restored-hamza form
  (word-initial bare alef → إ, never the definite article "ال"). Results are
  interleaved and deduplicated by OSM identity. The raw query decides success;
  a failing variant never turns a working search into an error. Most queries
  produce no variant and so issue a single request.
- **Transit furniture is demoted.** Bus stops, crossings, platforms and similar
  sink below real places, because the provider ranked the bus stop outside a
  university above the university. They are demoted, not dropped.
- **City names resolve to the city.** When the query prefixes a catalog city
  name and no city has been chosen, that city is lifted to the top, or added
  when the provider missed it. A same-named place far from the city's real
  coordinates is never promoted in its stead. Skipped when `cityId` is set,
  since the user is then searching for an address inside that city.
- No matches → `{ "suggestions": [] }` (200), so the client shows a clean empty
  state and keeps "choose on map" available.
- Provider failure → `502` with a safe body. After repeated failures a breaker
  opens for 30s and requests fail fast instead of waiting for a timeout.
- Rate limited per user; over budget → `429`. Counters live in Redis so the
  limit holds across replicas, degrading to per-process counters if Redis is
  down rather than rejecting search.
- Short-TTL, size-capped server cache keyed on
  `(q, lang, countries, cityId, coarse context)`. Query text is not logged
  (constitution IV).

**Contract tests**:
- 401 without token.
- `q` shorter than 2 chars → 400 from validation.
- valid `q` → suggestions with the documented shape, including `distanceMeters`.
- `lat` without `lng` → no bias applied.
- `cityId` → in-city results ranked first, provider order kept within a band.
- a ta-marbuta or bare-alef query issues the variant request too; "الجاردنز"
  issues only one, since "إلجاردنز" is not a word.
- one variant failing while the raw query succeeds still returns results; the
  raw query failing returns 502 even when a variant succeeded.
- a bus stop ranks below the place it stands outside, and is still listed.
- a city name outranks nearer noise; a same-named place far away does not.
- rate limit exceeded → 429.
- provider error mocked → 502, no credential leak in body or logs.

---

## GET /locations/place/:id

Resolves a selected suggestion to coordinates.

**Auth**: JWT.

**Path/query**:
| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `:id` | string | yes | opaque `placeId` from a suggestion |
| `sessionToken` | string | no | the same token as the autocomplete session |

**200 response**:
```json
{ "placeId": "osm:eyJ...", "label": "مطار الملكة علياء الدولي، عمّان، الأردن", "lat": 31.7226, "lng": 35.9932 }
```

**Behavior / rules**:
- Unknown or unparseable `placeId` → `404`. An id is never reinterpreted as
  belonging to a different provider.
- Provider failure → `502`; the client keeps its text and offers the map picker.

**Contract tests**:
- 401 without token.
- valid placeId → `{ placeId, label, lat, lng }`.
- unknown placeId → 404.

---

## GET /locations/reverse

Resolves a map point to a display address. Backs the centre pin of the map
picker, so a point is labelled the way the suggestion list would name it.

**Auth**: JWT.

**Query params**:
| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `lat`,`lng` | number | yes | out-of-range values → `400` |
| `lang` | `ar` \| `en` | no | defaults to `ar` |

**200 response**:
```json
{
  "primaryText": "شارع الرينبو",
  "secondaryText": "جبل عمان، عمّان",
  "label": "شارع الرينبو، جبل عمان، عمّان",
  "lat": 31.9539,
  "lng": 35.9106
}
```

**Behavior / rules**:
- A point with no known address returns 200 with empty text, not an error. The
  user can still confirm the point; only its label is missing.
- Rate limited and cached like autocomplete, with the cache key rounded to
  roughly 11 m so map jitter reuses one answer.

**Contract tests**:
- 401 without token.
- valid point → the documented shape.
- out-of-range latitude → 400, provider not called.
- provider knows no address → 200 with empty `label`.

---

## GET /locations/cities

City catalog for the city-first route pickers. Served from a static catalog,
not the places provider: the set is small and has to render instantly.

**Auth**: JWT.

**Query params**:
| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `country` | string | no | ISO 3166-1 alpha-2; omitted → all configured operating countries |
| `q` | string | no | optional server-side filter; the app also filters its cached copy |

**200 response**:
```json
{
  "cities": [
    { "id": "jo-amman", "nameAr": "عمّان", "nameEn": "Amman", "countryCode": "JO", "lat": 31.9539, "lng": 35.9106, "popular": true }
  ]
}
```

**Behavior / rules**:
- `popular` marks the cities the picker lists first before the user types.
- Name matching is insensitive to case, Arabic diacritics and hamza spelling,
  so "اربد" finds "إربد".
- `LOCATION_AUTOCOMPLETE_COUNTRIES`, when set, also restricts this catalog.
- Ids are stable and referenced by `cityId` on autocomplete; never renumber
  them.

**Contract tests**:
- 401 without token.
- `country=jo` → only Jordanian cities.
- `q` matches across hamza and case variants.
- configured country restriction excludes everything else.
