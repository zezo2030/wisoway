import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../constants/route_names.dart';
import '../services/trip_service.dart';
import '../ui/error_surface.dart';

/// All publish entry points check the server before opening the trip form.
class SharedTripNavigation {
  static final _checking = <NavigatorState>{};

  static Future<T?> open<T>(
    BuildContext context, {
    Future<void> Function()? checkEligibility,
  }) async {
    final navigator = Navigator.of(context);
    if (!_checking.add(navigator)) return null;
    final root = Navigator.of(context, rootNavigator: true);
    final progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    unawaited(root.push(progress));
    Object? failure;
    try {
      await (checkEligibility ?? TripService().assertCanCreateTrip)();
    } catch (error) {
      failure = error;
    } finally {
      if (progress.isActive) root.removeRoute(progress);
      _checking.remove(navigator);
    }
    if (!navigator.mounted) return null;
    if (failure != null) {
      ErrorSurface.showFailure(navigator.context, ApiClient.mapError(failure));
      return null;
    }
    return navigator.pushNamed<T>(RouteNames.createTrip);
  }
}
