import 'package:rideshare/core/errors/exception_mapper.dart';
import 'package:rideshare/core/errors/failure.dart';

@Deprecated('Use ExceptionMapper.fromError() + ErrorSurface.showFailure() instead. '
    'This class will be removed in a future release.')
class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is Failure) {
      return _categoryFallback(error.category);
    }
    final failure = ExceptionMapper.fromError(error);
    return _categoryFallback(failure.category);
  }

  static String _categoryFallback(FailureCategory category) {
    switch (category) {
      case FailureCategory.network:
        return 'Network error. Please check your connection.';
      case FailureCategory.server:
        return 'Server error. Please try again later.';
      case FailureCategory.auth:
        return 'Authentication error. Please sign in again.';
      case FailureCategory.permission:
        return 'Permission denied.';
      case FailureCategory.validation:
        return 'Invalid input. Please check your data.';
      case FailureCategory.banned:
        return 'Your account has been banned. Please contact support.';
      case FailureCategory.unknown:
        return 'An unexpected error occurred.';
    }
  }
}
