import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/auth_result.dart';
import '../../auth/models/user_model.dart';

/// Service khusus untuk mengelola fitur User Management (Daftar User & Tambah User oleh Admin).
/// Terpisah dari AuthService untuk mematuhi Single Responsibility Principle (SRP).
class UserManagementService {
  static final UserManagementService _instance = UserManagementService._internal();
  factory UserManagementService() => _instance;
  UserManagementService._internal();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Mengambil daftar semua profil pengguna dari tabel `profiles` (khusus Admin)
  Future<List<UserModel>> fetchUsersList() async {
    final client = _client;
    if (client == null) return [];

    try {
      final List<dynamic> response = await client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      return response
          .map((json) => UserModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching users list: $e');
      return [];
    }
  }

  /// Membuat user baru oleh Admin via Supabase RPC tanpa memutuskan sesi login Admin
  Future<AuthResult> adminCreateUser({
    required String email,
    required String password,
    required String fullName,
    bool isAdmin = false,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();
    final cleanFullName = fullName.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty || cleanFullName.isEmpty) {
      return AuthResult.failure(
        'Nama, email/username, dan password wajib diisi.',
      );
    }

    if (cleanPassword.length < 6) {
      return AuthResult.failure('Password minimal 6 karakter.');
    }

    final client = _client;
    if (client == null) {
      return AuthResult.failure('Supabase belum diinisialisasi.');
    }

    try {
      final response = await client.rpc(
        'admin_create_user',
        params: {
          'new_email': cleanEmail,
          'new_password': cleanPassword,
          'new_full_name': cleanFullName,
          'is_admin_flag': isAdmin,
        },
      );

      final userMap = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};

      final createdUser = UserModel(
        id: userMap['id']?.toString() ?? '',
        username: userMap['username']?.toString() ?? cleanEmail.split('@').first,
        fullName: cleanFullName,
        email: userMap['email']?.toString() ?? cleanEmail,
        isAdmin: isAdmin,
        mustChangePassword: true,
      );

      return AuthResult.success(
        message: 'Pengguna baru berhasil dibuat!',
        user: createdUser,
      );
    } on PostgrestException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Gagal membuat pengguna: $e');
    }
  }
}
