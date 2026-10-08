import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth — the only file that talks
/// directly to the Firebase Auth SDK.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of auth state changes (null when logged out).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return credential.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
