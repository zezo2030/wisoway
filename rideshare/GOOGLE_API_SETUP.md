# Google API Configuration Fix

## Error: `DEVELOPER_ERROR` in GoogleApiManager

This error occurs when Google Sign-In or Google Maps APIs are not properly configured. Follow these steps to fix it:

## Fix Google Sign-In

1. **Get your app's SHA-1 fingerprint:**
   ```bash
   # For debug keystore (development)
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # For Windows (debug keystore)
   keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```

2. **Configure in Firebase Console:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project: `rideshare-5f785`
   - Go to **Project Settings** (gear icon) > **Your apps**
   - Click on your Android app
   - Scroll down to **SHA certificate fingerprints**
   - Click **Add fingerprint** and paste your SHA-1
   - Save

3. **Enable Google Sign-In:**
   - Go to **Authentication** > **Sign-in method**
   - Click on **Google**
   - Toggle **Enable**
   - Enter your **Support email**
   - Click **Save**

4. **Download updated google-services.json:**
   - Go to **Project Settings** > **Your apps**
   - Download the updated `google-services.json`
   - Replace `android/app/google-services.json` with the new file

5. **Rebuild the app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Fix Google Maps API

1. **Enable Maps SDK for Android:**
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Select project: `rideshare-5f785`
   - Go to **APIs & Services** > **Library**
   - Search for "Maps SDK for Android"
   - Click **Enable**

2. **Enable Places API (if using location search):**
   - In the same library, search for "Places API"
   - Click **Enable**

3. **Check API Key restrictions:**
   - Go to **APIs & Services** > **Credentials**
   - Click on your API key: `AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw`
   - Under **Application restrictions**, ensure:
     - **Android apps** is selected
     - Your package name `com.example.rideshare` is added
   - Under **API restrictions**, ensure:
     - **Restrict key** is selected
     - **Maps SDK for Android** is checked
     - **Places API** is checked (if using location search)

4. **Rebuild the app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Verify Configuration

After completing the above steps, the `DEVELOPER_ERROR` should be resolved. The app will now be able to:
- Use Google Sign-In without errors
- Load Google Maps properly
- Use location services

## Note

The error message you see is a warning and might not break functionality immediately, but Google Sign-In and Maps features will not work until properly configured.

