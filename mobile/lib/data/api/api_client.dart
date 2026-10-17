import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/env_config.dart';
import '../auth/token_storage.dart';
import '../auth/device_identity.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(tokenStorage: tokenStorage);
});

/// Central HTTP Client built on [Dio].
///
/// Features:
/// - Base URL from [EnvConfig]
/// - Automatic Bearer Authorization header injection
/// - Global error interceptor handling 401 Unauthorized (invalid/expired JWT)
class ApiClient {
  late final Dio _dio;
  final TokenStorage tokenStorage;
  final DeviceIdentity deviceIdentity;

  void Function()? onUnauthorized;

  ApiClient({required this.tokenStorage, DeviceIdentity? deviceIdentity})
    : deviceIdentity = deviceIdentity ?? DeviceIdentity() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            options.headers['X-Device-ID'] = await this.deviceIdentity.getKey();
          } catch (_) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Device identity unavailable. Please restart Stepsy.',
              ),
            );
            return;
          }
          final token = await tokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final currentToken = await tokenStorage.getToken();
          if ((error.response?.statusCode == 401 ||
                  error.response?.statusCode == 426) &&
              currentToken != null &&
              error.requestOptions.headers['Authorization'] ==
                  'Bearer $currentToken') {
            // Token expired or invalid — clear token, cached user, and invoke callback
            await tokenStorage.clearAll();
            onUnauthorized?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  // Convenience methods
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
