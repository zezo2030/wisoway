import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_interceptor.dart';
import 'api_endpoints.dart';
import '../errors/exception_mapper.dart';
import '../errors/failure.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  
  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(AuthInterceptor());
    if (kDebugMode) {
      debugPrint('ApiClient baseUrl=${ApiEndpoints.baseUrl}');
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Dio get dio => _dio;

  /// [cancelToken] lets a caller abort an in-flight request — used by the
  /// location search screen so a superseded keystroke stops consuming the
  /// provider budget instead of merely having its response ignored.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      return response.data;
    } catch (e, st) {
      throw ExceptionMapper.fromError(e, st);
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } catch (e, st) {
      throw ExceptionMapper.fromError(e, st);
    }
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      return response.data;
    } catch (e, st) {
      throw ExceptionMapper.fromError(e, st);
    }
  }

  Future<dynamic> delete(String path, {dynamic data}) async {
    try {
      final response = await _dio.delete(path, data: data);
      return response.data;
    } catch (e, st) {
      throw ExceptionMapper.fromError(e, st);
    }
  }

  static Failure mapError(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;
    return ExceptionMapper.fromError(error, stackTrace);
  }
}
