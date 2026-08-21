import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/auth/models/auth_result.dart';
import 'package:moneytracker/auth/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    test('fromJson creates valid UserModel instance', () {
      final json = {
        'id': 'user-uuid-101',
        'username': 'admin_test',
        'full_name': 'Administrator Test',
        'email': 'admin@moneytracker.app',
        'is_admin': true,
        'is_active': 1,
        'last_login_at': '2026-08-20T10:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user-uuid-101');
      expect(user.username, 'admin_test');
      expect(user.fullName, 'Administrator Test');
      expect(user.email, 'admin@moneytracker.app');
      expect(user.isAdmin, isTrue);
      expect(user.isActive, isTrue);
      expect(user.mustChangePassword, isTrue);
      expect(user.lastLoginAt, '2026-08-20T10:00:00Z');
    });

    test('mustChangePassword is false when password_changed is true', () {
      final json = {
        'id': 'user-uuid-102',
        'username': 'user_changed',
        'full_name': 'User Changed',
        'email': 'changed@moneytracker.app',
        'password_changed': true,
      };

      final user = UserModel.fromJson(json);
      expect(user.mustChangePassword, isFalse);
    });

    test('toJson serializes correctly', () {
      final user = UserModel(
        id: 'user-uuid-202',
        username: 'user2',
        fullName: 'User Two',
        email: 'user2@moneytracker.app',
        isAdmin: false,
        isActive: true,
        mustChangePassword: true,
      );

      final json = user.toJson();

      expect(json['id'], 'user-uuid-202');
      expect(json['username'], 'user2');
      expect(json['is_admin'], isFalse);
      expect(json['must_change_password'], isTrue);
    });

  });

  group('AuthResult Tests', () {
    test('AuthResult.success creates successful state with user', () {
      final user = UserModel(
        id: 'user-uuid-1',
        username: 'teller1',
        fullName: 'Teller One',
        email: 'teller@moneytracker.app',
        isAdmin: false,
      );

      final result = AuthResult.success(message: 'Login OK', user: user);

      expect(result.isSuccess, isTrue);
      expect(result.message, 'Login OK');
      expect(result.user, isNotNull);
      expect(result.user?.username, 'teller1');
    });

    test('AuthResult.failure creates failure state', () {
      final result = AuthResult.failure('Invalid credentials');

      expect(result.isSuccess, isFalse);
      expect(result.message, 'Invalid credentials');
      expect(result.user, isNull);
    });
  });
}

