import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/auth/token_storage.dart';
import 'package:qadam/data/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(user.role, equals('USER'));
      expect(user.isMerchant, isFalse);
    });

    test('UserModel parses MERCHANT role and partner details correctly', () {
      final json = {
        'id': 'merchant-123',
        'email': 'store@apexcafe.com',
        'status': 'ACTIVE',
        'role': 'MERCHANT',
        'partner_id': 'partner-uuid-456',
        'partner_name': 'Apex Cafe & Bakery',
        'created_at': '2026-09-01T10:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, equals('merchant-123'));
      expect(user.email, equals('store@apexcafe.com'));
      expect(user.role, equals('MERCHANT'));
      expect(user.partnerId, equals('partner-uuid-456'));
      expect(user.partnerName, equals('Apex Cafe & Bakery'));
      expect(user.isMerchant, isTrue);

      final outJson = user.toJson();
      expect(outJson['role'], equals('MERCHANT'));
      expect(outJson['partner_id'], equals('partner-uuid-456'));
      expect(outJson['partner_name'], equals('Apex Cafe & Bakery'));
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

  group('TokenStorage Persistent Auth Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('saveToken and getToken persists JWT correctly', () async {
      final storage = TokenStorage();
      expect(await storage.getToken(), isNull);

      await storage.saveToken('jwt_sample_token_123');
      expect(await storage.getToken(), equals('jwt_sample_token_123'));

      await storage.deleteToken();
      expect(await storage.getToken(), isNull);
    });

    test('saveUser and getUser persists UserModel across app sessions', () async {
      final storage = TokenStorage();
      expect(await storage.getUser(), isNull);

      final user = UserModel(
        id: 'user-xyz',
        email: 'runner@qadam.pk',
        status: 'ACTIVE',
        country: 'PK',
        timezone: 'Asia/Karachi',
        createdAt: DateTime.parse('2026-08-18T12:00:00Z'),
      );

      await storage.saveUser(user);

      final cachedUser = await storage.getUser();
      expect(cachedUser, isNotNull);
      expect(cachedUser!.id, equals('user-xyz'));
      expect(cachedUser.email, equals('runner@qadam.pk'));
      expect(cachedUser.status, equals('ACTIVE'));
      expect(cachedUser.country, equals('PK'));
      expect(cachedUser.timezone, equals('Asia/Karachi'));

      await storage.deleteUser();
      expect(await storage.getUser(), isNull);
    });

    test('clearAll clears both token and cached user profile on logout', () async {
      final storage = TokenStorage();
      await storage.saveToken('jwt_persistent_token');
      await storage.saveUser(UserModel(
        id: 'user-xyz',
        email: 'runner@qadam.pk',
        status: 'ACTIVE',
        country: 'PK',
        timezone: 'Asia/Karachi',
        createdAt: DateTime.parse('2026-08-18T12:00:00Z'),
      ));

      expect(await storage.getToken(), equals('jwt_persistent_token'));
      expect(await storage.getUser(), isNotNull);

      await storage.clearAll();

      expect(await storage.getToken(), isNull);
      expect(await storage.getUser(), isNull);
    });
  });
}
