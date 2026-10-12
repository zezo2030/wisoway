import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/constants/route_names.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/notification_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/providers/notification_provider.dart';
import 'package:rideshare/screens/notifications/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAuthProvider extends AuthProvider {
  _StubAuthProvider(this._user);

  final UserModel _user;

  @override
  UserModel? get userModel => _user;

  @override
  Future<void> loadUserProfile({bool silent = false}) async {}
}

/// Serves a fixed inbox without reaching the server.
class _FakeNotificationProvider extends ChangeNotifier
    implements NotificationProvider {
  _FakeNotificationProvider(this.notifications);

  @override
  final List<NotificationModel> notifications;

  final List<String> read = [];

  @override
  Future<void> fetchNotifications() async {}

  @override
  Future<void> markAsRead(String notificationId) async {
    read.add(notificationId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

UserModel _user(String role) => UserModel(
  id: 'u1',
  phoneNumber: '0790000000',
  email: 'u@example.com',
  name: 'سالم',
  gender: 'male',
  role: role,
  isDriverApproved: role == 'driver',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

NotificationModel _notification(
  String type, {
  String title = 'عنوان',
  String body = 'نص الإشعار',
  Map<String, dynamic>? data,
}) => NotificationModel(
  id: 'n-$type',
  userId: 'u1',
  type: type,
  title: title,
  body: body,
  data: data,
  createdAt: DateTime(2026, 10, 1),
);

/// Pumps the inbox with [notification] and taps it. Returns the routes that
/// were pushed, as "name args".
Future<List<String>> _tap(
  WidgetTester tester,
  NotificationModel notification, {
  String role = 'passenger',
}) async {
  final pushed = <String>[];
  final inbox = _FakeNotificationProvider([notification]);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _StubAuthProvider(_user(role)),
        ),
        ChangeNotifierProvider<NotificationProvider>.value(value: inbox),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const NotificationsScreen(),
        onGenerateRoute: (settings) {
          pushed.add('${settings.name} ${settings.arguments}');
          return MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('destination')),
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text(notification.title));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(inbox.read, [notification.id]);
  return pushed;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  group('NotificationsScreen taps', () {
    testWidgets('a new rating opens the rated trip for a passenger', (
      tester,
    ) async {
      final pushed = await _tap(
        tester,
        _notification(
          'rating_new',
          title: 'تقييم جديد',
          data: {'tripId': 't1', 'ratingId': 'r1'},
        ),
      );
      expect(pushed, ['${RouteNames.tripDetails} t1']);
    });

    testWidgets('a new rating opens trip management for a driver', (
      tester,
    ) async {
      final pushed = await _tap(
        tester,
        _notification(
          'rating_new',
          title: 'تقييم جديد',
          data: {'tripId': 't1'},
        ),
        role: 'driver',
      );
      expect(pushed, ['${RouteNames.tripManagement} t1']);
    });

    testWidgets('a trip started notice opens that trip', (tester) async {
      final pushed = await _tap(
        tester,
        _notification(
          'trip_started',
          title: 'بدأت الرحلة',
          data: {'tripId': 't2'},
        ),
      );
      expect(pushed, ['${RouteNames.tripDetails} t2']);
    });

    testWidgets('an auto-completed trip opens the driver\'s trip summary', (
      tester,
    ) async {
      final pushed = await _tap(
        tester,
        _notification(
          'trip_auto_completed',
          title: 'تم إنهاء الرحلة تلقائياً',
          data: {'tripId': 't3'},
        ),
        role: 'driver',
      );
      expect(pushed, ['${RouteNames.tripSummary} {tripId: t3}']);
    });

    testWidgets('a trip id sent as entityId is followed too', (tester) async {
      final pushed = await _tap(
        tester,
        _notification(
          'booking_canceled_by_passenger',
          title: 'إلغاء حجز',
          data: {'entityId': 't4'},
        ),
        role: 'driver',
      );
      expect(pushed, ['${RouteNames.tripManagement} t4']);
    });

    testWidgets('a fare credit opens the driver wallet', (tester) async {
      final pushed = await _tap(
        tester,
        _notification(
          'ride_fare_credited',
          title: 'أجرة',
          data: {'tripId': 't5'},
        ),
        role: 'driver',
      );
      expect(pushed, ['${RouteNames.driverWallet} null']);
    });

    testWidgets('a notice with nowhere to go shows its full text', (
      tester,
    ) async {
      final pushed = await _tap(
        tester,
        _notification(
          'admin_broadcast',
          title: 'إعلان',
          body: 'نص طويل للإعلان يظهر كاملاً عند الضغط عليه.',
        ),
      );
      expect(pushed, isEmpty);
      expect(find.byKey(const Key('notification-full-text')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('notification-full-text')),
          matching: find.text('نص طويل للإعلان يظهر كاملاً عند الضغط عليه.'),
        ),
        findsOneWidget,
      );
    });
  });
}
