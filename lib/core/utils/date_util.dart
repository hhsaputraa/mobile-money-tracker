/// Utility untuk standarisasi zona waktu Asia/Jakarta (WIB, UTC+7)
/// Memastikan tampilan dan penyimpanan waktu selalu konsisten dengan waktu di database.
class DateUtil {
  static const Duration wibOffset = Duration(hours: 7);

  /// Mengembalikan waktu saat ini dalam zona waktu Asia/Jakarta (WIB)
  static DateTime nowInWib() {
    final nowUtc = DateTime.now().toUtc();
    final wib = nowUtc.add(wibOffset);
    return DateTime(wib.year, wib.month, wib.day, wib.hour, wib.minute, wib.second);
  }

  /// Mengonversi objek [DateTime] ke zona waktu Asia/Jakarta (WIB)
  static DateTime toWib(DateTime dateTime) {
    if (dateTime.isUtc) {
      final wib = dateTime.add(wibOffset);
      return DateTime(wib.year, wib.month, wib.day, wib.hour, wib.minute, wib.second);
    }
    return dateTime;
  }

  /// Menguraikan string timestamp dari database Supabase secara presisi
  /// Menjamin jam yang tampil di frontend sama persis dengan jam yang tercatat di database.
  static DateTime parseDbDate(dynamic raw) {
    if (raw == null) return nowInWib();
    if (raw is DateTime) return raw;

    final str = raw.toString().trim();
    if (str.isEmpty) return nowInWib();

    try {
      // Ekstrak komponen tanggal & jam: YYYY-MM-DD HH:MM:SS
      final match = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):?(\d{2})?',
      ).firstMatch(str);

      if (match != null) {
        final y = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final d = int.parse(match.group(3)!);
        final h = int.parse(match.group(4)!);
        final min = int.parse(match.group(5)!);
        final s = int.tryParse(match.group(6) ?? '0') ?? 0;

        // Jika string mencantumkan offset UTC (+00 atau berakhiran Z) tanpa +07
        if ((str.endsWith('Z') || str.contains('+00')) && !str.contains('+07')) {
          final utc = DateTime.utc(y, m, d, h, min, s);
          final wib = utc.add(wibOffset);
          return DateTime(wib.year, wib.month, wib.day, wib.hour, wib.minute, wib.second);
        }

        // Jika string memiliki +07 (seperti di PostgreSQL 11:41:40+07) atau tanpa timezone,
        // angka jam dalam string adalah jam asli yang dicatat di DB.
        return DateTime(y, m, d, h, min, s);
      }

      final parsed = DateTime.parse(str);
      return parsed.isUtc ? parsed.add(wibOffset) : parsed;
    } catch (_) {
      return nowInWib();
    }
  }

  /// Format [DateTime] ke teks Indonesia lengkap dengan zona waktu WIB
  /// Contoh: "03 Sep 2026, 11:41 WIB"
  static String formatToWib(
    DateTime dateTime, {
    bool showTime = true,
    bool includeZoneLabel = true,
  }) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final wib = toWib(dateTime);
    final day = wib.day.toString().padLeft(2, '0');
    final month = months[wib.month];
    final year = wib.year;

    if (!showTime) {
      return '$day $month $year';
    }

    final hour = wib.hour.toString().padLeft(2, '0');
    final minute = wib.minute.toString().padLeft(2, '0');
    final zone = includeZoneLabel ? ' WIB' : '';
    return '$day $month $year, $hour:$minute$zone';
  }

  /// Mengubah DateTime ke string ISO 8601 dengan offset eksplisit Asia/Jakarta (+07:00)
  /// Contoh: "2026-09-03T11:41:40+07:00"
  static String toWibIsoString(DateTime dateTime) {
    final wib = toWib(dateTime);
    final y = wib.year.toString().padLeft(4, '0');
    final m = wib.month.toString().padLeft(2, '0');
    final d = wib.day.toString().padLeft(2, '0');
    final h = wib.hour.toString().padLeft(2, '0');
    final min = wib.minute.toString().padLeft(2, '0');
    final s = wib.second.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h:$min:$s+07:00';
  }
}
