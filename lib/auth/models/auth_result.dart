import 'user_model.dart';

/// Type-safe result wrapper for authentication operations.
/// Simple, explicit, and easy to read without overengineering.
class AuthResult {
  final bool isSuccess;
  final String message;
  final UserModel? user;

  const AuthResult({
    required this.isSuccess,
    required this.message,
    this.user,
  });

  factory AuthResult.success({String message = 'Berhasil', UserModel? user}) {
    return AuthResult(
      isSuccess: true,
      message: message,
      user: user,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult(
      isSuccess: false,
      message: message,
    );
  }
}
