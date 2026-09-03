import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/core/utils/date_util.dart';
import 'package:moneytracker/savings/models/savings_summary_model.dart';
import 'package:moneytracker/savings/models/savings_transaction_model.dart';
import 'package:moneytracker/savings/presentation/savings_transaction_dialog.dart';

void main() {
  group('SavingsTransactionModel Tests', () {
    test('fromJson parses complete transaction data with Rupiah formatting', () {
      final json = {
        'id': 'tx-uuid-1',
        'user_id': 'user-uuid-101',
        'user_name': 'Ahmad Fauzi',
        'user_email': 'ahmad@example.com',
        'amount': 2500000,
        'type': 'deposit',
        'description': 'Setoran tabungan awal',
        'transaction_date': '2026-09-03T10:00:00Z',
        'created_by': 'admin-uuid-1',
        'created_at': '2026-09-03T10:00:00Z',
      };

      final tx = SavingsTransactionModel.fromJson(json);

      expect(tx.id, 'tx-uuid-1');
      expect(tx.userId, 'user-uuid-101');
      expect(tx.userName, 'Ahmad Fauzi');
      expect(tx.userEmail, 'ahmad@example.com');
      expect(tx.amount, 2500000.0);
      expect(tx.formattedAmount, 'Rp 2.500.000');
      expect(tx.type, 'deposit');
      expect(tx.description, 'Setoran tabungan awal');
      expect(tx.formattedDate, contains('WIB'));
    });

    test('fromJson handles joined profiles nested map', () {
      final json = {
        'id': 'tx-uuid-2',
        'user_id': 'user-uuid-102',
        'amount': 750000.50,
        'profiles': {
          'full_name': 'Siti Rahma',
          'email': 'siti@example.com',
        },
        'transaction_date': '2026-09-01T08:30:00Z',
      };

      final tx = SavingsTransactionModel.fromJson(json);

      expect(tx.id, 'tx-uuid-2');
      expect(tx.userName, 'Siti Rahma');
      expect(tx.userEmail, 'siti@example.com');
      expect(tx.amount, 750000.50);
      expect(tx.formattedAmount, 'Rp 750.001');
    });

    test('toJson serializes correctly with WIB timezone offset', () {
      final tx = SavingsTransactionModel(
        id: 'tx-uuid-3',
        userId: 'user-uuid-103',
        userName: 'Budi',
        amount: 500000,
        transactionDate: DateTime.utc(2026, 9, 3, 4, 30),
        description: 'Setoran mingguan',
      );

      final json = tx.toJson();

      expect(json['id'], 'tx-uuid-3');
      expect(json['user_id'], 'user-uuid-103');
      expect(json['amount'], 500000.0);
      expect(json['description'], 'Setoran mingguan');
      expect(json['transaction_date'], contains('+07:00'));
    });
  });

  group('SavingsSummaryModel Tests', () {
    test('fromJson parses user summary correctly', () {
      final json = {
        'total_balance': 3500000,
        'total_transactions': 5,
      };

      final summary = SavingsSummaryModel.fromJson(json);

      expect(summary.totalBalance, 3500000.0);
      expect(summary.formattedTotalBalance, 'Rp 3.500.000');
      expect(summary.totalTransactions, 5);
      expect(summary.activeCustomersCount, isNull);
    });

    test('fromJson parses admin overview correctly', () {
      final json = {
        'total_savings_pool': 150000000,
        'total_transactions_count': 120,
        'active_customers_count': 45,
      };

      final summary = SavingsSummaryModel.fromJson(json);

      expect(summary.totalBalance, 150000000.0);
      expect(summary.formattedTotalBalance, 'Rp 150.000.000');
      expect(summary.totalTransactions, 120);
      expect(summary.activeCustomersCount, 45);
    });
  });

  group('Rupiah Formatter Tests', () {
    test('ThousandsSeparatorInputFormatter formats digits with thousand dots', () {
      final formatter = ThousandsSeparatorInputFormatter();

      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(text: '1000000');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '1.000.000');
    });
  });

  group('DateUtil Asia/Jakarta (WIB, UTC+7) Tests', () {
    test('toWib converts UTC time to UTC+7 correctly', () {
      final utcTime = DateTime.utc(2026, 9, 3, 4, 30); // 04:30 UTC
      final wibTime = DateUtil.toWib(utcTime);

      expect(wibTime.hour, 11); // 04:30 + 7 hours = 11:30
      expect(wibTime.minute, 30);
      expect(wibTime.day, 3);
    });

    test('formatToWib formats date with WIB label', () {
      final utcTime = DateTime.utc(2026, 9, 3, 4, 30);
      final formatted = DateUtil.formatToWib(utcTime);

      expect(formatted, '03 Sep 2026, 11:30 WIB');
    });

    test('formatToWib without time formats date only', () {
      final utcTime = DateTime.utc(2026, 9, 3, 4, 30);
      final formatted = DateUtil.formatToWib(utcTime, showTime: false);

      expect(formatted, '03 Sep 2026');
    });

    test('toWibIsoString produces valid ISO 8601 with +07:00 offset', () {
      final utcTime = DateTime.utc(2026, 9, 3, 4, 30);
      final isoString = DateUtil.toWibIsoString(utcTime);

      expect(isoString, '2026-09-03T11:30:00+07:00');
    });

    test('parses exact DB format 2026-09-03 11:41:40.292398+07 and matches DB hour', () {
      // 1. Format dari DB dengan offset +07
      final txDb = SavingsTransactionModel.fromJson({
        'id': '1',
        'user_id': 'u1',
        'amount': 100000,
        'transaction_date': '2026-09-03 11:41:40.292398+07',
      });
      expect(txDb.formattedDate, '03 Sep 2026, 11:41 WIB');

      // 2. Format ISO dengan offset +07:00
      final txIso = SavingsTransactionModel.fromJson({
        'id': '2',
        'user_id': 'u1',
        'amount': 100000,
        'transaction_date': '2026-09-03T11:41:40.292398+07:00',
      });
      expect(txIso.formattedDate, '03 Sep 2026, 11:41 WIB');

      // 3. Format tanpa offset
      final txWithoutTz = SavingsTransactionModel.fromJson({
        'id': '3',
        'user_id': 'u1',
        'amount': 100000,
        'transaction_date': '2026-09-03 11:41:40.292398',
      });
      expect(txWithoutTz.formattedDate, '03 Sep 2026, 11:41 WIB');

      // 4. Format UTC murni (04:41 UTC -> 11:41 WIB)
      final txUtc = SavingsTransactionModel.fromJson({
        'id': '4',
        'user_id': 'u1',
        'amount': 100000,
        'transaction_date': '2026-09-03T04:41:40.292398Z',
      });
      expect(txUtc.formattedDate, '03 Sep 2026, 11:41 WIB');
    });
  });
}
