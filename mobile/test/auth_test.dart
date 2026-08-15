import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    test('UserModel.fromJson parses GET /auth/me payload correctly', () {
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
        'status': 'ACTIVE',
        'country': 'PK',
        'timezone': 'Asia/Karachi',
        'created_at': '2026-08-15T12:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, equals('user-123'));
      expect(user.email, equals('test@example.com'));
      expect(user.status, equals('ACTIVE'));
      expect(user.country, equals('PK'));
      expect(user.timezone, equals('Asia/Karachi'));
      expect(user.createdAt, equals(DateTime.parse('2026-08-15T12:00:00Z')));
    });

    test('UserModel.toJson produces valid map', () {
      final user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        status: 'ACTIVE',
        country: 'PK',
        timezone: 'Asia/Karachi',
        createdAt: DateTime.parse('2026-08-15T12:00:00Z'),
      );

      final json = user.toJson();

      expect(json['id'], equals('user-123'));
      expect(json['email'], equals('test@example.com'));
      expect(json['status'], equals('ACTIVE'));
    });
  });
}
