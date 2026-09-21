import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/api/api_client.dart';
import 'package:rideshare/core/errors/failure.dart';
import 'package:rideshare/core/services/error_localizations.dart';

/// What a user is actually told when a request fails.
///
/// The regression these guard against: services used to catch the real error
/// and rethrow a flat "please try again", so an unreachable backend and a
/// mistyped password produced the same sentence. Retrying is useless advice
/// when the server cannot be reached at all.
void main() {
  Future<String> messageFor(WidgetTester tester, Object error) async {
    final failure = ApiClient.mapError(error);
    late String message;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('ar'),
        delegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            message = ErrorLocalizations.resolveFailure(context, failure);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return message;
  }

  group('the user is told what actually went wrong', () {
    testWidgets('an unreachable backend is named as a connection problem',
        (tester) async {
      final error = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/auth/send-otp'),
      );

      expect(ApiClient.mapError(error).category, FailureCategory.network);
      final message = await messageFor(tester, error);
      expect(message, contains('الاتصال'));
    });

    testWidgets('a server fault is not blamed on the connection',
        (tester) async {
      final options = RequestOptions(path: '/auth/send-otp');
      final error = DioException(
        type: DioExceptionType.badResponse,
        response: Response(statusCode: 500, requestOptions: options),
        requestOptions: options,
      );

      final failure = ApiClient.mapError(error);
      expect(failure.category, FailureCategory.server);
      final message = await messageFor(tester, error);
      expect(message, contains('الخادم'));
    });

    testWidgets('offline and server-down do not read the same', (tester) async {
      final options = RequestOptions(path: '/auth/send-otp');
      final offline = await messageFor(
        tester,
        DioException(
          type: DioExceptionType.connectionError,
          requestOptions: options,
        ),
      );
      final serverDown = await messageFor(
        tester,
        DioException(
          type: DioExceptionType.badResponse,
          response: Response(statusCode: 500, requestOptions: options),
          requestOptions: options,
        ),
      );

      expect(offline, isNot(equals(serverDown)));
    });

    testWidgets('a network failure offers retry; a bad password does not',
        (tester) async {
      final retryable = ApiClient.mapError(
        DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/x'),
        ),
      );
      expect(retryable.nextAction, FailureAction.retry);

      final options = RequestOptions(path: '/auth/login');
      final badPassword = ApiClient.mapError(
        DioException(
          type: DioExceptionType.badResponse,
          response: Response(statusCode: 401, requestOptions: options),
          requestOptions: options,
        ),
      );
      expect(badPassword.nextAction, isNot(FailureAction.retry));
    });
  });
}
