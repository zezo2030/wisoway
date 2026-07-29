# Create Trip Wizard — Design Assets Inventory

Source mockups (copied from user screenshots):

| File | Screen |
|------|--------|
| `step1-route.png` | Step 1 — المسار |
| `step2-details.png` | Step 2 — تفاصيل الرحلة |
| `step3-review.png` | Step 3 — مراجعة ونشر |

## Implementation strategy

Most UI chrome uses **Iconsax Plus / Material Icons** already in the Flutter app (no PNG extraction needed).  
Only a few items need **custom assets** or **CustomPainter** widgets.

---

## A. Custom graphics (must create / ship as assets)

| ID | Description | Used in | Suggested path / approach |
|----|-------------|---------|---------------------------|
| `car_topdown_shell` | Single scalable top-down white car shell; height follows **visible rows** for current available seat count (option B) | Step 2 | **CustomPainter only** (no per-type PNGs) |
| `seat_available` | Teal seat tile with check | Step 2 | Widget (Container + Icon) — no PNG |
| `seat_driver` | Dark grey driver seat | Step 2 | Widget |
| `seat_inactive` | White outlined inactive seat (partial last row only) | Step 2 | Widget |
| `route_connector` | Vertical dotted line + green/red dots | Step 1 | Widget |
| `license_plate_sa` | Decorative plate (BBR style) — **optional** | Step 3 | Skip or simple text badge; not required for MVP |
| `vehicle_photo` | Real vehicle image | Step 3 | From API (`vehicle.imageUrl`); fallback: existing `vehicle_camry.png` / `vehicle_fallback.png` |

### Existing reusable assets in repo

| Existing path | Reuse for |
|---------------|-----------|
| `rideshare/assets/images/trip_in_progress/vehicle_camry.png` | Step 3 vehicle card fallback |
| `rideshare/assets/images/trip_in_progress/vehicle_fallback.png` | Missing vehicle photo |
| `rideshare/assets/images/trip_in_progress/progress_car.png` | Optional route mid-icon |
| `rideshare/assets/images/presence_map_car.png` | Optional map/route car |

---

## B. Icons (map to Iconsax / Material — no image export)

### Shared chrome
| Visual | Suggested icon |
|--------|----------------|
| Back | `Icons.arrow_back_ios_new` / Iconsax arrow |
| Close | `Icons.close` |
| Step check | `Icons.check` |
| Chevron / next | `Icons.chevron_*` / Iconsax arrow |

### Step 1 — المسار
| Visual | Suggested icon |
|--------|----------------|
| Origin (من) | Green circle + `Icons.trip_origin` |
| Destination (إلى) | Red `Icons.location_on` |
| Locate / crosshair | `IconsaxPlusBroken.gps` / `Icons.my_location` |
| Add stop (+) | `Icons.add` |
| Distance | `IconsaxPlusBroken.routing` / road |
| Duration | `IconsaxPlusBroken.clock` |
| Road type | `IconsaxPlusBroken.driver` / highway |

### Step 2 — تفاصيل الرحلة
| Visual | Suggested icon |
|--------|----------------|
| Date | `IconsaxPlusBroken.calendar_1` |
| Time | `IconsaxPlusBroken.clock` |
| Price / wallet | `IconsaxPlusBroken.wallet_1` |
| Currency | Text badge `JOD` |
| Recurrence | `IconsaxPlusBroken.refresh` / `Icons.repeat` |
| Notes | `IconsaxPlusBroken.message` / chat |
| Seat +/- | `Icons.remove` / `Icons.add` |
| **منع الاختلاط** (new) | `IconsaxPlusBroken.people` / `Icons.diversity_3` / shield-people |

### Step 3 — مراجعة ونشر
| Visual | Suggested icon |
|--------|----------------|
| Save draft | `IconsaxPlusBroken.bookmark` |
| Calendar / clock / seats / wallet | same as Step 2 |
| AC / extras | `IconsaxPlusBroken.box` / `Icons.ac_unit` |
| Repeat summary | `Icons.repeat` |
| No smoking | `Icons.smoke_free` |
| Phone note | `IconsaxPlusBroken.call` |
| Shield info | `IconsaxPlusBroken.shield_tick` |
| Publish | `IconsaxPlusBroken.send_2` / paper plane |
| Back to edit | outlined button + arrow |

---

## C. Colors extracted from mockups (approx)

| Token | Hex (approx) | Use |
|-------|--------------|-----|
| Primary teal | `#0D7377` – `#0F766E` | Active step, CTA, available seats |
| Primary dark | `#0B5F63` | Headers / emphasis |
| Driver seat | `#4A5568` / slate | Unavailable driver |
| Origin green | `#22C55E` | From pin |
| Destination red | `#EF4444` | To pin |
| Info blue bg | `#E8F4FC` | Publish notice |
| Surface | `#FFFFFF` | Cards |
| Page bg | `#F7F8FA` | Screen background |
| Inactive step | `#CBD5E1` | Stepper gray |

---

## D. Seat layout templates (from vehicle type — not editable on create)

Aligned with backend `VEHICLE_TYPE_CATALOG` (passenger seats; driver excluded from count).
Sedan locked to **4** seats / `[1, 3]`. Cabin uses **progressive row reveal** (option B):
only rows needed for `availableSeatCount` are drawn; shell height animates.

| Type | Catalog seats | Layout shape | Cabin note |
|------|---------------|--------------|------------|
| sedan | 4 | [1, 3] | Short at 1 seat; full at 4 |
| suv | 5 | [2, 3] | 1–2 visible rows |
| van | 7 | [2, 3, 2] | 1–3 visible rows |
| truck | 2 | 1×2 | Single row |
| bus | 20 | 5×4 | Grid; may simplify shell |
| motorcycle | 1 | 1×1 | Minimal |

---

## E. New copy / strings needed (Arabic)

| Key idea | AR draft |
|----------|----------|
| Prevent mixing toggle | منع الاختلاط |
| Family exception note | يستثنى من ذلك حجز العائلة |
| Can disable note | يمكن تعطيل هذا الخيار والسماح بالاختلاط |
| Available / Driver / Inactive | متاح / غير متاح (السائق) / مقعد خامل |

---

## F. What was NOT extracted as crop files

Full-screen PNGs are design references only. Cropping individual icons from low-res mockups produces poor quality; prefer vector Iconsax + CustomPainter for the car shell. If product later supplies Figma exports, replace `car_topdown_*` with those SVGs/PNGs.
