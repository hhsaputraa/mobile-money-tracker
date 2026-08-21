export '../../auth/models/user_model.dart';

/// Request Payload untuk membuat Pengguna baru oleh Admin
class CreateUserRequest {
  final String fullName;
  final String email;
  final String password;
  final bool isAdmin;

  const CreateUserRequest({
    required this.fullName,
    required this.email,
    required this.password,
    this.isAdmin = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'email': email,
      'password': password,
      'is_admin': isAdmin,
    };
  }
}
