import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

/// Handles all reads/writes to the `users` Firestore collection.
class UserFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef => _db.collection('users');

  /// One-time fetch of a user's profile document.
  Future<UserModel?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(uid, doc.data()!);
  }

  /// Live stream of a user's profile — updates automatically if
  /// their role/status changes (e.g. Owner disables them mid-session).
  Stream<UserModel?> watchUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(uid, doc.data()!);
    });
  }

  Future<void> createUser(UserModel user) async {
    await _usersRef.doc(user.uid).set(user.toMap());
  }
}
