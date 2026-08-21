import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../services/user_management_service.dart';

/// Dialog Form untuk Admin membuat akun user baru
class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final UserManagementService _userManagementService = UserManagementService();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController(text: 'Admin123!');

  bool _isAdmin = false;
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _createdUser;
  String? _plainPassword;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _generateRandomPassword() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final pass = 'Pass${(now % 9000) + 1000}!';
    setState(() {
      _passwordController.text = pass;
    });
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final password = _passwordController.text.trim();
    final result = await _userManagementService.adminCreateUser(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      password: password,
      isAdmin: _isAdmin,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess && result.user != null) {
      setState(() {
        _createdUser = result.user;
        _plainPassword = password;
      });
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  void _copyCredentials() {
    if (_createdUser == null || _plainPassword == null) return;
    final text = '''
Halo ${_createdUser!.fullName},
Berikut adalah kredensial akun Money Tracker Anda:

• Username: ${_createdUser!.username}
• Email: ${_createdUser!.email}
• Password Awal: $_plainPassword

Saat pertama kali login, Anda akan diminta untuk mengatur password baru & profil.
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kredensial berhasil disalin ke clipboard!'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 460),
        child: _createdUser != null
            ? _buildSuccessView()
            : _buildFormView(),
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tambah Pengguna',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Buat akun baru untuk user/karyawan',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Input Nama Lengkap
            const Text(
              'Nama Lengkap',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _fullNameController,
              decoration: _inputDecoration(
                hintText: 'Contoh: Budi Santoso',
                prefixIcon: Icons.badge_outlined,
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Nama lengkap wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Input Email / Username
            const Text(
              'Email atau Username Awal',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              decoration: _inputDecoration(
                hintText: 'budi@gmail.com atau budi',
                prefixIcon: Icons.alternate_email_rounded,
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Email/Username wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Input Password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Password Awal',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                TextButton(
                  onPressed: _generateRandomPassword,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Acak Password',
                    style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _passwordController,
              decoration: _inputDecoration(
                hintText: 'Minimal 6 karakter',
                prefixIcon: Icons.lock_outline_rounded,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Password wajib diisi';
                if (val.trim().length < 6) return 'Minimal 6 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Switch Admin Role
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF64748B), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hak Akses Admin',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Izinkan user mengelola pengguna lain',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isAdmin,
                    activeTrackColor: AppTheme.primaryColor,
                    onChanged: (val) => setState(() => _isAdmin = val),
                  ),

                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Buat Pengguna',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFF0FDF4),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Pengguna Berhasil Dibuat!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Silakan salin kredensial berikut dan bagikan ke pengguna.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Nama', _createdUser!.fullName),
              const Divider(height: 16),
              _infoRow('Username / Email', _createdUser!.email),
              const Divider(height: 16),
              _infoRow('Password Awal', _plainPassword ?? ''),
              const Divider(height: 16),
              _infoRow('Role', _createdUser!.isAdmin ? 'Administrator' : 'Pengguna Regular'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyCredentials,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Salin Info'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Selesai'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hintText, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }
}
