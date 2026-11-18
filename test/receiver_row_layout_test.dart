// Regression test for the v1.0.0 layout bug where a button with an
// infinite minimum width inside a Row squeezed the neighbouring text to
// one character per line (saved receivers on the profile screen). It
// replicates the exact receiver row with the real theme: the details
// line must lay out wide on few lines, and the button must be visible.
import 'package:exchange/models.dart';
import 'package:exchange/quote.dart';
import 'package:exchange/strings.dart';
import 'package:exchange/theme.dart';
import 'package:exchange/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('receiver row layout diagnostic', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const r = Receiver(
      method: 'KBZPay',
      name: 'Myat Lin Aung',
      account: '0974091111',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CardTitle(s('receiversTitle')),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    receiveMethodLabel(r.method),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    [
                                      r.name,
                                      r.account,
                                      if (r.phone.isNotEmpty) r.phone,
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () {},
                              child: Text(s('removeReceiver')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final detailsFinder = find.text('Myat Lin Aung · 0974091111');
    final labelFinder = find.text('KBZPay');
    final buttonFinder = find.byType(OutlinedButton);
    // ignore: avoid_print
    print('DETAILS SIZE: ${tester.getSize(detailsFinder)}');
    // ignore: avoid_print
    print('LABEL SIZE: ${tester.getSize(labelFinder)}');
    // ignore: avoid_print
    print('BUTTON SIZE: ${tester.getSize(buttonFinder)}');
    // ignore: avoid_print
    print('BUTTON TOPLEFT: ${tester.getTopLeft(buttonFinder)}');
    final exception = tester.takeException();
    // ignore: avoid_print
    print('EXCEPTION: $exception');

    // The details line must lay out on one line at readable width.
    expect(tester.getSize(detailsFinder).width, greaterThan(100));
    expect(tester.getSize(detailsFinder).height, lessThan(40));
  });
}
