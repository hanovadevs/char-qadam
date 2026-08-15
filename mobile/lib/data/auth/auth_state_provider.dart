import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';
import 'token_storage.dart';

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

  const AuthState({
    required this.status,
    this.token,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
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
    if (token != null && token.isNotEmpty) {
      try {
        final user = await authRepository.getMe();
        state = AuthState(
          status: AuthStatus.authenticated,
          token: token,
          user: user,
          isLoading: false,
        );
      } catch (_) {
        // Token invalid or network failure on startup
        await tokenStorage.deleteToken();
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          isLoading: false,
        );
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

  Future<void> refreshProfile() async {
    if (state.status == AuthStatus.authenticated) {
      try {
        final user = await authRepository.getMe();
        state = state.copyWith(user: user);
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    await tokenStorage.deleteToken();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: false,
    );
  }
}
