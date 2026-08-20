import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/user_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRepository(apiClient: apiClient);
});

class ProfileRepository {
  final ApiClient apiClient;

  ProfileRepository({required this.apiClient});

  /// Update user profile details via PATCH /users/me.
  Future<UserModel> updateProfile({
    String? country,
    String? timezone,
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (country != null) body['country'] = country;
      if (timezone != null) body['timezone'] = timezone;
      if (password != null) body['password'] = password;

      final response = await apiClient.patch('/users/me', data: body);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail']?.toString() ?? 'Failed to update profile');
    } catch (e) {
      throw Exception('Unexpected error updating profile: $e');
    }
  }

  /// Soft-delete user account via DELETE /users/me.
  Future<void> deleteAccount() async {
    try {
      await apiClient.delete('/users/me');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail']?.toString() ?? 'Failed to delete account');
    } catch (e) {
      throw Exception('Unexpected error deleting account: $e');
    }
  }
}
