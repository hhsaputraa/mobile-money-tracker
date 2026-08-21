/// Model data untuk informasi status backend dan statistik Dashboard
class BackendArchitectureStatus {
  final String provider;
  final String authentication;
  final String protocol;
  final bool isHealthy;

  const BackendArchitectureStatus({
    this.provider = 'Supabase BaaS',
    this.authentication = 'Supabase Auth (JWT)',
    this.protocol = 'Direct HTTPS / WSS',
    this.isHealthy = true,
  });
}

/// Model rangkuman statistik dan data utama Dashboard
class DashboardStatsModel {
  final BackendArchitectureStatus backendStatus;

  const DashboardStatsModel({
    this.backendStatus = const BackendArchitectureStatus(),
  });
}
