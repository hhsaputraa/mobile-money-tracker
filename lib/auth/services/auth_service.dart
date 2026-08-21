import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth_result.dart';
import '../models/user_model.dart';

/// Service untuk mengelola autentikasi dan onboarding pengguna menggunakan Supabase Auth.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _initAuthListener();
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// State reaktif user dan token login
  final ValueNotifier<UserModel?> currentUser = ValueNotifier<UserModel?>(null);
  final ValueNotifier<String?> currentToken = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isCheckingAuth = ValueNotifier<bool>(true);

  /// Status apakah user sedang login
  bool get isAuthenticated {
    final client = _client;
    if (client == null) return false;
    return client.auth.currentSession != null &&
        !client.auth.currentSession!.isExpired;
  }

  /// Inisialisasi listener auth state change dari Supabase
  void _initAuthListener() {
    try {
      _client?.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null) {
          currentToken.value = session.accessToken;
          currentUser.value = await _enrichUserModelWithProfile(session.user);
        } else {
          currentToken.value = null;
          currentUser.value = null;
        }
        isCheckingAuth.value = false;
      });
    } catch (_) {
      isCheckingAuth.value = false;
    }
  }

  /// Memuat sesi yang tersimpan saat aplikasi dibuka
  Future<void> initSession() async {
    isCheckingAuth.value = true;
    try {
      final client = _client;
      final session = client?.auth.currentSession;
      if (session != null && !session.isExpired) {
        currentToken.value = session.accessToken;
        currentUser.value = await _enrichUserModelWithProfile(session.user);
      } else {
        currentToken.value = null;
        currentUser.value = null;
      }
    } catch (_) {
      currentToken.value = null;
      currentUser.value = null;
    } finally {
      isCheckingAuth.value = false;
    }
  }

  /// Memperkaya data user dengan mengambil status is_admin & profil dari tabel profiles
  Future<UserModel> _enrichUserModelWithProfile(User user) async {
    UserModel userModel = UserModel.fromSupabaseUser(user);
    final client = _client;
    if (client == null) return userModel;

    try {
      final profile = await client
          .from('profiles')
          .select('is_admin, full_name, username, address, birth_date')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        final isAdminProfile = profile['is_admin'] == true ||
            profile['is_admin']?.toString().toLowerCase() == 'true';
        final fullNameProfile = profile['full_name']?.toString();
        final usernameProfile = profile['username']?.toString();
        final addressProfile = profile['address']?.toString();

        DateTime? birthDateProfile;
        if (profile['birth_date'] != null) {
          try {
            birthDateProfile = DateTime.parse(profile['birth_date'].toString());
          } catch (_) {}
        }

        userModel = UserModel(
          id: user.id,
          username: (usernameProfile != null && usernameProfile.isNotEmpty)
              ? usernameProfile
              : userModel.username,
          fullName: (fullNameProfile != null && fullNameProfile.isNotEmpty)
              ? fullNameProfile
              : userModel.fullName,
          email: user.email ?? '',
          address: addressProfile ?? userModel.address,
          birthDate: birthDateProfile ?? userModel.birthDate,
          isAdmin: isAdminProfile || userModel.isAdmin,
          isActive: true,
          mustChangePassword: userModel.mustChangePassword,
          lastLoginAt: user.lastSignInAt,
        );
      }
    } catch (_) {}

    return userModel;
  }

  /// Melakukan login via Supabase Auth dengan username atau email & password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final cleanInput = email.trim();
    final cleanPassword = password.trim();

    if (cleanInput.isEmpty || cleanPassword.isEmpty) {
      return AuthResult.failure('Username/Email dan password wajib diisi.');
    }

    final client = _client;
    if (client == null) {
      return AuthResult.failure('Supabase belum diinisialisasi.');
    }

    String authEmail = cleanInput;

    // Jika input berupa username tanpa '@', cari email aslinya di tabel profiles
    if (!cleanInput.contains('@')) {
      try {
        final profile = await client
            .from('profiles')
            .select('email')
            .eq('username', cleanInput.toLowerCase())
            .maybeSingle();

        if (profile != null && profile['email'] != null) {
          authEmail = profile['email'].toString();
        } else {
          authEmail = '$cleanInput@moneytracker.app';
        }
      } catch (_) {
        authEmail = '$cleanInput@moneytracker.app';
      }
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: authEmail,
        password: cleanPassword,
      );

      final user = response.user;
      if (user != null) {
        final userModel = await _enrichUserModelWithProfile(user);
        currentUser.value = userModel;
        currentToken.value = response.session?.accessToken;

        return AuthResult.success(
          message: 'Login berhasil.',
          user: userModel,
        );
      }

      return AuthResult.failure('Login gagal. Pengguna tidak ditemukan.');
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthErrorMessage(e.message));
    } catch (e) {
      return AuthResult.failure('Terjadi kendala saat login: $e');
    }
  }


  /// Mengecek ketersediaan username di tabel profiles
  Future<bool> checkUsernameAvailable(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return false;

    final client = _client;
    if (client == null) return true;

    try {
      final currentUserId = client.auth.currentUser?.id;
      final query = client
          .from('profiles')
          .select('id')
          .eq('username', clean);

      final List<dynamic> records = await query;
      if (records.isEmpty) return true;

      // Jika username milik akun user sendiri, tetap valid
      if (currentUserId != null && records.first['id'] == currentUserId) {
        return true;
      }
      return false;
    } catch (_) {
      // Jika tabel profiles belum ada atau terjadi error jaringan, anggap valid
      return true;
    }
  }

  /// Menghasilkan 3 saran username cerdas (Google-style) berdasarkan nama & tanggal lahir
  Future<List<String>> generateUsernameSuggestions({
    required String baseName,
    DateTime? birthDate,
  }) async {
    final cleanBase = baseName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final name = cleanBase.isEmpty ? 'user' : cleanBase;

    final List<String> rawCandidates = [];

    if (birthDate != null) {
      final yearShort = birthDate.year.toString().substring(2);
      final day = birthDate.day.toString().padLeft(2, '0');
      final month = birthDate.month.toString().padLeft(2, '0');

      rawCandidates.add('$name$yearShort');     // contoh: budi98
      rawCandidates.add('$name$day$month');      // contoh: budi1505
      rawCandidates.add('${name}_id');          // contoh: budi_id
    } else {
      rawCandidates.add('$name.kas');
      rawCandidates.add('${name}_id');
      rawCandidates.add('${name}88');
    }

    final availableSuggestions = await Future.wait(
      rawCandidates.map((candidate) async {
        final isFree = await checkUsernameAvailable(candidate);
        if (isFree) {
          return candidate;
        } else {
          return '${candidate}_${DateTime.now().millisecond % 100}';
        }
      }),
    );

    return availableSuggestions.take(3).toList();
  }

  /// Menyelesaikan proses onboarding data diri, pilihan username, dan password baru
  Future<AuthResult> completeOnboarding({
    required String username,
    required String address,
    required DateTime birthDate,
    required String newPassword,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanAddress = address.trim();
    final cleanPassword = newPassword.trim();

    if (cleanUsername.isEmpty || cleanAddress.isEmpty || cleanPassword.isEmpty) {
      return AuthResult.failure('Semua data onboarding wajib diisi.');
    }

    final validUsernameRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
    if (!validUsernameRegex.hasMatch(cleanUsername)) {
      return AuthResult.failure(
        'Username hanya boleh berisi huruf, angka, titik, atau garis bawah (3-30 karakter).',
      );
    }

    if (cleanPassword.length < 6) {
      return AuthResult.failure('Password baru minimal 6 karakter.');
    }

    final client = _client;
    if (client == null) {
      return AuthResult.failure('Supabase belum diinisialisasi.');
    }

    // 1. Cek ketersediaan username
    final isAvailable = await checkUsernameAvailable(cleanUsername);
    if (!isAvailable) {
      return AuthResult.failure('Username "$cleanUsername" sudah digunakan. Silakan pilih yang lain.');
    }

    try {
      final birthDateStr = birthDate.toIso8601String().split('T').first;

      // 2. Update user di Supabase Auth (Password & Metadata)
      final authResponse = await client.auth.updateUser(
        UserAttributes(
          password: cleanPassword,
          data: {
            'username': cleanUsername,
            'address': cleanAddress,
            'birth_date': birthDateStr,
            'password_changed': true,
            'is_onboarded': true,
            'must_change_password': false,
          },
        ),
      );

      final user = authResponse.user;
      if (user == null) {
        return AuthResult.failure('Gagal memperbarui profil di Supabase Auth.');
      }

      // 3. Simpan/Sinkronkan ke tabel `profiles`
      try {
        await client.from('profiles').upsert({
          'id': user.id,
          'username': cleanUsername,
          'email': user.email ?? '',
          'address': cleanAddress,
          'birth_date': birthDateStr,
        });
      } catch (_) {
        // Abaikan jika tabel profiles belum memiliki kolom tambahan
      }

      final userModel = UserModel.fromSupabaseUser(user);
      currentUser.value = userModel;

      return AuthResult.success(
        message: 'Onboarding berhasil diselesaikan!',
        user: userModel,
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthErrorMessage(e.message));
    } catch (e) {
      return AuthResult.failure('Terjadi kendala saat onboarding: $e');
    }
  }

  /// Memperbarui password user di Supabase (fallback reset password mandiri)
  Future<AuthResult> updatePassword({required String newPassword}) async {
    final cleanPassword = newPassword.trim();
    if (cleanPassword.isEmpty || cleanPassword.length < 6) {
      return AuthResult.failure('Password baru minimal 6 karakter.');
    }

    final client = _client;
    if (client == null) {
      return AuthResult.failure('Supabase belum diinisialisasi.');
    }

    try {
      final response = await client.auth.updateUser(
        UserAttributes(
          password: cleanPassword,
          data: {
            'must_change_password': false,
            'password_changed': true,
            'is_first_login': false,
          },
        ),
      );

      final user = response.user;
      if (user != null) {
        final userModel = UserModel.fromSupabaseUser(user);
        currentUser.value = userModel;
        return AuthResult.success(
          message: 'Password berhasil diperbarui.',
          user: userModel,
        );
      }

      return AuthResult.failure('Gagal memperbarui password.');
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthErrorMessage(e.message));
    } catch (e) {
      return AuthResult.failure('Terjadi kendala saat update password: $e');
    }
  }

  /// Mengambil daftar semua user terdaftar dari tabel profiles (khusus Admin)
  Future<List<UserModel>> fetchUsersList() async {
    final client = _client;
    if (client == null) return [];

    try {
      final List<dynamic> response = await client
          .from('profiles')
          .select('id, username, full_name, email, is_admin, must_change_password, is_onboarded, created_at')
          .order('created_at', ascending: false);

      return response
          .map((json) => UserModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (_) {
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
      return AuthResult.failure('Nama, email/username, dan password wajib diisi.');
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

      final userMap = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
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

  /// Logout dari Supabase
  Future<void> logout() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {}
    currentToken.value = null;
    currentUser.value = null;
  }

  /// Menerjemahkan pesan error umum dari Supabase Auth ke Bahasa Indonesia yang ramah
  String _mapAuthErrorMessage(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Username/Email atau password salah. Silakan periksa kembali.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Periksa kotak masuk/spam email Anda.';
    }
    if (msg.contains('user already registered')) {
      return 'Email ini sudah terdaftar. Silakan langsung login.';
    }
    if (msg.contains('password should be at least')) {
      return 'Kata sandi harus minimal 6 karakter.';
    }
    return message;
  }
}

