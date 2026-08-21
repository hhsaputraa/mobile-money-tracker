import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'create_user_dialog.dart';

/// Halaman Manajemen Pengguna khusus Administrator
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _filterUsers();
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    final users = await _authService.fetchUsersList();

    if (mounted) {
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
      _filterUsers();
    }
  }

  void _filterUsers() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers.where((u) {
          final name = u.fullName.toLowerCase();
          final email = u.email.toLowerCase();
          final username = u.username.toLowerCase();
          return name.contains(query) ||
              email.contains(query) ||
              username.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _openCreateUserDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateUserDialog(),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: _loadUsers,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Info Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama, email, atau username...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ${_allUsers.length} Pengguna',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Text(
                      '• Hak Akses Admin',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: AppTheme.primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _UserCardTile(key: ValueKey(user.id), user: user);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateUserDialog,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Tambah User',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Pengguna',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Klik tombol Tambah User di bawah untuk mendaftarkan akun baru.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget kartu user terisolasi dengan RepaintBoundary agar scroll 60 FPS mulus di HP kentang
class _UserCardTile extends StatelessWidget {
  final UserModel user;

  const _UserCardTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = user.fullName.isNotEmpty
        ? user.fullName
            .split(' ')
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join()
        : 'U';

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: CircleAvatar(
            backgroundColor: user.isAdmin
                ? const Color(0xFFFEF3C7)
                : AppTheme.primaryColor.withValues(alpha: 0.1),
            foregroundColor: user.isAdmin
                ? const Color(0xFFD97706)
                : AppTheme.primaryColor,
            child: Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName : user.username,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (user.isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'User',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Username: @${user.username}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
