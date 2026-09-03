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

  /// Mengambil daftar semua profil pengguna aktif dari tabel `profiles` (khusus Admin).
  /// Pengguna berstatus is_active = false disaring sehingga tidak muncul di antarmuka.
  Future<List<UserModel>> fetchUsersList() async {
    final client = _client;
    if (client == null) return [];

    try {
      final List<dynamic> response = await client
          .from('profiles')
          .select()
          .neq('is_active', false)
          .order('created_at', ascending: false);

      return response
          .map((json) => UserModel.fromJson(Map<String, dynamic>.from(json)))
          .where((user) => user.isActive)
          .toList();
    } catch (e) {
      debugPrint('Error fetching users list: $e');
      return [];
    }
  }

  /// Menghapus (soft delete / menonaktifkan) user oleh Admin
  Future<AuthResult> adminDeleteUser(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return AuthResult.failure('ID pengguna tidak valid.');
    }

    final client = _client;
    if (client == null) {
      return AuthResult.failure('Supabase belum diinisialisasi.');
    }

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId != null && currentUserId == cleanUserId) {
      return AuthResult.failure('Admin tidak dapat menghapus akunnya sendiri.');
    }

    try {
      try {
        await client.rpc(
          'admin_soft_delete_user',
          params: {'target_user_id': cleanUserId},
        );
      } on PostgrestException catch (pe) {
        if (pe.message.contains('admin_soft_delete_user') &&
            pe.message.contains('schema cache')) {
          // Fallback update langsung ke tabel profiles jika migrasi belum dimuat ke cache
          await client
              .from('profiles')
              .update({'is_active': false})
              .eq('id', cleanUserId);
        } else {
          rethrow;
        }
      }

      return AuthResult.success(
        message: 'Pengguna berhasil dihapus.',
      );
    } on PostgrestException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Gagal menghapus pengguna: $e');
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
      if (e.message.contains('admin_create_user') &&
          e.message.contains('schema cache')) {
        return AuthResult.failure(
          'Fungsi database "admin_create_user" belum terpasang di Supabase. Jalankan script SQL di folder supabase/migrations/ pada Supabase SQL Editor.',
        );
      }
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Gagal membuat pengguna: $e');
    }
  }

  /// Mereset password user oleh Admin (mengeset password baru sementara & mewajibkan ubah password saat login)
  Future<AuthResult> adminResetUserPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = newPassword.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return AuthResult.failure('Email dan password baru wajib diisi.');
    }

    if (cleanPassword.length < 6) {
      return AuthResult.failure('Password baru minimal 6 karakter.');
    }

    final client = _client;
    if (client == null) {
      return AuthResult.failure('Supabase belum diinisialisasi.');
    }

    try {
      try {
        await client.rpc(
          'admin_set_user_reset_code',
          params: {
            'target_email': cleanEmail,
            'code': cleanPassword,
          },
        );
      } on PostgrestException catch (pe) {
        if (pe.message.contains('admin_set_user_reset_code') &&
            pe.message.contains('schema cache')) {
          // Fallback ke admin_reset_user_password jika belum migrasi
          await client.rpc(
            'admin_reset_user_password',
            params: {
              'target_email': cleanEmail,
              'new_password': cleanPassword,
            },
          );
        } else {
          rethrow;
        }
      }

      return AuthResult.success(
        message: 'Kode reset password berhasil dibuat.',
      );
    } on PostgrestException catch (e) {
      if ((e.message.contains('admin_set_user_reset_code') ||
              e.message.contains('admin_reset_user_password')) &&
          e.message.contains('schema cache')) {
        return AuthResult.failure(
          'Fungsi database reset belum terpasang di Supabase. Jalankan script SQL di folder supabase/migrations/ pada Supabase SQL Editor.',
        );
      }
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Gagal mereset password: $e');
    }
  }

  /// Alias khusus untuk menyimpan kode reset 6 digit
  Future<AuthResult> adminSetUserResetCode({
    required String email,
    required String resetCode,
  }) async {
    return adminResetUserPassword(email: email, newPassword: resetCode);
  }
}
