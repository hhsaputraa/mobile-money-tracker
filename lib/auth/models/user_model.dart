import 'package:supabase_flutter/supabase_flutter.dart';

class UserModel {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String? address;
  final DateTime? birthDate;
  final bool isAdmin;
  final bool isActive;
  final bool mustChangePassword;
  final String? lastLoginAt;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.address,
    this.birthDate,
    this.isAdmin = false,
    this.isActive = true,
    this.mustChangePassword = false,
    this.lastLoginAt,
  });

  /// Factory untuk membuat UserModel dari objek User bawaan Supabase
  factory UserModel.fromSupabaseUser(User user) {
    final metadata = user.userMetadata ?? {};
    final fullName =
        metadata['full_name']?.toString() ??
        metadata['name']?.toString() ??
        user.email?.split('@').first ??
        'User';
    final username =
        metadata['username']?.toString() ??
        user.email?.split('@').first ??
        'user';
    final isAdmin =
        metadata['is_admin'] == true ||
        metadata['role']?.toString().toLowerCase() == 'admin';

    DateTime? parsedBirthDate;
    if (metadata['birth_date'] != null) {
      try {
        parsedBirthDate = DateTime.parse(metadata['birth_date'].toString());
      } catch (_) {}
    }

    final isPasswordChanged = metadata['password_changed'] == true;
    final isExplicitlyExempt = metadata['must_change_password'] == false;

    // User baru yang belum ganti password/onboarding (!isPasswordChanged) wajib masuk ke OnboardingScreen
    // Admin tidak pernah masuk ke OnboardingScreen
    final mustChange = !isAdmin && (!isPasswordChanged && !isExplicitlyExempt);
    final isActive = metadata['is_active'] == null
        ? true
        : (metadata['is_active'] == true ||
            metadata['is_active'] == 1 ||
            metadata['is_active'] == 'true');

    return UserModel(
      id: user.id,
      username: username,
      fullName: fullName,
      email: user.email ?? '',
      address: metadata['address']?.toString(),
      birthDate: parsedBirthDate,
      isAdmin: isAdmin,
      isActive: isActive,
      mustChangePassword: mustChange,
      lastLoginAt: user.lastSignInAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final isPasswordChanged = json['password_changed'] == true;
    final isExplicitlyExempt = json['must_change_password'] == false;
    final mustChange =
        json['must_change_password'] == true ||
        (!isPasswordChanged && !isExplicitlyExempt);

    DateTime? parsedBirthDate;
    if (json['birth_date'] != null) {
      try {
        parsedBirthDate = DateTime.parse(json['birth_date'].toString());
      } catch (_) {}
    }

    final isActive = json['is_active'] == null
        ? true
        : (json['is_active'] == true ||
            json['is_active'] == 1 ||
            json['is_active'] == 'true');

    return UserModel(
      id: json['id']?.toString() ?? json['id_app_users']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString(),
      birthDate: parsedBirthDate,
      isAdmin: json['is_admin'] == true || json['is_admin'] == 7,
      isActive: isActive,
      mustChangePassword: mustChange,
      lastLoginAt: json['last_login_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'address': address,
      'birth_date': birthDate?.toIso8601String(),
      'is_admin': isAdmin,
      'is_active': isActive,
      'must_change_password': mustChangePassword,
      'last_login_at': lastLoginAt,
    };
  }
}
