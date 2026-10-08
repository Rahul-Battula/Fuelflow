import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

/// Provides a single shared instance of AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Live stream of the current Firebase user (null = logged out).
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});
