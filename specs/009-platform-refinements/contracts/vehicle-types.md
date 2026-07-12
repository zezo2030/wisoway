# Contract: Vehicle Types Catalog

Exposes the canonical vehicle-type → seat-layout templates so clients can auto-apply a layout on type selection (FR-009/FR-010/FR-012). Backend remains the source of truth.

## GET /vehicles/types

**Auth**: JWT (any authenticated user; drivers use it during vehicle setup / trip creation).

**200 response**:
```json
{
  "types": [
    {
      "type": "sedan",
      "label": { "en": "Sedan", "ar": "سيدان" },
      "seats": 3,
      "layout": { "rows": 1, "seatsPerRow": 3, "preventGenderMixing": false }
    },
    {
      "type": "van",
      "label": { "en": "Van", "ar": "فان" },
      "seats": 7,
      "layout": { "rows": 3, "seatsPerRow": 3, "seatsPerRowList": [2, 3, 2] }
    }
  ]
}
```

**Behavior / rules**:
- Every supported `type` MUST appear with a non-empty `layout` (FR-012). A type missing a template is served with a flagged default and logged server-side.
- `layout` uses the existing `SeatLayout` shape already stored on `vehicle.seatLayout` (no new structure).
- Response is cacheable (rarely changes); clients may mirror it locally for offline prefill, but the server value wins.

**Contract tests**:
- 401 without token.
- 200 returns the full supported set; each entry has `type`, `label.en`, `label.ar`, `seats`, and a non-empty `layout`.
- `seats` equals the bookable seat count implied by `layout`.
