import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class SettingsService {
  SharedPreferences? _prefs;

  SettingsService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _p async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String> getThemeMode() async {
    final prefs = await _p;
    return prefs.getString(AppConstants.keyTheme) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await _p;
    await prefs.setString(AppConstants.keyTheme, mode);
  }

  Future<bool> isPushNotificationsEnabled() async {
    final prefs = await _p;
    return prefs.getBool(AppConstants.keyNotifPushEnabled) ?? true;
  }

  Future<void> setPushNotificationsEnabled(bool enabled) async {
    final prefs = await _p;
    await prefs.setBool(AppConstants.keyNotifPushEnabled, enabled);
  }

  Future<bool> isNotificationSoundEnabled() async {
    final prefs = await _p;
    return prefs.getBool(AppConstants.keyNotifSound) ?? true;
  }

  Future<void> setNotificationSoundEnabled(bool enabled) async {
    final prefs = await _p;
    await prefs.setBool(AppConstants.keyNotifSound, enabled);
  }

  Future<bool> isNotificationVibrationEnabled() async {
    final prefs = await _p;
    return prefs.getBool(AppConstants.keyNotifVibration) ?? true;
  }

  Future<void> setNotificationVibrationEnabled(bool enabled) async {
    final prefs = await _p;
    await prefs.setBool(AppConstants.keyNotifVibration, enabled);
  }

  Future<bool> isLocationSharingEnabled() async {
    final prefs = await _p;
    return prefs.getBool(AppConstants.keyPrivacyLocationSharing) ?? true;
  }

  Future<void> setLocationSharingEnabled(bool enabled) async {
    final prefs = await _p;
    await prefs.setBool(AppConstants.keyPrivacyLocationSharing, enabled);
  }

  Future<bool> isShowOnlineStatus() async {
    final prefs = await _p;
    return prefs.getBool(AppConstants.keyPrivacyShowOnline) ?? true;
  }

  Future<void> setShowOnlineStatus(bool enabled) async {
    final prefs = await _p;
    await prefs.setBool(AppConstants.keyPrivacyShowOnline, enabled);
  }

  Future<bool> isShowRating() async {
    final prefs = await _p;
    return prefs.getBool(AppConstants.keyPrivacyShowRating) ?? true;
  }

  Future<void> setShowRating(bool enabled) async {
    final prefs = await _p;
    await prefs.setBool(AppConstants.keyPrivacyShowRating, enabled);
  }

  Future<bool> isNotifCategoryEnabled(String key) async {
    final prefs = await _p;
    return prefs.getBool(key) ?? true;
  }

  Future<void> setNotifCategoryEnabled(String key, bool enabled) async {
    final prefs = await _p;
    await prefs.setBool(key, enabled);
  }
}
