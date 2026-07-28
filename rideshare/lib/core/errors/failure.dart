import 'package:equatable/equatable.dart';

enum FailureCategory {
  network,
  server,
  validation,
  auth,
  permission,
  banned,
  outstandingCharges,
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
  viewPendingCharges,
  topUpWallet,
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

  /// Only populated when category == FailureCategory.outstandingCharges
  final int? outstandingCount;
  final double? outstandingTotal;

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
    this.outstandingCount,
    this.outstandingTotal,
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
        outstandingCount,
        outstandingTotal,
      ];
}
