import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/models/offer_models.dart';
import 'package:qadam/data/models/points_models.dart';
import 'package:qadam/data/models/voucher_models.dart';

void main() {
  group('Phase M3 Models Tests', () {
    test('BalanceModel.fromJson parses GET /points/balance correctly', () {
      final json = {
        'balance': 450,
        'total_earned': 600,
        'total_spent': 150,
      };

      final balance = BalanceModel.fromJson(json);

      expect(balance.balance, equals(450));
      expect(balance.totalEarned, equals(600));
      expect(balance.totalSpent, equals(150));
    });

    test('LedgerEntryModel.fromJson parses ledger item correctly', () {
      final json = {
        'id': 'ledger-1',
        'delta': 50,
        'reason': 'STEP_EARN',
        'ref_type': 'activity_daily',
        'ref_id': 'act-1',
        'created_at': '2026-08-15T10:00:00Z',
      };

      final entry = LedgerEntryModel.fromJson(json);

      expect(entry.id, equals('ledger-1'));
      expect(entry.delta, equals(50));
      expect(entry.reason, equals('STEP_EARN'));
    });

    test('OfferModel.fromJson parses GET /offers item correctly', () {
      final json = {
        'id': 'offer-1',
        'partner_id': 'partner-1',
        'title': '10% Off Shoes',
        'description': 'Valid on sports shoes',
        'discount_type': 'PERCENT',
        'discount_value': 10.0,
        'points_cost': 500,
        'inventory': 100,
        'status': 'ACTIVE',
      };

      final offer = OfferModel.fromJson(json);

      expect(offer.id, equals('offer-1'));
      expect(offer.title, equals('10% Off Shoes'));
      expect(offer.discountType, equals('PERCENT'));
      expect(offer.pointsCost, equals(500));
      expect(offer.inventory, equals(100));
    });

    test('RedeemResultModel.fromJson parses POST /offers/{id}/redeem correctly', () {
      final json = {
        'voucher_id': 'vouch-1',
        'short_code': 'SR-7K4Q-92MX',
        'token': 'opaque-token-12345',
        'expires_at': '2026-09-15T12:00:00Z',
        'points_spent': 500,
        'balance': 150,
      };

      final result = RedeemResultModel.fromJson(json);

      expect(result.voucherId, equals('vouch-1'));
      expect(result.shortCode, equals('SR-7K4Q-92MX'));
      expect(result.token, equals('opaque-token-12345'));
      expect(result.pointsSpent, equals(500));
      expect(result.balance, equals(150));
    });

    test('VoucherModel.fromJson parses GET /vouchers item correctly', () {
      final json = {
        'id': 'vouch-1',
        'offer_id': 'offer-1',
        'short_code': 'SR-7K4Q-92MX',
        'status': 'ISSUED',
        'issued_at': '2026-08-15T12:00:00Z',
        'expires_at': '2026-09-15T12:00:00Z',
        'offer_title': '10% Off Shoes',
        'offer_discount_type': 'PERCENT',
        'offer_discount_value': 10.0,
      };

      final voucher = VoucherModel.fromJson(json);

      expect(voucher.id, equals('vouch-1'));
      expect(voucher.shortCode, equals('SR-7K4Q-92MX'));
      expect(voucher.status, equals('ISSUED'));
      expect(voucher.offerTitle, equals('10% Off Shoes'));
    });
  });
}
