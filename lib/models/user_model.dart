enum UserRole { owner, staff }

enum UserStatus { active, disabled }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final UserStatus status;

  UserModel({required this.uid, required this.name, required this.email, required this.role, required this.status});

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: (map['role'] as String? ?? 'staff') == 'owner' ? UserRole.owner : UserRole.staff,
      status: (map['status'] as String? ?? 'active') == 'disabled' ? UserStatus.disabled : UserStatus.active,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role == UserRole.owner ? 'owner' : 'staff',
      'status': status == UserStatus.active ? 'active' : 'disabled',
    };
  }
}
