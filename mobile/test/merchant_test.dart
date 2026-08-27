import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/models/merchant_models.dart';

void main() {
  group('Merchant POS Models Tests', () {
    test('PartnerInfoModel.fromJson parses partner profile correctly', () {
      final json = {
        'partner_id': 'partner-uuid-1',
        'name': 'Apex Cafe & Bakery',
        'status': 'ACTIVE',
      };
      final model = PartnerInfoModel.fromJson(json);
      expect(model.partnerId, equals('partner-uuid-1'));
      expect(model.name, equals('Apex Cafe & Bakery'));
      expect(model.status, equals('ACTIVE'));
    });

    test('VoucherValidationModel.fromJson parses percent discount correctly', () {
      final json = {
        'voucher_id': 'voucher-uuid-1',
        'short_code': 'SR-7K4Q-92MX',
        'offer_title': '20% Off All Espresso Drinks',
        'discount_type': 'PERCENT',
        'discount_value': 20.0,
        'expires_at': '2026-09-30T12:00:00Z',
        'nonce': 'signed-nonce-12345',
      };
      final model = VoucherValidationModel.fromJson(json);
      expect(model.voucherId, equals('voucher-uuid-1'));
      expect(model.shortCode, equals('SR-7K4Q-92MX'));
      expect(model.offerTitle, equals('20% Off All Espresso Drinks'));
      expect(model.discountDisplay, equals('20% OFF'));
      expect(model.nonce, equals('signed-nonce-12345'));
    });

    test('VoucherValidationModel.discountDisplay handles free item and fixed amounts', () {
      final freeJson = {
        'voucher_id': 'v-2',
        'short_code': 'SR-FREE-ITEM',
        'offer_title': 'Free Donut with Coffee',
        'discount_type': 'FREE_ITEM',
        'discount_value': 0.0,
        'expires_at': '2026-09-30T12:00:00Z',
        'nonce': 'nonce-2',
      };
      expect(VoucherValidationModel.fromJson(freeJson).discountDisplay, equals('FREE ITEM'));

      final fixedJson = {
        'voucher_id': 'v-3',
        'short_code': 'SR-500-OFF',
        'offer_title': 'Rs 500 Off Purchase',
        'discount_type': 'FIXED_AMOUNT',
        'discount_value': 500.0,
        'expires_at': '2026-09-30T12:00:00Z',
        'nonce': 'nonce-3',
      };
      expect(VoucherValidationModel.fromJson(fixedJson).discountDisplay, equals('Rs. 500 OFF'));
    });

    test('RedemptionHistoryItemModel.fromJson parses audit rows correctly', () {
      final json = {
        'id': 'redemption-uuid-1',
        'voucher_id': 'voucher-uuid-1',
        'short_code': 'SR-7K4Q-92MX',
        'store_id': 'STORE-01',
        'order_reference': 'RECEIPT #9482',
        'discount_value': 20.0,
        'redeemed_at': '2026-08-28T10:15:00Z',
      };
      final item = RedemptionHistoryItemModel.fromJson(json);
      expect(item.id, equals('redemption-uuid-1'));
      expect(item.shortCode, equals('SR-7K4Q-92MX'));
      expect(item.storeId, equals('STORE-01'));
      expect(item.orderReference, equals('RECEIPT #9482'));
    });
  });
}
