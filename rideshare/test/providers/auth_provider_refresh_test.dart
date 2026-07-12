import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/constants/app_constants.dart';
import 'package:rideshare/core/services/auth_service.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/providers/auth_provider.dart';

void main() {
  test('loadUserProfile refreshes approval state and notifies listeners', () async {
    final pending = _driver(isApproved: false);
    final approved = _driver(isApproved: true);
    final authService = _FakeAuthService(
      initialUser: pending,
      profileResponses: [approved],
    );
    final provider = AuthProvider(authService: authService);
    await _flushMicrotasks();

    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.loadUserProfile(silent: true);

    expect(provider.userModel?.isDriverApproved, isTrue);
    expect(provider.userModel?.canCreateTrips, isTrue);
    expect(provider.isRefreshingProfile, isFalse);
    expect(notifications, greaterThan(0));
  });

  test('loadUserProfile coalesces concurrent refreshes', () async {
    final pending = _driver(isApproved: false);
    final approved = _driver(isApproved: true);
    final refresh = Completer<UserModel>();
    final authService = _FakeAuthService(
      initialUser: pending,
      profileCompleters: [refresh],
    );
    final provider = AuthProvider(authService: authService);
    await _flushMicrotasks();

    final first = provider.loadUserProfile(silent: true);
    final second = provider.loadUserProfile(silent: true);

    expect(identical(first, second), isTrue);
    expect(provider.isRefreshingProfile, isTrue);
    expect(authService.profileCallCount, 1);

    refresh.complete(approved);
    await first;

    expect(provider.userModel?.isDriverApproved, isTrue);
    expect(provider.isRefreshingProfile, isFalse);
    expect(authService.profileCallCount, 1);
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

UserModel _driver({required bool isApproved}) {
  final now = DateTime(2026, 6, 14);
  return UserModel(
    id: isApproved ? 'driver-approved' : 'driver-pending',
    phoneNumber: '+962790000000',
    email: 'driver@example.com',
    name: 'Driver',
    gender: AppConstants.genderMale,
    role: AppConstants.roleDriver,
    isPhoneVerified: true,
    isDriverApproved: isApproved,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    required this.initialUser,
    this.profileResponses = const [],
    this.profileCompleters = const [],
  });

  final UserModel initialUser;
  final List<UserModel> profileResponses;
  final List<Completer<UserModel>> profileCompleters;
  int profileCallCount = 0;

  @override
  Future<UserModel?> checkAuthState() async => initialUser;

  @override
  Future<UserModel> getProfile() async {
    final callIndex = profileCallCount++;
    if (callIndex < profileCompleters.length) {
      return profileCompleters[callIndex].future;
    }
    if (callIndex < profileResponses.length) {
      return profileResponses[callIndex];
    }
    return profileResponses.isNotEmpty ? profileResponses.last : initialUser;
  }
}
