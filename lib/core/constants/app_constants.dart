import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'MONEY TRACKER';
  static const String appTagline = 'MONEY TRACKER';

  static const String baseUrlLocal = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8097',
  );

  static const String baseUrlAndroidEmulator = String.fromEnvironment(
    'API_BASE_URL_ANDROID',
    defaultValue: 'http://10.0.2.2:8097',
  );

  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://onesibmhxdwvnxuyfvpj.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9uZXNpYm1oeGR3dm54dXlmdnBqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg0MjI2NjAsImV4cCI6MjA3Mzk5ODY2MH0.2qtsgRZnEUr4fuzvfu3vVfXaA4_Ldp9RKhAiyBPIXMk',
  );

  static const String aesKey = String.fromEnvironment(
    'AES_KEY',
    defaultValue: kDebugMode ? 'f17ba46472fa64e40ca496d1b4c91e8f' : '',
  );
  static const String keyAuthToken = 'auth_token';
  static const String keyUserData = 'user_data';
  static const String keyCustomBaseUrl = 'custom_base_url';
}

