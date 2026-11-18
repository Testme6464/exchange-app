// Tests for the quote math, amount limits, receive-method filtering
// and formatting helpers in lib/quote.dart — mirroring js/app.js.

import 'dart:math' as math;

import 'package:exchange/models.dart';
import 'package:exchange/quote.dart';
import 'package:exchange/strings.dart';
import 'package:flutter_test/flutter_test.dart';

AppSettings _settings({double feePercent = 0}) {
  return AppSettings(
    rates: const RatesSettings(thbToMmk: 141.85, mmkToThb: 146.41),
    fees: FeesSettings(
      feePercent: feePercent,
      minThb: 100,
      maxThb: 50000,
      minMmk: 10000,
      maxMmk: 5000000,
    ),
  );
}

void main() {
  group('calcQuote THB_TO_MMK', () {
    test('no fee: gross and net are whole MMK', () {
      final q = calcQuote('THB_TO_MMK', 1000, _settings())!;
      expect(q.rate, 141.85);
      expect(q.gross, 141850);
      expect(q.fee, 0);
      expect(q.net, 141850);
      expect(q.sendCurrency, 'THB');
      expect(q.receiveCurrency, 'MMK');
    });

    test('fee is taken in the receive currency, rounded to whole MMK', () {
      final q = calcQuote('THB_TO_MMK', 1000, _settings(feePercent: 1))!;
      // gross 141850, fee = round(141850 * 1%) = round(1418.5) = 1419.
      expect(q.fee, 1419);
      expect(q.net, 141850 - 1419);
    });

    test('fractional gross rounds to whole MMK before the fee is taken', () {
      // 333 * 141.85 = 47236.05 -> gross 47236, fee 0.
      final q = calcQuote('THB_TO_MMK', 333, _settings())!;
      expect(q.gross, 47236);
      expect(q.net, 47236);
    });
  });

  group('calcQuote MMK_TO_THB', () {
    test('no fee: THB to 2 decimals', () {
      final q = calcQuote('MMK_TO_THB', 141850, _settings())!;
      expect(q.rate, 146.41);
      expect(q.gross, closeTo(968.86, 0.01));
      expect(q.fee, 0);
      expect(q.net, closeTo(968.86, 0.01));
      expect(q.sendCurrency, 'MMK');
      expect(q.receiveCurrency, 'THB');
    });

    test('fee is taken in THB, rounded to 2 decimals', () {
      final q = calcQuote('MMK_TO_THB', 146410, _settings(feePercent: 2))!;
      // gross = 1000 THB exactly, fee = 20, net = 980.
      expect(q.gross, 1000);
      expect(q.fee, 20);
      expect(q.net, 980);
    });
  });

  group('calcQuote invalid input', () {
    test('returns null for zero, negative and NaN amounts', () {
      final st = _settings();
      expect(calcQuote('THB_TO_MMK', 0, st), isNull);
      expect(calcQuote('THB_TO_MMK', -5, st), isNull);
      expect(calcQuote('THB_TO_MMK', double.nan, st), isNull);
      expect(calcQuote('MMK_TO_THB', 0, st), isNull);
    });
  });

  group('amountLimits + validateAmount', () {
    test('THB leg uses min_thb/max_thb', () {
      final lim = amountLimits('THB_TO_MMK', _settings());
      expect((lim.min, lim.max, lim.currency), (100, 50000, 'THB'));
    });

    test('MMK leg uses min_mmk/max_mmk', () {
      final lim = amountLimits('MMK_TO_THB', _settings());
      expect((lim.min, lim.max, lim.currency), (10000, 5000000, 'MMK'));
    });

    test('validateAmount messages match the website strings', () {
      final st = _settings();
      expect(validateAmount('THB_TO_MMK', 0, st), s('invalidAmount'));
      expect(validateAmount('THB_TO_MMK', 50, st), s('belowMin'));
      expect(validateAmount('THB_TO_MMK', 60000, st), s('aboveMax'));
      expect(validateAmount('THB_TO_MMK', 100, st), '');
      expect(validateAmount('THB_TO_MMK', 50000, st), '');
      expect(validateAmount('MMK_TO_THB', 5000, st), s('belowMin'));
      expect(validateAmount('MMK_TO_THB', 10000, st), '');
    });
  });

  group('enabledReceiveMethods', () {
    test('defaults expose all 7 methods', () {
      expect(
        enabledReceiveMethods(const AppSettings()),
        ['KBZPay', 'WavePay', 'AYA Pay', 'CB Pay', 'KBZ Bank', 'PromptPay', 'Other'],
      );
    });

    test('disabled methods are filtered out', () {
      final st = AppSettings(
        receiveMethods: const [
          ReceiveMethodEntry(label: 'KBZPay', enabled: true),
          ReceiveMethodEntry(label: 'WavePay', enabled: false),
          ReceiveMethodEntry(label: 'Other', enabled: true),
        ],
      );
      expect(enabledReceiveMethods(st), ['KBZPay', 'Other']);
    });

    test('all-disabled falls back to the full list so ordering never breaks', () {
      final st = AppSettings(
        receiveMethods: const [
          ReceiveMethodEntry(label: 'KBZPay', enabled: false),
          ReceiveMethodEntry(label: 'WavePay', enabled: false),
        ],
      );
      expect(enabledReceiveMethods(st), ['KBZPay', 'WavePay']);
    });

    test('empty list falls back to RECEIVE_METHODS + Other', () {
      const st = AppSettings(receiveMethods: []);
      expect(
        enabledReceiveMethods(st),
        [...receiveMethodsFallback, 'Other'],
      );
    });

    test('receiveMethodLabel localizes Other only', () {
      expect(receiveMethodLabel('Other'), s('methodOther'));
      expect(receiveMethodLabel('KBZPay'), 'KBZPay');
    });
  });

  group('formatting', () {
    test('fmtNum groups thousands, en-US style', () {
      expect(fmtNum(141850), '141,850');
      expect(fmtNum(968.86, 2), '968.86');
      expect(fmtNum(1000.5, 2), '1,000.50');
      expect(fmtNum(0), '0');
      expect(fmtNum(5000000), '5,000,000');
    });

    test('fmtMoney uses THB 2dp / MMK whole + Burmese label', () {
      expect(fmtMoney(1000, 'THB'), '1,000.00 ${s('thb')}');
      expect(fmtMoney(141850, 'MMK'), '141,850 ${s('mmk')}');
    });

    test('fmtDateTime renders en-GB style in local time', () {
      expect(
        fmtDateTime(DateTime(2026, 11, 2, 14, 30)),
        '02 Nov 2026, 14:30',
      );
      expect(fmtDateTime(null), s('neverUpdated'));
    });

    test('fmtTimeAgo buckets match the website', () {
      final now = DateTime(2026, 11, 18, 12, 0);
      expect(fmtTimeAgo(null, now: now), s('neverUpdated'));
      expect(fmtTimeAgo(now, now: now), s('justNow'));
      expect(
        fmtTimeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        s('minutesAgo', {'n': '5'}),
      );
      expect(
        fmtTimeAgo(now.subtract(const Duration(hours: 3)), now: now),
        s('hoursAgo', {'n': '3'}),
      );
      expect(
        fmtTimeAgo(now.subtract(const Duration(days: 2)), now: now),
        s('daysAgo', {'n': '2'}),
      );
    });

    test('statusLabel maps statuses to strings', () {
      expect(statusLabel('pending'), s('statusPending'));
      expect(statusLabel('completed'), s('statusCompleted'));
    });
  });

  group('contact links', () {
    test('telegramLink normalizes handles', () {
      expect(telegramLink(''), '');
      expect(telegramLink('myshop'), 'https://t.me/myshop');
      expect(telegramLink('@myshop'), 'https://t.me/myshop');
      expect(telegramLink('t.me/myshop'), 'https://t.me/myshop');
      expect(
        telegramLink('https://t.me/myshop'),
        'https://t.me/myshop',
      );
    });

    test('viberLink strips separators and URL-encodes', () {
      expect(viberLink(''), '');
      expect(
        viberLink('+66 81-234 5678'),
        'viber://chat?number=%2B66812345678',
      );
      expect(viberLink('095123456'), 'viber://chat?number=095123456');
    });
  });

  group('order numbers + file names', () {
    test('generateOrderNo matches BKX-YYYYMMDD-XXXX', () {
      final no = generateOrderNo(math.Random(42));
      expect(no, matches(RegExp(r'^BKX-\d{8}-[A-Z2-9]{4}$')));
      // Deterministic with a seeded Random.
      expect(generateOrderNo(math.Random(42)), no);
      // Only the website's alphabet is used.
      final suffix = no.split('-').last;
      for (final c in suffix.split('')) {
        expect('ABCDEFGHJKMNPQRSTUVWXYZ23456789', contains(c));
      }
    });

    test('sanitizeFileName keeps safe chars, caps at 60, defaults to file', () {
      expect(sanitizeFileName('my slip (1).png'), 'my_slip_1_.png');
      expect(sanitizeFileName(''), 'file');
      expect(sanitizeFileName('a' * 100).length, 60);
      expect(sanitizeFileName('IMG_2026.jpg'), 'IMG_2026.jpg');
    });
  });
}
