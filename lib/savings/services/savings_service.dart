import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/auth_result.dart';
import '../../auth/models/user_model.dart';
import '../../core/utils/date_util.dart';
import '../models/savings_summary_model.dart';
import '../models/savings_transaction_model.dart';

/// Service untuk mengelola transaksi tabungan nasabah dan statistik admin di Supabase.
class SavingsService {
  static final SavingsService _instance = SavingsService._internal();
  factory SavingsService() => _instance;
  SavingsService._internal();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // 1. FITUR NASABAH (PENABUNG)
  // ===========================================================================

  /// Mengambil total tabungan milik penabung saat ini
  Future<double> getMyTotalBalance() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return 0.0;

    try {
      // 1. Coba panggil RPC jika sudah tersedia
      try {
        final response = await client.rpc('get_my_savings_summary');
        if (response is Map && response['total_balance'] != null) {
          return (response['total_balance'] as num).toDouble();
        }
      } catch (_) {}

      // 2. Fallback query langsung ke tabel savings_transactions
      final List<dynamic> records = await client
          .from('savings_transactions')
          .select('amount')
          .eq('user_id', userId);

      double total = 0.0;
      for (final item in records) {
        final amt = item['amount'];
        if (amt is num) {
          total += amt.toDouble();
        }
      }
      return total;
    } catch (e) {
      debugPrint('Error getMyTotalBalance: $e');
      return 0.0;
    }
  }

  /// Mengambil seluruh riwayat setoran tabungan milik penabung saat ini
  Future<List<SavingsTransactionModel>> getMyTransactions() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return [];

    try {
      final List<dynamic> response = await client
          .from('savings_transactions')
          .select()
          .eq('user_id', userId)
          .order('transaction_date', ascending: false);

      return response
          .map((json) => SavingsTransactionModel.fromJson(
              Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      debugPrint('Error getMyTransactions: $e');
      return [];
    }
  }

  // ===========================================================================
  // 2. FITUR ADMINISTRATOR (PENGELOLA)
  // ===========================================================================

  /// Mengambil statistik ringkasan total tabungan, total transaksi, dan nasabah aktif
  Future<SavingsSummaryModel> getAdminOverview() async {
    final client = _client;
    if (client == null) {
      return const SavingsSummaryModel(totalBalance: 0, totalTransactions: 0);
    }

    try {
      // 1. Coba panggil RPC
      try {
        final response = await client.rpc('get_admin_savings_summary');
        if (response is Map) {
          return SavingsSummaryModel.fromJson(
              Map<String, dynamic>.from(response));
        }
      } catch (_) {}

      // 2. Fallback query langsung
      final List<dynamic> txRecords =
          await client.from('savings_transactions').select('amount');
      double pool = 0.0;
      for (final item in txRecords) {
        final amt = item['amount'];
        if (amt is num) pool += amt.toDouble();
      }

      final List<dynamic> customerRecords = await client
          .from('profiles')
          .select('id')
          .neq('is_admin', true)
          .neq('is_active', false);

      return SavingsSummaryModel(
        totalBalance: pool,
        totalTransactions: txRecords.length,
        activeCustomersCount: customerRecords.length,
      );
    } catch (e) {
      debugPrint('Error getAdminOverview: $e');
      return const SavingsSummaryModel(totalBalance: 0, totalTransactions: 0);
    }
  }

  /// Mengambil daftar nasabah aktif untuk pilihan dropdown saat admin menginput transaksi
  Future<List<UserModel>> getActiveCustomersList() async {
    final client = _client;
    if (client == null) return [];

    try {
      final List<dynamic> response = await client
          .from('profiles')
          .select()
          .neq('is_admin', true)
          .neq('is_active', false)
          .order('full_name', ascending: true);

      return response
          .map((json) => UserModel.fromJson(Map<String, dynamic>.from(json)))
          .where((u) => !u.isAdmin && u.isActive)
          .toList();
    } catch (e) {
      debugPrint('Error getActiveCustomersList: $e');
      return [];
    }
  }

  /// Mengambil daftar seluruh transaksi tabungan dengan opsi filter per nasabah & pencarian
  Future<List<SavingsTransactionModel>> getAllTransactions({
    String? filterUserId,
    String? searchQuery,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('savings_transactions').select(
            'id, user_id, amount, type, description, transaction_date, created_by, created_at, profiles!savings_transactions_user_id_fkey(full_name, username, email)',
          );

      if (filterUserId != null && filterUserId.isNotEmpty) {
        query = query.eq('user_id', filterUserId);
      }

      final List<dynamic> response =
          await query.order('transaction_date', ascending: false);

      var list = response
          .map((json) => SavingsTransactionModel.fromJson(
              Map<String, dynamic>.from(json)))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        list = list.where((tx) {
          final name = tx.userName?.toLowerCase() ?? '';
          final desc = tx.description?.toLowerCase() ?? '';
          final email = tx.userEmail?.toLowerCase() ?? '';
          return name.contains(q) || desc.contains(q) || email.contains(q);
        }).toList();
      }

      return list;
    } catch (e) {
      // Jika join foreign key nama belum tersedia di schema cache, query fallback tanpa join
      try {
        var query = client.from('savings_transactions').select();
        if (filterUserId != null && filterUserId.isNotEmpty) {
          query = query.eq('user_id', filterUserId);
        }
        final List<dynamic> response =
            await query.order('transaction_date', ascending: false);
        return response
            .map((json) => SavingsTransactionModel.fromJson(
                Map<String, dynamic>.from(json)))
            .toList();
      } catch (err) {
        debugPrint('Error getAllTransactions fallback: $err');
        return [];
      }
    }
  }

  /// Mencatat setoran tabungan baru oleh Admin ke nasabah tertentu
  Future<AuthResult> createTransaction({
    required String userId,
    required double amount,
    String? description,
    DateTime? transactionDate,
  }) async {
    if (userId.trim().isEmpty) {
      return AuthResult.failure('Pilih nasabah terlebih dahulu.');
    }
    if (amount <= 0) {
      return AuthResult.failure('Nominal setoran harus lebih dari 0.');
    }

    final client = _client;
    if (client == null) {
      return AuthResult.failure('Supabase belum diinisialisasi.');
    }

    try {
      final currentAdminId = client.auth.currentUser?.id;
      final txDate =
          DateUtil.toWibIsoString(transactionDate ?? DateUtil.nowInWib());

      await client.from('savings_transactions').insert({
        'user_id': userId.trim(),
        'amount': amount,
        'type': 'deposit',
        'description': description?.trim(),
        'transaction_date': txDate,
        'created_by': currentAdminId,
      });

      return AuthResult.success(
        message: 'Setoran tabungan berhasil dicatat!',
      );
    } catch (e) {
      return AuthResult.failure('Gagal mencatat setoran: $e');
    }
  }

  /// Memperbarui data transaksi setoran oleh Admin
  Future<AuthResult> updateTransaction({
    required String transactionId,
    required double amount,
    String? description,
    DateTime? transactionDate,
  }) async {
    if (transactionId.trim().isEmpty) {
      return AuthResult.failure('ID transaksi tidak valid.');
    }
    if (amount <= 0) {
      return AuthResult.failure('Nominal setoran harus lebih dari 0.');
    }

    final client = _client;
    if (client == null) {
      return AuthResult.failure('Supabase belum diinisialisasi.');
    }

    try {
      final updateData = <String, dynamic>{
        'amount': amount,
        'description': description?.trim(),
        'updated_at': DateUtil.toWibIsoString(DateUtil.nowInWib()),
      };

      if (transactionDate != null) {
        updateData['transaction_date'] =
            DateUtil.toWibIsoString(transactionDate);
      }

      await client
          .from('savings_transactions')
          .update(updateData)
          .eq('id', transactionId.trim());

      return AuthResult.success(
        message: 'Transaksi berhasil diperbarui!',
      );
    } catch (e) {
      return AuthResult.failure('Gagal memperbarui transaksi: $e');
    }
  }

  /// Menghapus catatan transaksi oleh Admin
  Future<AuthResult> deleteTransaction(String transactionId) async {
    if (transactionId.trim().isEmpty) {
      return AuthResult.failure('ID transaksi tidak valid.');
    }

    final client = _client;
    if (client == null) {
      return AuthResult.failure('Supabase belum diinisialisasi.');
    }

    try {
      await client
          .from('savings_transactions')
          .delete()
          .eq('id', transactionId.trim());

      return AuthResult.success(
        message: 'Catatan transaksi berhasil dihapus.',
      );
    } catch (e) {
      return AuthResult.failure('Gagal menghapus transaksi: $e');
    }
  }
}
