// Smoke test: the Telegram/Viber brand SVGs copied from the website
// must parse and render under flutter_svg (a malformed path would
// throw during pump).

import 'package:exchange/contact_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand icons parse and render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SvgPicture.string(telegramIconSvg, width: 28, height: 28),
              SvgPicture.string(viberIconSvg, width: 28, height: 28),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNWidgets(2));
  });
}
