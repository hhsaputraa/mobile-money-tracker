import 'package:flutter/material.dart';

import '../../auth/models/user_model.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../user_management/presentation/user_management_screen.dart';
import '../models/dashboard_stats_model.dart';
import '../services/dashboard_service.dart';

/// Screen utama Dashboard Money Tracker terhubung ke Supabase
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();

  DashboardStatsModel _stats = const DashboardStatsModel();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final stats = await _dashboardService.getDashboardStats();
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: _authService.currentUser,
      builder: (context, user, _) {
        final isAdmin = user?.isAdmin ?? false;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text(AppConstants.appName),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Keluar',
                onPressed: _handleLogout,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Header Ucapan Selamat Datang
                  _WelcomeHeader(user: user),
                  const SizedBox(height: 24),

                  // 2. Banner Kelola Pengguna (Hanya Tampil untuk Administrator)
                  if (isAdmin) ...[
                    _AdminUserManagementBanner(),
                    const SizedBox(height: 20),
                  ],

                  // 3. Kartu Status Arsitektur Backend
                  _BackendStatusCard(status: _stats.backendStatus),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sub-widget Header Ucapan Selamat Datang (Stateless, modular & reusable)
class _WelcomeHeader extends StatelessWidget {
  final UserModel? user;

  const _WelcomeHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName =
        user?.fullName.isNotEmpty == true ? user!.fullName : (user?.email ?? 'User');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 48,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Selamat Datang, $displayName!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user?.email ?? 'Terhubung ke Supabase Cloud',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

/// Sub-widget Banner Tombol Kelola Pengguna khusus Admin
class _AdminUserManagementBanner extends StatelessWidget {
  const _AdminUserManagementBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UserManagementScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kelola Pengguna',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tambah user baru & pantau akun karyawan',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sub-widget Kartu Status Arsitektur Backend
class _BackendStatusCard extends StatelessWidget {
  final BackendArchitectureStatus status;

  const _BackendStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status.isHealthy ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Status Arsitektur Backend',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Provider', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              Text(
                status.provider,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Autentikasi', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              Text(
                status.authentication,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Protokol', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              Text(
                status.protocol,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
