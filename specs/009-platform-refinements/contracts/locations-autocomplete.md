# Contract: Location Autocomplete (backend proxy over Google Places)

Keeps the Google API key server-side (constitution IV). Used by the mobile origin/destination fields.

## GET /locations/autocomplete

Returns ranked place suggestions for a partial query.

**Auth**: JWT (any authenticated user).

**Query params**:
| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `q` | string | yes | partial text; server rejects < 2 chars with empty list |
| `lang` | `ar` \| `en` | no | defaults to request locale; biases suggestion language (FR-007) |
| `sessionToken` | string | no | client-generated session token to group billing; echoed to Places |
| `lat`,`lng` | number | no | optional location bias toward the user |

**200 response**:
```json
{
  "sessionToken": "abc-123",
  "suggestions": [
    { "placeId": "ChIJ...", "primaryText": "Queen Alia Intl Airport", "secondaryText": "Amman, Jordan", "description": "Queen Alia International Airport, Amman, Jordan" }
  ]
}
```

**Behavior / rules**:
- Results are region-biased to the platform's service region and language-matched to `lang`.
- Empty `q` or no matches → `{ "suggestions": [] }` (200), so the client shows a clean "no matching places" state (FR-008).
- Upstream/provider failure → `502` with a safe error body; the client falls back to the tap-on-map picker (FR-008). Query text is not logged (constitution IV).
- Short-TTL server cache keyed on `(q, lang, region)`; per-user rate limiting applied.

**Contract tests**:
- 401 without token.
- `q` length < 2 → empty suggestions, 200.
- valid `q` → array of suggestions with the documented shape.
- provider error mocked → 502, no key leak in body/logs.

---

## GET /locations/place/:id

Resolves a selected suggestion to coordinates.

**Auth**: JWT.

**Path/query**:
| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `:id` | string | yes | `placeId` from a suggestion |
| `sessionToken` | string | no | same token as the autocomplete session (closes billing session) |

**200 response**:
```json
{ "placeId": "ChIJ...", "label": "Queen Alia International Airport, Amman, Jordan", "lat": 31.7226, "lng": 35.9932 }
```

**Behavior / rules**:
- Unknown/expired `placeId` → `404`.
- Provider failure → `502`; client keeps the typed text and offers the map picker.

**Contract tests**:
- 401 without token.
- valid placeId → `{ placeId, label, lat, lng }`.
- unknown placeId → 404.
