import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';
import 'token_storage.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/notification_service.dart';

// SharedPreferences keys for the client-only cached Google profile (name/photo).
// These are not stored server-side; they only decorate the local profile UI.
const String _kGoogleNameKey = 'google_display_name';
const String _kGooglePhotoKey = 'google_photo_url';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
}

class AuthState {
  final AuthStatus status;
  final String? token;
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  // Client-only cached Google profile (not persisted server-side).
  final String? googleName;
  final String? googlePhotoUrl;

  const AuthState({
    required this.status,
    this.token,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.googleName,
    this.googlePhotoUrl,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    String? googleName,
    String? googlePhotoUrl,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      googleName: googleName ?? this.googleName,
      googlePhotoUrl: googlePhotoUrl ?? this.googlePhotoUrl,
    );
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final apiClient = ref.watch(apiClientProvider);
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(
    tokenStorage: tokenStorage,
    apiClient: apiClient,
    authRepository: authRepository,
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final TokenStorage tokenStorage;
  final ApiClient apiClient;
  final AuthRepository authRepository;

  AuthNotifier({
    required this.tokenStorage,
    required this.apiClient,
    required this.authRepository,
  }) : super(AuthState.initial()) {
    apiClient.onUnauthorized = logout;
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    final token = await tokenStorage.getToken();
    final cachedUser = await tokenStorage.getUser();
    final (googleName, googlePhoto) = await _loadGoogleProfile();

    if (token != null && token.isNotEmpty) {
      // Immediately restore authenticated state from local storage so the user stays
      // logged in persistently and can use the app even offline / with spotty connection.
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        user: cachedUser,
        isLoading: false,
        googleName: googleName,
        googlePhotoUrl: googlePhoto,
      );

      // Attempt to refresh the profile in the background if online
      try {
        final user = await authRepository.getMe();
        await tokenStorage.saveUser(user);
        state = state.copyWith(user: user);
      } catch (_) {
        // If it's a network glitch or server issue, do NOT log out.
        // If the token is truly 401 invalid, ApiClient's interceptor triggers logout() automatically.
      }
    } else {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        isLoading: false,
      );
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final token = await authRepository.login(email: email, password: password);
      await tokenStorage.saveToken(token);
      final user = await authRepository.getMe();
      await tokenStorage.saveUser(user);
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? country,
    String? timezone,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final token = await authRepository.register(
        email: email,
        password: password,
        country: country,
        timezone: timezone,
      );
      await tokenStorage.saveToken(token);
      final user = await authRepository.getMe();
      await tokenStorage.saveUser(user);
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> loginWithGoogle({
    required String idToken,
    String? country,
    String? timezone,
    String? displayName,
    String? photoUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final token = await authRepository.loginWithGoogle(
        idToken: idToken,
        country: country,
        timezone: timezone,
      );
      await tokenStorage.saveToken(token);
      final user = await authRepository.getMe();
      await tokenStorage.saveUser(user);
      // Cache the Google name/photo locally so the profile screen can show them
      // (the backend does not store these).
      await _saveGoogleProfile(displayName, photoUrl);
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        user: user,
        isLoading: false,
        googleName: displayName,
        googlePhotoUrl: photoUrl,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<String?> forgotPassword({required String email}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final token = await authRepository.forgotPassword(email: email);
      state = state.copyWith(isLoading: false);
      return token;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return null;
    }
  }

  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await authRepository.resetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<void> refreshProfile() async {
    if (state.status == AuthStatus.authenticated) {
      try {
        final user = await authRepository.getMe();
        await tokenStorage.saveUser(user);
        state = state.copyWith(user: user);
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    await tokenStorage.clearAll();
    await CacheService.clearAllPersonalCaches();
    await NotificationService.setUser(null);
    await _saveGoogleProfile(null, null); // clear cached Google profile
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: false,
    );
  }

  Future<(String?, String?)> _loadGoogleProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getString(_kGoogleNameKey), prefs.getString(_kGooglePhotoKey));
    } catch (_) {
      return (null, null);
    }
  }

  Future<void> _saveGoogleProfile(String? name, String? photoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name == null || name.isEmpty) {
        await prefs.remove(_kGoogleNameKey);
      } else {
        await prefs.setString(_kGoogleNameKey, name);
      }
      if (photoUrl == null || photoUrl.isEmpty) {
        await prefs.remove(_kGooglePhotoKey);
      } else {
        await prefs.setString(_kGooglePhotoKey, photoUrl);
      }
    } catch (_) {}
  }
}
