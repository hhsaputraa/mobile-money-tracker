import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_util.dart';
import '../models/savings_transaction_model.dart';
import '../services/savings_service.dart';

/// Formatter otomatis pemisah ribuan Rupiah (contoh: 1000000 -> 1.000.000)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Ambil hanya angka
    final cleanDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Format dengan titik setiap 3 digit dari belakang
    final chars = cleanDigits.split('').reversed.toList();
    final buffer = StringBuffer();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }

    final formattedText = buffer.toString().split('').reversed.join('');

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

/// Helper pemformatan ribuan dengan titik
String formatNumberWithDots(int number) {
  final chars = number.toString().split('').reversed.toList();
  final buffer = StringBuffer();
  for (int i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(chars[i]);
  }
  return buffer.toString().split('').reversed.join('');
}

/// Dialog untuk mencatat setoran baru atau memperbarui transaksi tabungan nasabah (Admin only)
class SavingsTransactionDialog extends StatefulWidget {
  final SavingsTransactionModel? existingTransaction;

  const SavingsTransactionDialog({
    super.key,
    this.existingTransaction,
  });

  @override
  State<SavingsTransactionDialog> createState() =>
      _SavingsTransactionDialogState();
}

class _SavingsTransactionDialogState extends State<SavingsTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final SavingsService _savingsService = SavingsService();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  List<UserModel> _customers = [];
  String? _selectedUserId;
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingCustomers = true;
  bool _isSubmitting = false;

  bool get isEditMode => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _initValues() {
    if (isEditMode) {
      final tx = widget.existingTransaction!;
      _selectedUserId = tx.userId;
      _selectedDate = DateUtil.toWib(tx.transactionDate);
      _amountController.text = formatNumberWithDots(tx.amount.toInt());
      _descriptionController.text = tx.description ?? '';
      _updateDateDisplay();
      _isLoadingCustomers = false;
    } else {
      _selectedDate = DateUtil.nowInWib();
      _updateDateDisplay();
      _loadActiveCustomers();
    }
  }

  void _updateDateDisplay() {
    _dateController.text =
        DateUtil.formatToWib(_selectedDate, showTime: false);
  }

  Future<void> _loadActiveCustomers() async {
    setState(() => _isLoadingCustomers = true);
    final list = await _savingsService.getActiveCustomersList();
    if (mounted) {
      setState(() {
        _customers = list;
        _isLoadingCustomers = false;
        if (_customers.isNotEmpty && _selectedUserId == null) {
          _selectedUserId = _customers.first.id;
        }
      });
    }
  }

  Future<void> _openCustomerSearchPicker() async {
    if (_customers.isEmpty) return;

    final selected = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerSearchPickerSheet(
        customers: _customers,
        selectedUserId: _selectedUserId,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedUserId = selected.id;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (picked != null && mounted) {
      final nowWib = DateUtil.nowInWib();
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          nowWib.hour,
          nowWib.minute,
          nowWib.second,
        );
        _updateDateDisplay();
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null || _selectedUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih nasabah terlebih dahulu.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final cleanDigits = _amountController.text.replaceAll('.', '').trim();
    final rawAmount = double.tryParse(cleanDigits);
    if (rawAmount == null || rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal setoran harus lebih dari 0.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    if (isEditMode) {
      final result = await _savingsService.updateTransaction(
        transactionId: widget.existingTransaction!.id,
        amount: rawAmount,
        description: _descriptionController.text.trim(),
        transactionDate: _selectedDate,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result.isSuccess) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } else {
      final result = await _savingsService.createTransaction(
        userId: _selectedUserId!,
        amount: rawAmount,
        description: _descriptionController.text.trim(),
        transactionDate: _selectedDate,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result.isSuccess) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cari data nasabah yang sedang terpilih
    UserModel? selectedCustomer;
    if (_selectedUserId != null && _customers.isNotEmpty) {
      try {
        selectedCustomer =
            _customers.firstWhere((c) => c.id == _selectedUserId);
      } catch (_) {
        selectedCustomer = null;
      }
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEditMode
                          ? Icons.edit_note_rounded
                          : Icons.add_circle_outline_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditMode
                              ? 'Edit Setoran Tabungan'
                              : 'Input Setoran Baru',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          isEditMode
                              ? 'Perbarui nominal atau catatan setoran'
                              : 'Tambahkan saldo tabungan ke nasabah',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 20),

              // 1. Pemilihan Nasabah dengan Fitur Pencarian Cepat
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nasabah (Penabung)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  if (!isEditMode && !_isLoadingCustomers && _customers.isNotEmpty)
                    InkWell(
                      onTap: _openCustomerSearchPicker,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Cari Nasabah',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (isEditMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded,
                          color: Color(0xFF64748B), size: 18),
                      const SizedBox(width: 10),
                      Text(
                        widget.existingTransaction?.userName ??
                            'Nasabah #$_selectedUserId',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_isLoadingCustomers)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor),
                  ),
                )
              else if (_customers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Belum ada nasabah aktif. Tambahkan user terlebih dahulu di menu Kelola Pengguna.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                  ),
                )
              else
                InkWell(
                  onTap: _openCustomerSearchPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.12),
                          foregroundColor: AppTheme.primaryColor,
                          child: Text(
                            selectedCustomer != null &&
                                    selectedCustomer.fullName.isNotEmpty
                                ? selectedCustomer.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedCustomer != null
                                    ? (selectedCustomer.fullName.isNotEmpty
                                        ? selectedCustomer.fullName
                                        : selectedCustomer.username)
                                    : 'Pilih Nasabah...',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (selectedCustomer != null)
                                Text(
                                  '@${selectedCustomer.username} • ${selectedCustomer.email}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.search_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // 2. Input Nominal Uang dengan Separator Rupiah Otomatis
              const Text(
                'Nominal Setoran (Rp)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      'Rp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  hintText: '100.000',
                  hintStyle: const TextStyle(
                      fontSize: 16, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
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
                        color: AppTheme.primaryColor, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nominal setoran wajib diisi';
                  }
                  final clean = val.replaceAll('.', '').trim();
                  final parsed = double.tryParse(clean);
                  if (parsed == null || parsed <= 0) {
                    return 'Nominal harus lebih besar dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 3. Tanggal Transaksi
              const Text(
                'Tanggal Transaksi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.calendar_today_rounded,
                      color: Color(0xFF64748B), size: 18),
                  suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
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
                        color: AppTheme.primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Catatan / Keterangan Setoran
              const Text(
                'Catatan / Keterangan (Opsional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Contoh: Setoran tabungan minggu ke-1 September',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
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
                        color: AppTheme.primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Batal & Simpan
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Batal',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditMode ? 'Simpan Perubahan' : 'Catat Setoran',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom Sheet Pencarian Nasabah Real-time
class _CustomerSearchPickerSheet extends StatefulWidget {
  final List<UserModel> customers;
  final String? selectedUserId;

  const _CustomerSearchPickerSheet({
    required this.customers,
    required this.selectedUserId,
  });

  @override
  State<_CustomerSearchPickerSheet> createState() =>
      _CustomerSearchPickerSheetState();
}

class _CustomerSearchPickerSheetState
    extends State<_CustomerSearchPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = List.from(widget.customers);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = List.from(widget.customers);
      } else {
        _filteredCustomers = widget.customers.where((c) {
          final name = c.fullName.toLowerCase();
          final username = c.username.toLowerCase();
          final email = c.email.toLowerCase();
          return name.contains(query) ||
              username.contains(query) ||
              email.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pilih Nasabah (Penabung)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '${_filteredCustomers.length} Nasabah',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _searchController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Cari nama, username, atau email...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: Color(0xFF64748B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),

          // List Nasabah
          Flexible(
            child: _filteredCustomers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_search_rounded,
                            size: 44, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 10),
                        Text(
                          'Tidak ada nasabah yang cocok dengan "${_searchController.text}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      final isSelected = customer.id == widget.selectedUserId;
                      final name = customer.fullName.isNotEmpty
                          ? customer.fullName
                          : customer.username;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: ListTile(
                          onTap: () => Navigator.of(context).pop(customer),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected
                                ? AppTheme.primaryColor
                                : const Color(0xFFF1F5F9),
                            foregroundColor: isSelected
                                ? Colors.white
                                : const Color(0xFF334155),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            '@${customer.username} • ${customer.email}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.primaryColor, size: 20)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
