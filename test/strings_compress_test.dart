// Guards for the Burmese string table (copied from the website) and
// the slip-image compression helper.

import 'dart:typed_data';

import 'package:exchange/strings.dart';
import 'package:exchange/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('strings table', () {
    test('contains the website strings plus the app-only additions', () {
      // 256 copied from js/app.js STRINGS + 8 app-only strings.
      expect(strings.length, 264);
    });

    test('every value is non-empty', () {
      for (final entry in strings.entries) {
        expect(entry.value, isNotEmpty, reason: 'key ${entry.key}');
      }
    });

    test('critical keys exist', () {
      for (final key in [
        'appName',
        'loginTitle',
        'registerTitle',
        'rateTitle',
        'calcTitle',
        'newOrderTitle',
        'wizardStep1',
        'wizardStep2',
        'wizardStep3',
        'ordersTitle',
        'profileTitle',
        'adminTitle',
        'tabOverview',
        'tabOrders',
        'tabRates',
        'tabUsers',
        'tabSettings',
        'tabLedger',
        'googleSignIn',
        'pickCamera',
        'pickGallery',
        'dialogConfirm',
        'dialogCancel',
        'retryAction',
      ]) {
        expect(strings.containsKey(key), isTrue, reason: 'missing $key');
      }
    });

    test('s() substitutes {placeholders} like the website S()', () {
      expect(
        s('rateLineThb', {'rate': '141.85'}),
        strings['rateLineThb']!.replaceAll('{rate}', '141.85'),
      );
      expect(s('nonexistentKey'), 'nonexistentKey');
    });

    test('no string contains private-use codepoints (Zawgyi danger zone)', () {
      for (final entry in strings.entries) {
        for (final rune in entry.value.runes) {
          // Private-use areas are where Zawgyi-only glyphs live; valid
          // Myanmar Unicode + common punctuation (em dash, ellipsis,
          // arrows) never use them.
          final isPrivateUse = (rune >= 0xE000 && rune <= 0xF8FF) ||
              (rune >= 0xF0000 && rune <= 0xFFFFD) ||
              (rune >= 0x100000 && rune <= 0x10FFFD);
          expect(
            isPrivateUse,
            isFalse,
            reason: '${entry.key} has U+${rune.toRadixString(16)}',
          );
        }
      }
    });
  });

  group('compressImageBytes', () {
    test('resizes so the longest side is 1200px and encodes JPEG', () {
      final original = img.Image(width: 2000, height: 1000);
      img.fill(original, color: img.ColorRgb8(37, 99, 235));
      final png = img.encodePng(original);

      final compressed = compressImageBytes(png);
      // JPEG magic bytes.
      expect(compressed[0], 0xFF);
      expect(compressed[1], 0xD8);

      final decoded = img.decodeImage(Uint8List.fromList(compressed))!;
      expect(decoded.width, 1200);
      expect(decoded.height, 600);
    });

    test('small images keep their size, still JPEG', () {
      final original = img.Image(width: 400, height: 300);
      img.fill(original, color: img.ColorRgb8(245, 158, 11));
      final png = img.encodePng(original);

      final compressed = compressImageBytes(png);
      final decoded = img.decodeImage(Uint8List.fromList(compressed))!;
      expect(decoded.width, 400);
      expect(decoded.height, 300);
    });

    test('un-decodable input passes through unchanged', () {
      final junk = [0, 1, 2, 3, 4, 5];
      expect(compressImageBytes(junk), junk);
    });
  });
}
