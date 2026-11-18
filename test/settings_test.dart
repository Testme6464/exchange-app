// Tests for AppSettings.merge() — the Dart mirror of mergeSettings()
// in js/app.js: stored settings overlay the website defaults.

import 'package:exchange/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings.merge defaults', () {
    test('null stored settings yield the website defaults', () {
      const st = AppSettings();
      expect(st.rates.thbToMmk, 141.85);
      expect(st.rates.mmkToThb, 146.41);
      expect(st.fees.feePercent, 0);
      expect(st.fees.minThb, 100);
      expect(st.fees.maxThb, 50000);
      expect(st.fees.minMmk, 10000);
      expect(st.fees.maxMmk, 5000000);
      expect(st.paymentsThb, isEmpty);
      expect(st.paymentsMmk, isEmpty);
      expect(st.receiveMethods.length, 7);
      expect(st.receiveMethods.every((m) => m.enabled), isTrue);
      expect(st.shop.name, '');
      expect(st.shop.isOpen, isTrue);

      final merged = AppSettings.merge(null);
      expect(merged.rates.thbToMmk, 141.85);
      expect(merged.shop.isOpen, isTrue);
    });

    test('empty stored map yields defaults', () {
      final merged = AppSettings.merge({});
      expect(merged.rates.thbToMmk, 141.85);
      expect(merged.receiveMethods.length, 7);
    });

    test('partial rate overrides keep the other leg', () {
      final merged = AppSettings.merge({
        'rates': {'thb_to_mmk': 141.50},
      });
      expect(merged.rates.thbToMmk, 141.50);
      expect(merged.rates.mmkToThb, 146.41);
    });

    test('fee overrides merge field-by-field', () {
      final merged = AppSettings.merge({
        'fees': {'fee_percent': 1.5, 'min_thb': 200},
      });
      expect(merged.fees.feePercent, 1.5);
      expect(merged.fees.minThb, 200);
      expect(merged.fees.maxThb, 50000);
      expect(merged.fees.minMmk, 10000);
    });

    test('payment method lists parse with enabled defaulting to true', () {
      final merged = AppSettings.merge({
        'payments_thb': {
          'methods': [
            {
              'id': 'm-1',
              'label': 'KBZPay',
              'account_name': 'Tryo',
              'account_number': '091234567',
              'qr_image_url': '',
            },
            {
              'id': 'm-2',
              'label': 'PromptPay',
              'account_name': 'Tryo',
              'account_number': '0812345678',
              'qr_image_url': 'https://example.com/qr.png',
              'enabled': false,
            },
          ],
        },
      });
      expect(merged.paymentsThb.length, 2);
      expect(merged.paymentsThb.first.enabled, isTrue);
      expect(merged.paymentsThb.first.label, 'KBZPay');
      expect(merged.paymentsThb[1].enabled, isFalse);
      expect(merged.paymentsThb[1].qrImageUrl, 'https://example.com/qr.png');
      expect(merged.paymentsMmk, isEmpty);
    });

    test('receive_methods overrides parse, empty list falls back to defaults', () {
      final merged = AppSettings.merge({
        'receive_methods': {
          'methods': [
            {'label': 'KBZPay', 'enabled': true},
            {'label': 'WavePay', 'enabled': false},
          ],
        },
      });
      expect(merged.receiveMethods.length, 2);
      expect(merged.receiveMethods[1].enabled, isFalse);

      final empty = AppSettings.merge({
        'receive_methods': {'methods': []},
      });
      expect(empty.receiveMethods.length, 7);
    });

    test('shop overrides merge field-by-field', () {
      final merged = AppSettings.merge({
        'shop': {
          'name': 'My Shop',
          'is_open': false,
          'contact_telegram': 'myshop',
        },
      });
      expect(merged.shop.name, 'My Shop');
      expect(merged.shop.isOpen, isFalse);
      expect(merged.shop.contactTelegram, 'myshop');
      expect(merged.shop.announcement, '');
      expect(merged.shop.contactPhone, '');
    });

    test('unknown keys are ignored', () {
      final merged = AppSettings.merge({
        'something_else': {'x': 1},
      });
      expect(merged.rates.thbToMmk, 141.85);
    });
  });

  group('model parsing', () {
    test('Order parses numerics and dates defensively', () {
      final order = Order.fromJson({
        'id': 'abc',
        'order_no': 'BKX-20261118-ABCD',
        'user_id': 'u1',
        'direction': 'THB_TO_MMK',
        'send_amount': 1000,
        'send_currency': 'THB',
        'receive_amount': 141850,
        'receive_currency': 'MMK',
        'rate': 141.85,
        'fee': 0,
        'receive_method': 'KBZPay',
        'receiver_name': 'Aung',
        'receiver_account': '09123',
        'receiver_phone': '',
        'slip_path': 'u1/123-slip.jpg',
        'slip_txn_id': 'TXN1',
        'status': 'pending',
        'admin_note': '',
        'proof_path': null,
        'created_at': '2026-11-18T07:00:00Z',
        'updated_at': '2026-11-18T07:00:00Z',
        'completed_at': null,
      });
      expect(order.sendAmount, 1000);
      expect(order.rate, 141.85);
      expect(order.slipPath, 'u1/123-slip.jpg');
      expect(order.proofPath, isNull);
      expect(order.createdAt, isNotNull);
      expect(order.completedAt, isNull);
    });

    test('Profile parses receivers list, tolerates missing fields', () {
      final profile = Profile.fromJson({
        'id': 'u1',
        'email': 'a@b.com',
        'display_name': 'Tryo',
        'receivers': [
          {
            'method': 'KBZPay',
            'name': 'Aung',
            'account': '09123',
            'phone': '',
          },
        ],
        'is_blocked': false,
      });
      expect(profile.receivers.length, 1);
      expect(profile.receivers.first.account, '09123');
      expect(profile.phone, '');
    });
  });
}
