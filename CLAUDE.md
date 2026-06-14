# mahoudmsq Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-27

## Active Technologies
- TypeScript 5.7 (backend); Dart 3.x / Flutter 3.9.2 (mobile) (007-app-ux-improvements)
- PostgreSQL (backend) via TypeORM. New column `city` on `users`. (007-app-ux-improvements)
- TypeScript 5.7 (backend), Dart 3.x / Flutter 3.9.2 (mobile), TypeScript ~5.x (admin dashboard) + NestJS 11.x, TypeORM, BullMQ (job queues), Twilio (SMS OTP — already integrated), Firebase Admin SDK (push), Socket.IO (chat gateway), Cliq A2A (in-app fee payment — retained per CLAR-001), PostGIS (spatial queries), bcrypt (legacy password hashing — to be removed for end-user auth, kept only for any admin login). Mobile: `flutter_bloc`, `provider`, `dio`, `geolocator`, `device_info_plus`, `share_plus`, Google Maps Flutter, Firebase Messaging, `flutter_localizations` (AR/EN). Dashboard: React, react-i18next. (008-platform-completion)
- PostgreSQL (primary store, with PostGIS extension on `trips` for nearby-trip search). Redis (cache + BullMQ broker — already used). (008-platform-completion)

- TypeScript 5.7 (backend), Dart 3.x / Flutter 3.9.2 (mobile) + NestJS 11.x, TypeORM, bcrypt, Twilio (backend); Flutter BLoC, dio/http client (mobile) (006-password-reset)

## Project Structure

```text
src/
tests/
```

## Commands

npm test; npm run lint

## Code Style

TypeScript 5.7 (backend), Dart 3.x / Flutter 3.9.2 (mobile): Follow standard conventions

## Recent Changes
- 008-platform-completion: Added TypeScript 5.7 (backend), Dart 3.x / Flutter 3.9.2 (mobile), TypeScript ~5.x (admin dashboard) + NestJS 11.x, TypeORM, BullMQ (job queues), Twilio (SMS OTP — already integrated), Firebase Admin SDK (push), Socket.IO (chat gateway), Cliq A2A (in-app fee payment — retained per CLAR-001), PostGIS (spatial queries), bcrypt (legacy password hashing — to be removed for end-user auth, kept only for any admin login). Mobile: `flutter_bloc`, `provider`, `dio`, `geolocator`, `device_info_plus`, `share_plus`, Google Maps Flutter, Firebase Messaging, `flutter_localizations` (AR/EN). Dashboard: React, react-i18next.
- 007-app-ux-improvements: Added TypeScript 5.7 (backend); Dart 3.x / Flutter 3.9.2 (mobile)

- 006-password-reset: Added TypeScript 5.7 (backend), Dart 3.x / Flutter 3.9.2 (mobile) + NestJS 11.x, TypeORM, bcrypt, Twilio (backend); Flutter BLoC, dio/http client (mobile)

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
