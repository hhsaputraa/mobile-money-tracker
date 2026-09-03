import '../../core/utils/date_util.dart';

/// Model data untuk transaksi tabungan (setoran nasabah)
class SavingsTransactionModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final double amount;
  final String type; // 'deposit'
  final String? description;
  final DateTime transactionDate;
  final String? createdBy;
  final DateTime? createdAt;

  const SavingsTransactionModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userEmail,
    required this.amount,
    this.type = 'deposit',
    this.description,
    required this.transactionDate,
    this.createdBy,
    this.createdAt,
  });

  /// Format nominal ke format Rupiah standar Indonesia, misal: Rp 1.500.000
  String get formattedAmount {
    final absAmount = amount.abs().round();
    final parts = absAmount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts.length - 1; i >= 0; i--) {
      buffer.write(parts[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    final formatted = buffer.toString().split('').reversed.join('');
    return 'Rp $formatted';
  }

  /// Format tanggal ke format Indonesia zona waktu Asia/Jakarta (WIB), misal: 03 Sep 2026, 14:30 WIB
  String get formattedDate => DateUtil.formatToWib(transactionDate);

  factory SavingsTransactionModel.fromJson(Map<String, dynamic> json) {
    // Ekstraksi profil jika query join dari Supabase
    String? userName = json['user_name']?.toString();
    String? userEmail = json['user_email']?.toString();
    if (json['profiles'] is Map) {
      final profile = json['profiles'] as Map<String, dynamic>;
      userName = profile['full_name']?.toString() ??
          profile['username']?.toString() ??
          userName;
      userEmail = profile['email']?.toString() ?? userEmail;
    }

    final parsedDate = DateUtil.parseDbDate(json['transaction_date']);
    final parsedCreatedAt = json['created_at'] != null
        ? DateUtil.parseDbDate(json['created_at'])
        : null;

    final rawAmount = json['amount'];
    double parsedAmount = 0.0;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else if (rawAmount != null) {
      parsedAmount = double.tryParse(rawAmount.toString()) ?? 0.0;
    }

    return SavingsTransactionModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: userName,
      userEmail: userEmail,
      amount: parsedAmount,
      type: json['type']?.toString() ?? 'deposit',
      description: json['description']?.toString(),
      transactionDate: parsedDate,
      createdBy: json['created_by']?.toString(),
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'amount': amount,
      'type': type,
      'description': description,
      'transaction_date': DateUtil.toWibIsoString(transactionDate),
      'created_by': createdBy,
      'created_at':
          createdAt != null ? DateUtil.toWibIsoString(createdAt!) : null,
    };
  }
}
