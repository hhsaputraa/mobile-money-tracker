import 'package:flutter/material.dart';

import '../../auth/models/user_model.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../savings/models/savings_summary_model.dart';
import '../../savings/models/savings_transaction_model.dart';
import '../../savings/presentation/savings_transaction_dialog.dart';
import '../../savings/services/savings_service.dart';
import '../../user_management/presentation/user_management_screen.dart';

/// Halaman Dashboard Utama: Beradaptasi secara cerdas untuk Penabung (Nasabah) dan Administrator
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final SavingsService _savingsService = SavingsService();

  // State untuk Nasabah (Penabung)
  SavingsSummaryModel _customerSummary = const SavingsSummaryModel(
    totalBalance: 0,
    totalTransactions: 0,
  );
  List<SavingsTransactionModel> _customerTransactions = [];
  bool _isBalanceHidden = false;

  // State untuk Administrator
  SavingsSummaryModel _adminSummary = const SavingsSummaryModel(
    totalBalance: 0,
    totalTransactions: 0,
  );
  List<SavingsTransactionModel> _adminTransactions = [];
  List<UserModel> _activeCustomers = [];
  String? _selectedFilterUserId;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final currentUser = _authService.currentUser.value;
    final isAdmin = currentUser?.isAdmin ?? false;

    if (isAdmin) {
      final results = await Future.wait([
        _savingsService.getAdminOverview(),
        _savingsService.getActiveCustomersList(),
        _savingsService.getAllTransactions(
          filterUserId: _selectedFilterUserId,
          searchQuery: _searchController.text,
        ),
      ]);

      if (mounted) {
        setState(() {
          _adminSummary = results[0] as SavingsSummaryModel;
          _activeCustomers = results[1] as List<UserModel>;
          _adminTransactions = results[2] as List<SavingsTransactionModel>;
          _isLoading = false;
        });
      }
    } else {
      final balance = await _savingsService.getMyTotalBalance();
      final txList = await _savingsService.getMyTransactions();

      if (mounted) {
        setState(() {
          _customerSummary = SavingsSummaryModel(
            totalBalance: balance,
            totalTransactions: txList.length,
          );
          _customerTransactions = txList;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Konfirmasi Keluar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari aplikasi?',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  // ===========================================================================
  // MODAL ACTIONS UNTUK ADMIN
  // ===========================================================================

  Future<void> _openCreateTransactionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SavingsTransactionDialog(),
    );

    if (result == true) {
      _loadDashboardData();
    }
  }

  Future<void> _openEditTransactionDialog(SavingsTransactionModel tx) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SavingsTransactionDialog(existingTransaction: tx),
    );

    if (result == true) {
      _loadDashboardData();
    }
  }

  Future<void> _confirmDeleteTransaction(SavingsTransactionModel tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Hapus Transaksi?', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Hapus catatan setoran ${tx.formattedAmount} untuk nasabah "${tx.userName ?? 'Nasabah'}"? Saldo nasabah akan otomatis disesuaikan.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _savingsService.deleteTransaction(tx.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: res.isSuccess
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
          ),
        );
        if (res.isSuccess) {
          _loadDashboardData();
        }
      }
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
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Segarkan',
                onPressed: _loadDashboardData,
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Keluar',
                onPressed: _handleLogout,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadDashboardData,
            color: AppTheme.primaryColor,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : isAdmin
                ? _buildAdminDashboard(user)
                : _buildCustomerDashboard(user),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. TAMPILAN DASHBOARD NASABAH (PENABUNG)
  // ===========================================================================

  Widget _buildCustomerDashboard(UserModel? user) {
    final displayName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : (user?.username ?? 'Penabung');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Sapaan
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang, $displayName!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Kartu Saldo Tabungan Utama (Sleek Emerald Card)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL SALDO TABUNGAN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() => _isBalanceHidden = !_isBalanceHidden);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Icon(
                            _isBalanceHidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isBalanceHidden ? 'Tampilkan' : 'Sembunyikan',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _isBalanceHidden
                    ? 'Rp •••••••••'
                    : _customerSummary.formattedTotalBalance,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${_customerSummary.totalTransactions} kali setoran masuk',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Section Title: Riwayat Setoran
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Riwayat Setoran Tabungan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_customerTransactions.isEmpty)
          _buildEmptyTransactionState(
            message: 'Belum ada riwayat setoran tabungan. Setoran yang dicatat oleh Admin akan langsung terlihat di sini.',
          )
        else
          ..._customerTransactions.map(
            (tx) => _buildTransactionCard(tx, isAdmin: false),
          ),
      ],
    );
  }

  // ===========================================================================
  // 2. TAMPILAN DASHBOARD ADMINISTRATOR (PENGELOLA)
  // ===========================================================================

  Widget _buildAdminDashboard(UserModel? user) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Sapaan Admin
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Color(0xFFD97706),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang, ${user?.fullName ?? 'Admin'}!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    'Panel Pengelola Tabungan Nasabah',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Kartu Ringkasan Admin
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL TABUNGAN SELURUH NASABAH',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _adminSummary.formattedTotalBalance,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_adminSummary.totalTransactions} Total Transaksi',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_adminSummary.activeCustomersCount ?? 0} Nasabah Aktif',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tombol Aksi Cepat Admin
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openCreateTransactionDialog,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Input Setoran',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.people_outline_rounded, size: 20),
                label: const Text(
                  'Kelola User',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Section Title: Kelola Transaksi
        const Text(
          'Daftar Transaksi Tabungan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),

        // Filter Nasabah Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedFilterUserId,
              isExpanded: true,
              hint: const Text(
                'Semua Nasabah',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Semua Nasabah (Tampilkan Semua)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                ..._activeCustomers.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(
                      '${c.fullName.isNotEmpty ? c.fullName : c.username} (@${c.username})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedFilterUserId = val);
                _loadDashboardData();
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Search Bar
        TextField(
          controller: _searchController,
          onSubmitted: (_) => _loadDashboardData(),
          decoration: InputDecoration(
            hintText: 'Cari catatan atau nama...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF64748B),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _loadDashboardData();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_adminTransactions.isEmpty)
          _buildEmptyTransactionState(
            message: 'Belum ada transaksi yang sesuai. Klik tombol "+ Input Setoran" di atas untuk menambahkan.',
          )
        else
          ..._adminTransactions.map(
            (tx) => _buildTransactionCard(tx, isAdmin: true),
          ),
      ],
    );
  }

  // ===========================================================================
  // REUSABLE COMPONENTS
  // ===========================================================================

  Widget _buildTransactionCard(
    SavingsTransactionModel tx, {
    required bool isAdmin,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.arrow_downward_rounded,
            color: Color(0xFF16A34A),
            size: 20,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '+ ${tx.formattedAmount}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16A34A),
              ),
            ),
            Text(
              tx.formattedDate,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAdmin && tx.userName != null)
                Text(
                  'Nasabah: ${tx.userName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              Text(
                tx.description?.isNotEmpty == true
                    ? tx.description!
                    : 'Setoran Tabungan',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        trailing: isAdmin
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    tooltip: 'Edit Transaksi',
                    onPressed: () => _openEditTransactionDialog(tx),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                    tooltip: 'Hapus Transaksi',
                    onPressed: () => _confirmDeleteTransaction(tx),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyStateComponent({required String message}) {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Transaksi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionState({required String message}) {
    return _buildEmptyStateComponent(message: message);
  }
}
