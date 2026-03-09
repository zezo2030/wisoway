# Script to get SHA-1 fingerprint for Firebase setup
# Run this script to get your SHA-1 fingerprint for adding to Firebase Console

Write-Host "Getting SHA-1 fingerprint for Debug keystore..." -ForegroundColor Cyan
Write-Host ""

# Get debug keystore path
$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $debugKeystore) {
    Write-Host "Found debug keystore at: $debugKeystore" -ForegroundColor Green
    Write-Host ""
    Write-Host "SHA-1 Fingerprint:" -ForegroundColor Yellow
    Write-Host "==================" -ForegroundColor Yellow
    
    # Get SHA-1 using keytool
    $sha1 = keytool -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android 2>&1 | Select-String -Pattern "SHA1:" | ForEach-Object { $_.Line.Trim() }
    
    if ($sha1) {
        Write-Host $sha1 -ForegroundColor Green
        Write-Host ""
        Write-Host "Copy this SHA-1 fingerprint and add it to Firebase Console:" -ForegroundColor Cyan
        Write-Host "1. Go to https://console.firebase.google.com/" -ForegroundColor White
        Write-Host "2. Select your project: rideshare-5f785" -ForegroundColor White
        Write-Host "3. Go to Project Settings (gear icon)" -ForegroundColor White
        Write-Host "4. Select your Android app" -ForegroundColor White
        Write-Host "5. In 'SHA certificate fingerprints' section, click 'Add fingerprint'" -ForegroundColor White
        Write-Host "6. Paste the SHA-1 above and save" -ForegroundColor White
    } else {
        Write-Host "Could not extract SHA-1. Please run manually:" -ForegroundColor Red
        Write-Host "keytool -list -v -keystore `"$debugKeystore`" -alias androiddebugkey -storepass android -keypass android" -ForegroundColor Yellow
    }
} else {
    Write-Host "Debug keystore not found at: $debugKeystore" -ForegroundColor Red
    Write-Host ""
    Write-Host "To generate SHA-1 manually, run:" -ForegroundColor Yellow
    Write-Host "keytool -list -v -keystore `"$debugKeystore`" -alias androiddebugkey -storepass android -keypass android" -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")








