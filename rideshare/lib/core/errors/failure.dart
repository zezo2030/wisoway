import 'package:equatable/equatable.dart';

enum FailureCategory {
  network,
  server,
  validation,
  auth,
  permission,
  banned,
  unknown,
}

enum FailureSeverity {
  info,
  warning,
  error,
}

enum FailureAction {
  retry,
  reauthenticate,
  openSettings,
}

class Failure extends Equatable {
  final FailureCategory category;
  final String messageKey;
  final String? displayMessage;
  final List<String>? messageArgs;
  final FailureSeverity severity;
  final FailureAction? nextAction;
  final String developerDetail;

  /// Only populated when category == FailureCategory.banned
  final String? banReason;
  final String? supportWhatsApp;

  const Failure({
    required this.category,
    required this.messageKey,
    this.displayMessage,
    this.messageArgs,
    required this.severity,
    this.nextAction,
    required this.developerDetail,
    this.banReason,
    this.supportWhatsApp,
  });

  @override
  List<Object?> get props => [
        category,
        messageKey,
        displayMessage,
        messageArgs,
        severity,
        nextAction,
        developerDetail,
        banReason,
        supportWhatsApp,
      ];
}
