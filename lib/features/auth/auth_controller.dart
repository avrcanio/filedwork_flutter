import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import 'auth_models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.loading = false,
    this.error,
  });

  final AuthStatus status;
  final AuthUser? user;
  final bool loading;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  static const initial = AuthState(status: AuthStatus.unknown);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._client, this._storage) : super(AuthState.initial) {
    _client.onUnauthorized = _onUnauthorized;
    _bootstrap();
  }

  final ApiClient _client;
  final SecureStorage _storage;

  Future<void> _bootstrap() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      await _loadProfile();
    } catch (_) {
      final id = await _storage.readUserId();
      final name = await _storage.readUserName();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: id ?? 0,
          username: name ?? '',
          firstName: name ?? '',
        ),
      );
    }
  }

  Future<void> _loadProfile() async {
    final res = await _client.dio.get<Map<String, dynamic>>(ApiConfig.profilePath);
    final user = AuthUser.fromJson(res.data ?? const {});
    await _storage.saveUser(id: user.id, name: user.displayName);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
    );
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        ApiConfig.loginPath,
        data: {'username': username, 'password': password},
      );
      final data = res.data ?? const {};
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Token nije primljen.');
      }
      final userJson = Map<String, dynamic>.from(data['user'] as Map? ?? const {});
      if (data['fieldwork'] != null) {
        userJson['fieldwork'] = data['fieldwork'];
      }
      final user = AuthUser.fromJson(userJson);
      await _storage.saveToken(token);
      await _storage.saveUser(id: user.id, name: user.displayName);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        loading: false,
      );
      return true;
    } catch (error) {
      final message = error is DioException && error.response?.statusCode == 401
          ? 'Neispravno korisničko ime ili lozinka.'
          : ApiClient.describeError(error);
      state = state.copyWith(loading: false, error: message);
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _onUnauthorized() {
    _storage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});
