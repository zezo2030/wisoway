import 'package:flutter/foundation.dart';
import 'package:rideshare/providers/auth_provider.dart';

/// Stands in for AuthProvider in widget tests so a screen can be pumped without
/// reaching a real server.
///
/// Screens read AuthProvider during build, so its absence used to surface as a
/// ProviderNotFoundException from deep inside the widget tree rather than as
/// anything a reader could act on.
class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
