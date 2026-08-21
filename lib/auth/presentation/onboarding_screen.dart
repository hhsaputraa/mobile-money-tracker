import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../services/auth_service.dart';

/// Halaman Onboarding & Setup Akun Bergaya Google untuk User Baru
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();

  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Form Step 1: Data Diri
  final _step1FormKey = GlobalKey<FormState>();
  DateTime? _selectedBirthDate;
  final TextEditingController _birthDateDisplayController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Form Step 2: Username
  List<String> _suggestions = [];
  String? _selectedSuggestion;
  bool _isCustomUsername = false;
  final TextEditingController _customUsernameController =
      TextEditingController();

  // Form Step 3: Password Baru
  final _step3FormKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  @override
  void initState() {
    super.initState();
    _initSuggestions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _birthDateDisplayController.dispose();
    _addressController.dispose();
    _customUsernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Membuat rekomendasi username awal berdasarkan nama user
  Future<void> _initSuggestions() async {
    final user = _authService.currentUser.value;
    final baseName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : (user?.email.split('@').first ?? 'user');

    final list = await _authService.generateUsernameSuggestions(
      baseName: baseName,
      birthDate: _selectedBirthDate,
    );

    if (mounted) {
      setState(() {
        _suggestions = list;
        if (list.isNotEmpty &&
            _selectedSuggestion == null &&
            !_isCustomUsername) {
          _selectedSuggestion = list.first;
        }
      });
    }
  }

  /// Membuka dialog pemilih tanggal lahir
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = _selectedBirthDate ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateDisplayController.text =
            '${picked.day} ${_getMonthName(picked.month)} ${picked.year}';
      });
      // Perbarui rekomendasi username dengan data tanggal lahir baru
      _initSuggestions();
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  /// Berpindah ke langkah berikutnya
  void _goToNextStep() {
    setState(() {
      _errorMessage = null;
    });

    if (_currentStep == 0) {
      if (!_step1FormKey.currentState!.validate()) return;
      if (_selectedBirthDate == null) {
        setState(() {
          _errorMessage = 'Silakan pilih tanggal lahir Anda.';
        });
        return;
      }
    } else if (_currentStep == 1) {
      final chosen = _isCustomUsername
          ? _customUsernameController.text.trim()
          : _selectedSuggestion;

      if (chosen == null || chosen.isEmpty) {
        setState(() {
          _errorMessage = 'Silakan pilih atau buat username Anda.';
        });
        return;
      }

      if (_isCustomUsername) {
        final validRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
        if (!validRegex.hasMatch(chosen)) {
          setState(() {
            _errorMessage =
                'Username hanya boleh berisi huruf, angka, titik, atau garis bawah (3-30 karakter).';
          });
          return;
        }
      }
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
      );
      setState(() {
        _currentStep++;
      });
    }
  }

  /// Kembali ke langkah sebelumnya
  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  /// Menyelesaikan seluruh proses Onboarding
  Future<void> _submitOnboarding() async {
    if (!_step3FormKey.currentState!.validate() || _isLoading) return;

    final chosenUsername = _isCustomUsername
        ? _customUsernameController.text.trim()
        : (_selectedSuggestion ?? '');

    if (chosenUsername.isEmpty) {
      setState(() {
        _errorMessage = 'Username tidak boleh kosong.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.completeOnboarding(
      username: chosenUsername,
      address: _addressController.text.trim(),
      birthDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
      newPassword: _newPasswordController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun Anda berhasil disiapkan! Selamat datang.'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
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

  InputDecoration _buildDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
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
    final user = _authService.currentUser.value;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF0F172A),
                ),
                onPressed: _goToPreviousStep,
              )
            : null,
        title: Text(
          'Langkah ${_currentStep + 1} dari 3',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: List.generate(3, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryColor
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),

            // Konten Utama Wizard
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  RepaintBoundary(child: _buildStep1DataDiri(user?.fullName)),
                  RepaintBoundary(child: _buildStep2PilihUsername()),
                  RepaintBoundary(child: _buildStep3PasswordBaru()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// STEP 1: Data Diri (Tanggal Lahir & Alamat)
  Widget _buildStep1DataDiri(String? name) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lengkapi Data Diri',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selamat datang, ${name ?? 'Pengguna'}! Silakan lengkapi data profil awal Anda.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null) ...[
              _buildErrorBanner(_errorMessage!),
              const SizedBox(height: 16),
            ],

            // Input Tanggal Lahir
            const Text(
              'Tanggal Lahir',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickBirthDate,
              borderRadius: BorderRadius.circular(12),
              child: IgnorePointer(
                child: TextFormField(
                  controller: _birthDateDisplayController,
                  decoration: _buildDecoration(
                    hintText: 'Pilih tanggal lahir',
                    prefixIcon: Icons.calendar_today_rounded,
                  ),
                  validator: (val) {
                    if (_selectedBirthDate == null) {
                      return 'Tanggal lahir wajib diisi';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Input Alamat Tempat Tinggal
            const Text(
              'Alamat Tempat Tinggal',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Jl. Contoh No. 123, Kota...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: _defaultBorder,
                enabledBorder: _enabledBorder,
                focusedBorder: _focusedBorder,
                errorBorder: _errorBorder,
                focusedErrorBorder: _focusedErrorBorder,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Alamat wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Tombol Lanjut ke Username
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _goToNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Selanjutnya',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// STEP 2: Pilih / Buat Username (Google-Style)
  Widget _buildStep2PilihUsername() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Username Anda',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih atau buat username',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            _buildErrorBanner(_errorMessage!),
            const SizedBox(height: 16),
          ],

          // Daftar 3 Rekomendasi Username Cerdas
          ..._suggestions.map((suggestion) {
            final isSelected =
                !_isCustomUsername && _selectedSuggestion == suggestion;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isCustomUsername = false;
                    _selectedSuggestion = suggestion;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Opsi 4: Buat username sendiri
          Container(
            decoration: BoxDecoration(
              color: _isCustomUsername
                  ? AppTheme.primaryColor.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isCustomUsername
                    ? AppTheme.primaryColor
                    : const Color(0xFFE2E8F0),
                width: _isCustomUsername ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isCustomUsername = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isCustomUsername
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: _isCustomUsername
                              ? AppTheme.primaryColor
                              : const Color(0xFF94A3B8),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Buat username...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isCustomUsername)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: TextFormField(
                      controller: _customUsernameController,
                      textInputAction: TextInputAction.done,
                      decoration: _buildDecoration(
                        hintText: 'Ketik username',
                        prefixIcon: Icons.alternate_email_rounded,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Tombol Lanjut ke Password
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _goToNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Selanjutnya',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// STEP 3: Atur Password Baru
  Widget _buildStep3PasswordBaru() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buat Kata Sandi Baru',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Buat kata sandi yang kuat dengan minimal 6 karakter.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null) ...[
              _buildErrorBanner(_errorMessage!),
              const SizedBox(height: 16),
            ],

            // Input Password Baru
            const Text(
              'Kata Sandi Baru',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNewPass,
              textInputAction: TextInputAction.next,
              enabled: !_isLoading,
              decoration: _buildDecoration(
                hintText: 'Minimal 6 karakter',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPass = !_obscureNewPass;
                    });
                  },
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Kata sandi baru wajib diisi';
                }
                if (val.length < 6) {
                  return 'Kata sandi minimal 6 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Input Konfirmasi Password
            const Text(
              'Konfirmasi Kata Sandi',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPass,
              textInputAction: TextInputAction.done,
              enabled: !_isLoading,
              onFieldSubmitted: (_) => _submitOnboarding(),
              decoration: _buildDecoration(
                hintText: 'Ulangi kata sandi',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPass = !_obscureConfirmPass;
                    });
                  },
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Konfirmasi kata sandi wajib diisi';
                }
                if (val != _newPasswordController.text) {
                  return 'Konfirmasi kata sandi tidak cocok';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Tombol Selesai
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
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
                        'Selesai & Masuk ke Dashboard',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
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
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
