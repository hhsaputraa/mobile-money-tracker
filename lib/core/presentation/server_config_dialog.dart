import 'package:flutter/material.dart';

import '../network/api_client.dart';
import '../theme/app_theme.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  final ApiClient _apiClient = ApiClient();
  late final TextEditingController _urlController;

  bool _isTesting = false;
  bool? _testSuccess;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _apiClient.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final inputUrl = _urlController.text.trim();
    if (inputUrl.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _testMessage = null;
    });

    final isHealthy = await _apiClient.testUrl(inputUrl);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = isHealthy;
        _testMessage = isHealthy ? 'Koneksi Sukses!' : 'Gagal terhubung!';
      });
    }
  }

  Future<void> _saveUrl() async {
    final inputUrl = _urlController.text.trim();
    if (inputUrl.isEmpty) return;

    await _apiClient.setBaseUrl(inputUrl);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Base URL berhasil disimpan: ${_apiClient.baseUrl}'),
          backgroundColor: AppTheme.secondaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _resetUrl() async {
    await _apiClient.resetToDefault();
    _urlController.text = _apiClient.baseUrl;

    setState(() {
      _testSuccess = null;
      _testMessage = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Base URL direset ke default: ${_apiClient.baseUrl}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: AppTheme.primaryColor, size: 24),
          SizedBox(width: 10),
          Text(
            'Server Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'URL backend',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
                const SizedBox(height: 14),

              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://xxxx.trycloudflare.com',
                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    tooltip: 'Hapus Teks',
                    onPressed: () => _urlController.clear(),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Tombol Test Koneksi & Reset
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check_rounded, size: 16),
                    label: const Text('Test Koneksi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _resetUrl,
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Reset Default'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              // Feedback Test Status
              if (_testMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _testSuccess == true
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess == true
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        size: 18,
                        color: _testSuccess == true
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _testSuccess == true
                                ? const Color(0xFF15803D)
                                : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
          ),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          onPressed: _saveUrl,
          label: const Text('Simpan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
