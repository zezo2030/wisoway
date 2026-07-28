import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import 'failure.dart';

class ExceptionMapper {
  const ExceptionMapper._();

  static Failure fromError(Object error, [StackTrace? stackTrace]) {
    final detail = _buildDeveloperDetail(error, stackTrace);

    if (error is DioException) {
      return _mapDioException(error, detail);
    }

    if (error is FirebaseException) {
      return _mapFirebaseException(error, detail);
    }

    if (error is PlatformException) {
      return _mapPlatformException(error, detail);
    }

    if (error is FormatException) {
      return Failure(
        category: FailureCategory.validation,
        messageKey: 'errorsValidationGeneric',
        severity: FailureSeverity.warning,
        developerDetail: detail,
      );
    }

    if (error is TimeoutException) {
      return Failure(
        category: FailureCategory.network,
        messageKey: 'errorsNetworkTimeout',
        severity: FailureSeverity.warning,
        nextAction: FailureAction.retry,
        developerDetail: detail,
      );
    }

    return Failure(
      category: FailureCategory.unknown,
      messageKey: 'errorsUnknownGeneric',
      severity: FailureSeverity.error,
      nextAction: FailureAction.retry,
      developerDetail: detail,
    );
  }

  static Failure _mapDioException(DioException error, String detail) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Failure(
          category: FailureCategory.network,
          messageKey: 'errorsNetworkTimeout',
          severity: FailureSeverity.warning,
          nextAction: FailureAction.retry,
          developerDetail: detail,
        );

      case DioExceptionType.connectionError:
        return Failure(
          category: FailureCategory.network,
          messageKey: 'errorsNetworkOffline',
          severity: FailureSeverity.warning,
          nextAction: FailureAction.retry,
          developerDetail: detail,
        );

      case DioExceptionType.badResponse:
        return _mapBadResponse(error, detail);

      case DioExceptionType.cancel:
        return Failure(
          category: FailureCategory.unknown,
          messageKey: 'errorsUnknownGeneric',
          severity: FailureSeverity.info,
          developerDetail: detail,
        );

      case DioExceptionType.badCertificate:
        return Failure(
          category: FailureCategory.network,
          messageKey: 'errorsNetworkOffline',
          severity: FailureSeverity.warning,
          nextAction: FailureAction.retry,
          developerDetail: detail,
        );

