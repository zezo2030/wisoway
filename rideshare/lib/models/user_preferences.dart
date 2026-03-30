enum AppThemeMode { system, light, dark }

enum NotificationCategory { trips, payments, messages, system }

class UserPreferences {
  final AppThemeMode themeMode;
  final String languageCode;
  final bool pushNotificationsEnabled;
  final bool notificationSoundEnabled;
  final bool notificationVibrationEnabled;
  final bool notifTripsEnabled;
  final bool notifPaymentsEnabled;
  final bool notifMessagesEnabled;
  final bool notifSystemEnabled;
  final bool locationSharingEnabled;
  final bool showOnlineStatus;
  final bool showRating;

  const UserPreferences({
    this.themeMode = AppThemeMode.system,
    this.languageCode = 'ar',
    this.pushNotificationsEnabled = true,
    this.notificationSoundEnabled = true,
    this.notificationVibrationEnabled = true,
    this.notifTripsEnabled = true,
    this.notifPaymentsEnabled = true,
    this.notifMessagesEnabled = true,
    this.notifSystemEnabled = true,
    this.locationSharingEnabled = true,
    this.showOnlineStatus = true,
    this.showRating = true,
  });
}
