# Contract — Recurrence Sub-Surface (Phase 4)

The HTTP surface for recurrence rules is covered in `trips.contract.md` (sections "POST /trips/recurrence-rules", "PATCH …/:id", "DELETE …/:id"). This file documents only the **rule-template payload shape** that is shared by the trip-create endpoint and the recurrence rule endpoints, so it does not drift between them.

## Rule template JSON (`trip_recurrence_rules.templateJson`)

```json
{
  "fromName": "...",
  "fromAddress": "...",
  "fromPoint": { "lat": ..., "lng": ... },
  "toName": "...",
  "toAddress": "...",
  "toPoint": { "lat": ..., "lng": ... },
  "price": "5.00",
  "currency": "JOD",
  "totalSeats": 4,
  "seatLayout": { ... },
  "stops": [ ... ],
  "notes": "...",
  "carImageUrl": "..."
}
```

This template is captured at rule creation and used as-is by the spawner. **Editing the rule does NOT mutate already-spawned trips** — those are independent rows. Admins or drivers wanting to change a single occurrence should edit that occurrence's trip directly.

## Spawn algorithm

```
for each active rule:
  start = rule.lastSpawnedFor || rule.createdAt::date
  end   = min(now + 14 days, rule.until || infinity)::date
  for date in (start, end]:
    if rule.frequency='weekly' and date.weekday() not in rule.weekdays: continue
    departure = local-time-on(date, rule.localTime, rule.timezone)
    if exists trip with (driverId, departureTime=departure): log 'recurrence_skip'; continue
    create Trip from rule.templateJson with departureTime=departure, recurrenceRuleId=rule.id
  rule.lastSpawnedFor = end
```

## Spawn triggers

- Hourly cron (BullMQ repeat job).
- Optional manual admin endpoint `POST /admin/recurrence-rules/:id/spawn-now` for ops debugging.

## Cancellation impact

- A driver-cancellation of a single spawned trip leaves the rule active and the next sweep generates the *next* date (not the cancelled one).
- A driver-cancellation of the rule itself (via DELETE `/trips/recurrence-rules/:id`) sets `isActive=false`. Already-spawned future trips are NOT touched — the driver must cancel them individually if desired (this is a deliberate UX decision; bulk-cancel may be added later).
