import '../../core/network/api_client.dart';
import '../models/dashboard_stats_model.dart';

/// Service khusus untuk mengelola data dan status bisnis di Dashboard
class DashboardService {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Mengambil informasi status backend dan statistik Dashboard
  Future<DashboardStatsModel> getDashboardStats() async {
    final isHealthy = await _apiClient.checkHealth();
    return DashboardStatsModel(
      backendStatus: BackendArchitectureStatus(isHealthy: isHealthy),
    );
  }
}
