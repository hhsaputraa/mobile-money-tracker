/// Model ringkasan saldo tabungan dan agregasi statistik
class SavingsSummaryModel {
  final double totalBalance;
  final int totalTransactions;
  final int? activeCustomersCount;

  const SavingsSummaryModel({
    required this.totalBalance,
    required this.totalTransactions,
    this.activeCustomersCount,
  });

  /// Format total saldo ke format Rupiah standar Indonesia, misal: Rp 2.500.000
  String get formattedTotalBalance {
    final absAmount = totalBalance.abs().round();
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

  factory SavingsSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawBalance = json['total_balance'] ?? json['total_savings_pool'];
    double balance = 0.0;
    if (rawBalance is num) {
      balance = rawBalance.toDouble();
    } else if (rawBalance != null) {
      balance = double.tryParse(rawBalance.toString()) ?? 0.0;
    }

    final rawCount =
        json['total_transactions'] ?? json['total_transactions_count'];
    int count = 0;
    if (rawCount is num) {
      count = rawCount.toInt();
    } else if (rawCount != null) {
      count = int.tryParse(rawCount.toString()) ?? 0;
    }

    final rawCustomers = json['active_customers_count'];
    int? customers;
    if (rawCustomers is num) {
      customers = rawCustomers.toInt();
    } else if (rawCustomers != null) {
      customers = int.tryParse(rawCustomers.toString());
    }

    return SavingsSummaryModel(
      totalBalance: balance,
      totalTransactions: count,
      activeCustomersCount: customers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_balance': totalBalance,
      'total_transactions': totalTransactions,
      'active_customers_count': activeCustomersCount,
    };
  }
}
