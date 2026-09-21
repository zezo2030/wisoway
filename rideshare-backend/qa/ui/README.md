# UI QA harness (Flutter app on Android emulators)

Drives the real app on a device, rather than calling the API. Complements
`qa/*.js`, which exercises the same features over HTTP.

Flutter publishes its semantics tree to Android accessibility, so
`uiautomator dump` exposes every widget's label in `content-desc` and its
`bounds`. `driver.js` turns that into find/tap/type helpers, so scripts address
widgets by their visible Arabic label instead of hard-coded pixels.

## Devices

Two emulators, because the two-sided flows need both roles at once — an instant
offer lives for 25 seconds, which is far too short to log out and back in.

```
emulator-5554   passenger
emulator-5556   driver
```

Both run the debug APK built against the local backend:

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3003/api/v1
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Running

```bash
ANDROID_SERIAL=emulator-5556 node qa/ui/10-driver-signup.js
```

`ANDROID_SERIAL` picks the device; it defaults to `emulator-5554`.

## Device prerequisites

Without these the flows fail for environmental reasons that look like app bugs:

- **Permissions**: `pm grant` notifications, fine/coarse location, camera and
  `READ_MEDIA_IMAGES`. `resetApp()` re-grants them, since `pm clear` drops them.
- **Location**: `settings put secure location_mode 3`, accept Google's
  "Location Accuracy" dialog once, and keep feeding `emu geo fix <lng> <lat>`.
  Going online as a driver waits on a real fix and otherwise fails with
  "انتهت مهلة الاتصال".
- **Gallery images**: push a few PNGs to `/sdcard/Pictures` so the document
  pickers have something to select.
- **Gboard**: dismiss the one-time "Try out your stylus" tutorial and set
  `settings put secure stylus_handwriting_enabled 0`. While it is up it swallows
  every `input text`, so fields silently stay empty.

## Gotchas these helpers encode

- **Never send BACK to dismiss the keyboard.** Injected over adb it reaches the
  activity rather than the IME, pops the route and destroys a half-filled form.
  ENTER (keycode 66) fires the field's IME action and closes the keyboard
  harmlessly — that is what `hideKeyboard()` does.
- **The OTP row is `TextDirection.ltr`** even in Arabic, so box 0 is the
  leftmost. Each box holds one character and ignores a bulk `input text`, so
  `enterOtp` taps and types digit by digit. The screen submits itself on the
  sixth digit.
- **Read-only "select" fields** (vehicle type) are `isDense` TextFormFields with
  no border: the tappable strip is well below the label and helper text inside
  the same card. `tapSelect` probes a few offsets.
- **Filter the dump by package.** With the keyboard up, the IME's keys are
  dumped next to the app's widgets and look just like inputs.
- **`adb shell input text` cannot type Arabic** — it throws. Use ASCII for any
  free-text field.
- **Re-read the tree before every interaction.** The keyboard reflows the form,
  so coordinates from an earlier dump are stale.

## Known environment limit

Instant-ride offers reach the driver by FCM push, and these emulators have no
valid FCM registration for the project — the backend logs "The registration
token is not a valid FCM registration token". The offer card therefore only
appears when the app happens to re-fetch `/instant-rides/offers/pending` on
resume, which `watch-offer.js` forces by repeatedly foregrounding the activity.
Offer delivery itself is covered properly by `qa/04-instant-rides.js`.