      case DioExceptionType.unknown:
        return Failure(
          category: FailureCategory.unknown,
          messageKey: 'errorsUnknownGeneric',
          severity: FailureSeverity.error,
          nextAction: FailureAction.retry,
          developerDetail: detail,
        );
    }
  }

  static Failure _mapBadResponse(DioException error, String detail) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (statusCode == 401) {
      // A 401 on a request that carried no Authorization header (login and
      // other public endpoints) means the submitted credentials were wrong —
      // NOT an expired session. Showing "session expired / log in again" or
      // triggering reauth there is misleading, so map it to invalid creds.
      final isAuthenticatedRequest = error.requestOptions.headers.keys
          .any((key) => key.toLowerCase() == 'authorization');
      if (!isAuthenticatedRequest) {
        return Failure(
          category: FailureCategory.auth,
          messageKey: 'errorsAuthInvalidCredentials',
          severity: FailureSeverity.warning,
          developerDetail: detail,
        );
      }
      return Failure(
        category: FailureCategory.auth,
        messageKey: 'errorsAuthSessionExpired',
        severity: FailureSeverity.error,
        nextAction: FailureAction.reauthenticate,
        developerDetail: detail,
      );
    }

    if (statusCode == 403) {
      final code = _extractCode(data);
      if (code == 'ACCOUNT_BANNED') {
        final banReason = data is Map ? data['banReason'] as String? : null;
        final supportWhatsApp =
            data is Map ? data['supportWhatsApp'] as String? : null;
        return Failure(
          category: FailureCategory.banned,
          messageKey: 'errorsAccountBanned',
          severity: FailureSeverity.error,
          developerDetail: detail,
          banReason: banReason,
          supportWhatsApp: supportWhatsApp,
        );
      }
      if (code == 'OUTSTANDING_CHARGES') {
        final count = data is Map ? (data['count'] as num?)?.toInt() : null;
        final total = data is Map
            ? (data['totalAmount'] as num?)?.toDouble()
            : null;
        return Failure(
          category: FailureCategory.outstandingCharges,
          messageKey: 'errorsOutstandingCharges',
          severity: FailureSeverity.error,
          nextAction: FailureAction.viewPendingCharges,
          developerDetail: detail,
          outstandingCount: count,
          outstandingTotal: total,
        );
      }
      if (code == 'NEGATIVE_WALLET_BALANCE') {
        final message = data is Map
            ? (data['message'] as String?)
            : null;
        return Failure(
          category: FailureCategory.permission,
          messageKey: 'errorsNegativeWalletBalance',
          displayMessage: message,
          severity: FailureSeverity.error,
          nextAction: FailureAction.topUpWallet,
          developerDetail: detail,
        );
      }
    }

    if (statusCode != null && statusCode >= 500) {
      return Failure(
        category: FailureCategory.server,
        messageKey: 'errorsServerGeneric',
        severity: FailureSeverity.error,
        nextAction: FailureAction.retry,
        developerDetail: detail,
      );
    }

    if (statusCode != null && statusCode >= 400) {
      final backendMessage = _extractBackendMessage(data);
      final knownMessageKey = _mapKnownBackendMessageKey(backendMessage);
      return Failure(
        category: FailureCategory.validation,
        messageKey: knownMessageKey ?? 'errorsValidationGeneric',
        displayMessage: knownMessageKey == null ? backendMessage : null,
        messageArgs: knownMessageKey == null && backendMessage != null
            ? [backendMessage]
            : null,
        severity: FailureSeverity.warning,
        developerDetail: detail,
      );
    }

    return Failure(
      category: FailureCategory.unknown,
      messageKey: 'errorsUnknownGeneric',
      severity: FailureSeverity.error,
      developerDetail: detail,
    );
  }

  static Failure _mapFirebaseException(FirebaseException error, String detail) {
    final code = error.code.toLowerCase();

    if (code.contains('invalid-credential') ||
        code.contains('wrong-password') ||
        code.contains('user-not-found') ||
        code.contains('invalid-email')) {
      return Failure(
        category: FailureCategory.auth,
        messageKey: 'errorsAuthInvalidCredentials',
        severity: FailureSeverity.error,
        developerDetail: detail,
      );
    }

    if (code.contains('permission-denied') ||
        code.contains('unauthorized')) {
      return Failure(
        category: FailureCategory.permission,
        messageKey: 'errorsPermissionDenied',
        severity: FailureSeverity.error,
        nextAction: FailureAction.openSettings,
        developerDetail: detail,
      );
    }

    return Failure(
      category: FailureCategory.unknown,
      messageKey: 'errorsUnknownGeneric',
      severity: FailureSeverity.error,
      developerDetail: detail,
    );
  }

  static Failure _mapPlatformException(PlatformException error, String detail) {
    if (error.code.toLowerCase().contains('denied')) {
      return Failure(
        category: FailureCategory.permission,
        messageKey: 'errorsPermissionDenied',
        severity: FailureSeverity.warning,
        nextAction: FailureAction.openSettings,
        developerDetail: detail,
      );
    }

    return Failure(
      category: FailureCategory.unknown,
      messageKey: 'errorsUnknownGeneric',
      severity: FailureSeverity.error,
      developerDetail: detail,
    );
  }

  static String _buildDeveloperDetail(Object error, StackTrace? stackTrace) {
    final buffer = StringBuffer();
    buffer.write('${error.runtimeType}: $error');

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;
      if (statusCode != null) {
        buffer.write('\nstatusCode: $statusCode');
      }
      if (responseData != null) {
        buffer.write('\nresponseData: ${_stringifyForDebug(responseData)}');
      }
    }

    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }

  static String? _extractBackendMessage(dynamic data) {
    if (data is String && data.trim().isNotEmpty) {
      final trimmed = data.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          return _extractBackendMessage(jsonDecode(trimmed));
        } catch (_) {
          return trimmed;
        }
      }
      return trimmed;
    }

    if (data is Map) {
      final preferredKeys = ['message', 'detail', 'error_description', 'error'];
      for (final key in preferredKeys) {
        final extracted = _extractBackendMessage(data[key]);
        if (extracted != null) {
          return extracted;
        }
      }

      for (final entry in data.entries) {
        final extracted = _extractBackendMessage(entry.value);
        if (extracted != null) {
          return extracted;
        }
      }
    }

    if (data is List) {
      for (final item in data) {
        final extracted = _extractBackendMessage(item);
        if (extracted != null) {
          return extracted;
        }
      }
    }

    return null;
  }

  static String _stringifyForDebug(dynamic value) {
    try {
      if (value is String) {
        return value;
      }
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  static String? _mapKnownBackendMessageKey(String? backendMessage) {
    if (backendMessage == null || backendMessage.trim().isEmpty) {
      return null;
    }

    final normalized = backendMessage.trim().toLowerCase();

    if (normalized.contains('insufficient rider wallet balance') ||
        normalized.contains('insufficient wallet balance')) {
      return 'errorsWalletInsufficientBalance';
    }

    return null;
  }

  /// Extracts the `code` field from the backend error body (if present).
  static String? _extractCode(dynamic data) {
    if (data is Map) return data['code'] as String?;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded['code'] as String?;
      } catch (_) {}
    }
    return null;
  }
}
