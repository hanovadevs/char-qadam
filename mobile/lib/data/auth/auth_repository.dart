import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient: apiClient);
});

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  /// Register a new user account.
  /// Returns the access token on success.
  /// Throws [Exception] with user-friendly message on error.
  Future<String> register({
    required String email,
    required String password,
    String? country,
    String? timezone,
  }) async {
    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
      };
      if (country != null) body['country'] = country;
      if (timezone != null) body['timezone'] = timezone;

      final response = await apiClient.post(
        '/auth/register',
        data: body,
      );
      final data = response.data as Map<String, dynamic>;
      return data['access_token'] as String;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Authenticate with email and password.
  /// Returns the access token on success.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await apiClient.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return data['access_token'] as String;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Exchange a Google OAuth ID Token (or Supabase OAuth Token) for a Qadam JWT.
  Future<String> loginWithGoogle({
    required String idToken,
    String? country,
    String? timezone,
  }) async {
    try {
      final body = <String, dynamic>{
        'id_token': idToken,
      };
      if (country != null) body['country'] = country;
      if (timezone != null) body['timezone'] = timezone;

      final response = await apiClient.post(
        '/auth/google',
        data: body,
      );
      final data = response.data as Map<String, dynamic>;
      return data['access_token'] as String;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Unexpected Google authentication error: $e');
    }
  }

  /// Get profile of the current authenticated user.
  Future<UserModel> getMe() async {
    try {
      final response = await apiClient.get('/auth/me');
      final data = response.data as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Request a password reset token for given email.
  Future<String?> forgotPassword({required String email}) async {
    try {
      final response = await apiClient.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
      final data = response.data as Map<String, dynamic>;
      return data['reset_token'] as String?;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Failed to request password reset: $e');
    }
  }

  /// Reset password using a valid reset token.
  Future<String> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await apiClient.post(
        '/auth/reset-password',
        data: {
          'reset_token': resetToken,
          'new_password': newPassword,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return data['message'] as String? ?? 'Password updated successfully';
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  Exception _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return Exception('Network error: Unable to connect to server');
    }

    final data = error.response?.data;
    if (data is Map<String, dynamic> && data.containsKey('detail')) {
      final detail = data['detail'];
      if (detail is String) {
        return Exception(detail);
      } else if (detail is List && detail.isNotEmpty) {
        final msg = detail.first['msg'] ?? 'Validation error';
        return Exception(msg.toString());
      }
    }
    
    if (error.response?.statusCode == 401) {
      return Exception('Invalid email or password');
    } else if (error.response?.statusCode == 409) {
      return Exception('An account with this email already exists');
    }

    return Exception('Server error (${error.response?.statusCode ?? "Unknown"})');
  }
}
