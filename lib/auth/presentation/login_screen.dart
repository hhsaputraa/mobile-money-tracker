import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';

/// Halaman Login utama untuk Money Tracker / Arus Kas
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final TextEditingController _usernameOrEmailController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Memproses login ke Supabase
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final input = _usernameOrEmailController.text.trim();
    final password = _passwordController.text.trim();

    final result = await _authService.login(
      email: input,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      final mustChange = result.user?.mustChangePassword ?? false;
      if (mustChange) {
        // Alihkan ke layar Onboarding Setup Akun (Data Diri, Pilih Username, Reset Password)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        // Langsung masuk ke Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  static final OutlineInputBorder _defaultBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
  );
  static final OutlineInputBorder _enabledBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
  );
  static final OutlineInputBorder _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
  );
  static final OutlineInputBorder _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
  );
  static final OutlineInputBorder _focusedErrorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
  );

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF64748B)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _defaultBorder,
      enabledBorder: _enabledBorder,
      focusedBorder: _focusedBorder,
      errorBorder: _errorBorder,
      focusedErrorBorder: _focusedErrorBorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const _LoginBackground(),
          SafeArea(
            child: Column(
              children: [
                // 1. Header
                const _LoginHeader(),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // 2. Form Login Utama
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 20,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ARUS KAS',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'MASUK',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Pesan Error jika login gagal
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFCA5A5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 20,
                                      color: Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFF991B1B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Input Username / Email
                            const Text(
                              'Username atau Email',
                              style: TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameOrEmailController,
                              textInputAction: TextInputAction.next,
                              enabled: !_isLoading,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 15,
                              ),
                              decoration: _buildInputDecoration(
                                hintText: 'Username atau email dari Admin',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Username atau email tidak boleh kosong';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Input Password
                            const Text(
                              'Password',
                              style: TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              enabled: !_isLoading,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 15,
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              decoration: _buildInputDecoration(
                                hintText: 'Password dari Admin',
                                prefixIcon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Password tidak boleh kosong';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Tombol Masuk
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Masuk',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Info Keterangan Admin
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Akun dibuat oleh Admin. Saat pertama kali login, Anda akan diminta mengatur password baru.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Footer
                const _LoginFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header login terpisah sebagai widget const
class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'ARUS KAS',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '• Money Tracker',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer login terpisah sebagai widget const
class _LoginFooter extends StatelessWidget {
  const _LoginFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        '© MONEY TRACKER • SUPABASE',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Widget background gambar terisolasi dengan RepaintBoundary & Overlay tipis
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  static const String _imageUrl =
      'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1080&q=80';

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.expand(),
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: child,
              );
            },
          ),
          Container(color: Colors.white.withValues(alpha: 0.93)),
        ],
      ),
    );
  }
}
