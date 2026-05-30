import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/local_storage.dart';
import '../../domain/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    tryRestoreSession();
  }

  Future<void> tryRestoreSession() async {
    final token = LocalStorage.getToken();
    if (token == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final response = await ApiClient.get('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('user')) {
          final user = UserModel.fromJson(data['user']);
          await LocalStorage.saveUserProfile(user.toJson());
          state = AuthState(user: user, isAuthenticated: true);
        } else {
          await logout();
        }
      } else {
        await logout();
      }
    } catch (e) {
      // Offline fallback: load cached user profile from Hive if available
      final cachedProfile = LocalStorage.getUserProfile();
      if (cachedProfile != null) {
        state = AuthState(
          user: UserModel.fromJson(cachedProfile),
          isAuthenticated: true,
          errorMessage: 'Offline Mode: Loaded Cached Profile',
        );
      } else {
        state = AuthState(errorMessage: 'Connection failed');
      }
    }
  }

  /// Authenticates using a Firebase Token. In development, we can pass a mock token prefixed with `mock_`
  Future<bool> loginWithGoogle(String idToken, {String? referralCode}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await ApiClient.post('/auth/google', {
        'idToken': idToken,
        if (referralCode != null) 'referralCode': referralCode,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('token') && data.containsKey('user')) {
          final token = data['token'];
          final user = UserModel.fromJson(data['user']);

          await LocalStorage.saveToken(token);
          await LocalStorage.saveUserProfile(user.toJson());

          state = AuthState(user: user, isAuthenticated: true);
          return true;
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Invalid response format from authentication server',
          );
          return false;
        }
      } else {
        String errorMsg = 'Authentication failed';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('message')) {
            errorMsg = data['message'];
          }
        } catch (_) {}
        state = state.copyWith(
          isLoading: false,
          errorMessage: errorMsg,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Local Developer Quick Bypass Sign-In (Creates a mock account with a seed username)
  Future<bool> loginMock(String username, {String? referralCode}) async {
    // Generate a mock firebase-like token prefix recognized by our dev-mode backend
    final mockIdToken = 'mock_${username.trim().toLowerCase()}';
    return await loginWithGoogle(mockIdToken, referralCode: referralCode);
  }

  Future<void> updateCoins(int delta) async {
    if (state.user != null) {
      final updatedUser = state.user!.copyWith(coins: state.user!.coins + delta);
      state = state.copyWith(user: updatedUser);
      await LocalStorage.saveUserProfile(updatedUser.toJson());
    }
  }

  Future<void> logout() async {
    await LocalStorage.clearToken();
    await LocalStorage.clearUserProfile();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
