# Driver Home — Design Assets Inventory

Source mockup:

| File | Screen |
|------|--------|
| `driver-home.png` | Driver home (الشاشة الرئيسية للسائق) |

## Implementation strategy

Use **Iconsax Plus / Material** for chrome. Reuse existing vehicle / empty-state images where possible. Do **not** crop icons from the mockup PNG.

## Colors (approx from mockup)

| Token | Hex (approx) | Use |
|-------|--------------|-----|
| Primary teal | `#0F766E` – `#0D7377` | CTA, active nav, accents |
| Page bg | `#F7F8FA` | Screen background |
| Surface | `#FFFFFF` | Cards |
| Info banner | `#E8F4FC` | Offline hint strip |
| Stat yellow | soft amber icon well | New requests |
| Stat blue | soft blue icon well | Today trips |
| Stat green | soft green icon well | Bookings |

## Icons → Iconsax / Material

| Visual | Suggested |
|--------|-----------|
| Notifications | existing `NotificationIconButton` |
| Status / wifi | `IconsaxPlusBroken.wifi` / bolt |
| Publish + | `IconsaxPlusBold.add` / `add_circle` |
| Location / GPS / map | `location`, `gps`, `map` |
| Summary trend | `chart` / `trend_up` |
| View all chevron | `arrow_left_2` (RTL) |
| Bottom nav | keep current HomeScreen icons |

## Optional reuse

| Existing path | Use |
|---------------|-----|
| `rideshare/assets/images/trip_in_progress/vehicle_camry.png` | Availability / empty illustration fallback |
| `rideshare/assets/images/trip_in_progress/vehicle_fallback.png` | Same |
| `rideshare/assets/images/presence_map_car.png` | Optional empty-state car |
