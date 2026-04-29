import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rideshare/core/errors/exception_mapper.dart';
import 'package:rideshare/core/errors/failure.dart';

void main() {
  group('ExceptionMapper.fromError', () {
    group('DioException mapping', () {
      test('connectionTimeout → network timeout failure', () {
        final error = DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final failure = ExceptionMapper.fromError(error);

        expect(failure.category, FailureCategory.network);
        expect(failure.messageKey, 'errorsNetworkTimeout');
        expect(failure.severity, FailureSeverity.warning);
        expect(failure.nextAction, FailureAction.retry);
        expect(failure.developerDetail, contains('DioException'));
      });

      test('receiveTimeout → network timeout failure', () {
        final error = DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final failure = ExceptionMapper.fromError(error);

        expect(failure.category, FailureCategory.network);
        expect(failure.messageKey, 'errorsNetworkTimeout');
      });

      test('connectionError → network offline failure', () {
        final error = DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: '/test'),
        );

        final failure = ExceptionMapper.fromError(error);

        expect(failure.category, FailureCategory.network);
        expect(failure.messageKey, 'errorsNetworkOffline');
        expect(failure.nextAction, FailureAction.retry);
      });

      test('HTTP 401 → auth session expired failure', () {
        final error = DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: '/test'),
          ),
          requestOptions: RequestOptions(path: '/test'),
        );

        final failure = ExceptionMapper.fromError(error);

        expect(failure.category, FailureCategory.auth);
        expect(failure.messageKey, 'errorsAuthSessionExpired');
        expect(failure.severity, FailureSeverity.error);
        expect(failure.nextAction, FailureAction.reauthenticate);
      });

      test('HTTP 500 → server error failure', () {
        final error = DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: '/test'),
          ),
          requestOptions: RequestOptions(path: '/test'),
        );

        final failure = ExceptionMapper.fromError(error);

        expect(failure.category, FailureCategory.server);
        expect(failure.messageKey, 'errorsServerGeneric');
        expect(failure.nextAction, FailureAction.retry);
      });

      test('HTTP 502 → server error failure', () {
        final error = DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 502,
            requestOptions: RequestOptions(path: '/test'),
          ),
          requestOptions: RequestOptions(path: '/test'),
        );

        final failure = ExceptionMapper.fromError(error);

        expect(failure.category, FailureCategory.server);
        expect(failure.messageKey, 'errorsServerGeneric');
      });

      test('HTTP 400 with business-rule body → validation failure', () {
        final error = DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 400,
            data: {'message': 'This booking already exists.'},
            requestOptions: RequestOptions(path: '/test'),
          ),
          requestOptions: RequestOptions(path: '/test'),
        );

        final failure = ExceptionMapper.fromError(error);

        expect(failure.category, FailureCategory.validation);
        expect(failure.messageKey, 'errorsValidationGeneric');
        expect(failure.messageArgs, isNotNull);
        expect(failure.messageArgs!.first, 'This booking already exists.');
      });

      test('HTTP 400 with list message → validation failure with first item', () {
        final error = DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 400,
            data: {
              'message': ['Field is required', 'Invalid format'],
            },
            requestOptions: RequestOptions(path: '/test'),
          ),
          requestOptions: RequestOptions(path: '/test'),
        );

        final failure = ExceptionMapper.fromError(error);

        expect(failure.category, FailureCategory.validation);
        expect(failure.messageArgs!.first, 'Field is required');
      });
    });

    group('FirebaseException mapping', () {
      // Note: FirebaseException requires a real plugin, so we test via
      // the code-matching logic indirectly. We simulate by creating
      // a fake that matches the code structure.
      // Since FirebaseException is from firebase_core, we test what we can.

      test('FormatException → validation failure', () {
        final failure = ExceptionMapper.fromError(
          const FormatException('Invalid JSON'),
        );

        expect(failure.category, FailureCategory.validation);
        expect(failure.messageKey, 'errorsValidationGeneric');
      });

      test('TimeoutException → network timeout failure', () {
        final failure = ExceptionMapper.fromError(
          TimeoutException('Connection timed out', const Duration(seconds: 15)),
        );

        expect(failure.category, FailureCategory.network);
        expect(failure.messageKey, 'errorsNetworkTimeout');
        expect(failure.nextAction, FailureAction.retry);
      });

      test('PlatformException with denied code → permission failure', () {
        final error = PlatformException(
          code: 'PERMISSION_DENIED',
          message: 'Notification permission denied',
        );

        final failure = ExceptionMapper.fromError(error);

        expect(failure.category, FailureCategory.permission);
        expect(failure.messageKey, 'errorsPermissionDenied');
        expect(failure.nextAction, FailureAction.openSettings);
      });

      test('generic Object → unknown failure', () {
        final failure = ExceptionMapper.fromError(
          Exception('something broke'),
          StackTrace.current,
        );

        expect(failure.category, FailureCategory.unknown);
        expect(failure.messageKey, 'errorsUnknownGeneric');
        expect(failure.severity, FailureSeverity.error);
        expect(failure.nextAction, FailureAction.retry);
        expect(failure.developerDetail, isNotEmpty);
      });
    });

    group('developerDetail', () {
      test('includes original exception type', () {
        final failure = ExceptionMapper.fromError(
          Exception('test'),
        );

        expect(failure.developerDetail, contains('_Exception'));
      });

      test('includes stack trace when provided', () {
        final st = StackTrace.current;
        final failure = ExceptionMapper.fromError(
          Exception('test'),
          st,
        );

        expect(failure.developerDetail, contains(st.toString()));
      });
    });
  });
}
