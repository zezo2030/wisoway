# rideshare

A new Flutter project.

## ربط الباكند (Backend)

1. **تشغيل الباكند** من مجلد `rideshare-backend`:
   ```bash
   npm run start:dev
   ```
   الباكند يعمل على `http://localhost:3003` والـ API تحت `api/v1`.

2. **التطبيق مضبوط مسبقاً** على:
   - **محاكي أندرويد:** `http://10.0.2.2:3003/api/v1`
   - للتشغيل على **جهاز حقيقي** استخدم IP جهازك:
     ```bash
     flutter run --dart-define=BASE_URL=http://192.168.1.XXX:3003/api/v1
     ```
   - **محاكي iOS:** غيّر الـ default في `lib/core/api/api_endpoints.dart` إلى `http://127.0.0.1:3003/api/v1` أو استخدم dart-define.

3. تأكد أن MongoDB و Redis يعملان (حسب إعدادات الباكند في `.env`).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
