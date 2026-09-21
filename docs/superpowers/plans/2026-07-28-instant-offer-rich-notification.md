# Instant Offer Rich Notification — Implementation Plan

> **For agentic workers:** Execute task-by-task. Steps use checkbox syntax.

**Goal:** Rich Android system notification + restyled in-app dialog for `instant_offer`, matching the VisionWay direct-trip card.

**Architecture:** Mirror `BookingNotificationHelper` with `InstantOfferNotificationHelper` (RemoteViews + countdown + Accept/Reject intents). Enrich FCM payload in `makeOffer`. Flutter handles action deep-links via existing InstantRideService APIs. Redesign `_InstantOfferDialog` to match.

**Tech Stack:** NestJS/TypeORM, Flutter, Android Kotlin RemoteViews, FCM

**Spec:** `docs/superpowers/specs/2026-07-28-instant-offer-rich-notification-design.md`

## Global Constraints

- Reuse channel `rideshare_notifications`
- No new DB columns
- Distance via haversine at offer time
- Accept/Reject API calls stay in Flutter (auth)
- Keep counter-offer in in-app dialog only
- Do not break booking_created rich notification

---

## Task 1: Backend payload enrichment

**Files:** `rideshare-backend/src/modules/instant-rides/instant-dispatch.service.ts` (+ spec if present)

- [x] Add haversine + label helpers (or import shared)
- [x] Extend `makeOffer` push `data` with distanceKm, durationMinutes, labels
- [x] Include seatCount / seatCountLabel
- [ ] Run related unit tests (deferred)

## Task 2: Android notification UI + helper

**Files:** layouts, drawables, `InstantOfferNotificationHelper.kt`, `InstantOfferActionReceiver.kt`, `MainActivity.kt`, `VisionWayMessagingService.kt`, `AndroidManifest.xml`

- [x] Create green badge + lightning drawables
- [x] Create collapsed/expanded layouts
- [x] Helper with countdown ticker + Accept/Reject/Open intents
- [x] Receiver → MainActivity with extras
- [x] Wire MethodChannel + FCM intercept for `instant_offer`
- [x] Align labels/colors with VisionWay light card (#007D69)

## Task 3: Flutter push + actions

**Files:** `push_notification_service.dart`, `notification_model.dart`, `notification_navigation_service.dart`, `main.dart` as needed

- [x] Add `instantOffer` type
- [x] Foreground → native show
- [x] Handle intent extras accept/decline/open

## Task 4: In-app dialog redesign

**Files:** `driver_availability_card.dart` (or extracted widget)

- [x] Match notification visual language (white card / brand green)
- [x] Keep counter-offer
- [x] Skip/cancel system notif when dialog shown for same offerId

## Task 5: Verify

- [ ] Backend tests for payload labels (deferred)
- [ ] Manual checklist from spec §8
