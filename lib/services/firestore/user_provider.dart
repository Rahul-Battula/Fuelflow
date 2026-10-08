import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../auth/auth_provider.dart';
import 'user_firestore_service.dart';

final userFirestoreServiceProvider = Provider<UserFirestoreService>((ref) {
  return UserFirestoreService();
});

/// Live profile (name, role, status) of the currently logged-in user.
/// Emits null if logged out or the user document doesn't exist yet.
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final firestoreService = ref.watch(userFirestoreServiceProvider);

  return authState.when(
    data: (firebaseUser) {
      if (firebaseUser == null) {
        return Stream.value(null);
      }
      return firestoreService.watchUser(firebaseUser.uid);
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});
