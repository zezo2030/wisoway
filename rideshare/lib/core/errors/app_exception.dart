class AppException implements Exception {
  final String message;
  final Object? originalError;
  StackTrace? stackTrace;

  AppException({
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  final bool isOffline;

  NetworkException({
    required super.message,
    super.originalError,
    super.stackTrace,
    this.isOffline = false,
  });
}

class ServerException extends AppException {
  final int? statusCode;

  ServerException({
    required super.message,
    super.originalError,
    super.stackTrace,
    this.statusCode,
  });
}

class ValidationException extends AppException {
  final String? backendMessage;

  ValidationException({
    required super.message,
    super.originalError,
    super.stackTrace,
    this.backendMessage,
  });
}

class AuthException extends AppException {
  final bool isSessionExpired;

  AuthException({
    required super.message,
    super.originalError,
    super.stackTrace,
    this.isSessionExpired = false,
  });
}

class PermissionException extends AppException {
  PermissionException({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

class UnknownException extends AppException {
  UnknownException({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}
