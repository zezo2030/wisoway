import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../errors/failure.dart';
import '../services/error_localizations.dart';
import '../../core/constants/route_names.dart';

class ErrorSurface {
  static void showFailure(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    if (kDebugMode) {
      final resolvedMessage = _resolveMessage(context, failure);
      final shouldPrintVerbose =
          failure.severity == FailureSeverity.error &&
          failure.messageKey != 'errorsWalletInsufficientBalance';

      debugPrint(
        shouldPrintVerbose
            ? '[Failure] ${failure.developerDetail}'
            : '[Failure] ${failure.messageKey}: $resolvedMessage',
      );
    }

    switch (failure.severity) {
      case FailureSeverity.info:
      case FailureSeverity.warning:
        _showSnackBar(context, failure, onRetry: onRetry);
        break;
      case FailureSeverity.error:
        _showDialog(context, failure, onRetry: onRetry);
        break;
    }
  }

  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    _showBasicSnackBar(context, message, Colors.blue);
  }

  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    _showBasicSnackBar(context, message, Colors.green);
  }

  static void _showBasicSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _showSnackBar(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    final message = _resolveMessage(context, failure);
    final color = failure.severity == FailureSeverity.warning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        action: failure.nextAction != null
            ? SnackBarAction(
                label: _actionLabel(context, failure.nextAction!),
                onPressed: () =>
                    _handleAction(context, failure.nextAction!, onRetry: onRetry),
              )
            : null,
      ),
    );
  }

  static void _showDialog(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    final message = _resolveMessage(context, failure);
    final errorTitle = ErrorLocalizations.resolve(context, 'error');
    final okLabel = ErrorLocalizations.resolve(context, 'ok');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(errorTitle),
        content: Text(message),
        actions: [
          if (failure.nextAction != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _handleAction(context, failure.nextAction!, onRetry: onRetry);
              },
              child: Text(_actionLabel(context, failure.nextAction!)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }

  static String _actionLabel(BuildContext context, FailureAction action) {
    switch (action) {
      case FailureAction.retry:
        return ErrorLocalizations.resolve(context, 'errorsActionRetry');
      case FailureAction.reauthenticate:
        return ErrorLocalizations.resolve(context, 'errorsActionReauthenticate');
      case FailureAction.openSettings:
        return ErrorLocalizations.resolve(context, 'errorsActionOpenSettings');
    }
  }

  static void _handleAction(
    BuildContext context,
    FailureAction action, {
    VoidCallback? onRetry,
  }) {
    switch (action) {
      case FailureAction.retry:
        onRetry?.call();
        break;
      case FailureAction.reauthenticate:
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(RouteNames.signIn, (route) => false);
        break;
      case FailureAction.openSettings:
        launchUrl(Uri.parse('app-settings:'));
        break;
    }
  }

  static String _resolveMessage(BuildContext context, Failure failure) {
    final custom = failure.displayMessage?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return ErrorLocalizations.resolve(context, failure.messageKey);
  }
}
