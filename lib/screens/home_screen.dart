// Home: rate hero, announcement, closed notice, calculator and
// how-it-works — mirrors renderHome() in js/app.js.

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.state,
    required this.onOrderNow,
    super.key,
  });

  final AppState state;
  final VoidCallback onOrderNow;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _direction = 'THB_TO_MMK';
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.state.settings;
    final shop = settings.shop;
    final updatedLabel = fmtTimeAgo(widget.state.ratesUpdatedAt);

    final amount = double.tryParse(_amount.text.trim());
    final quote = amount != null
        ? calcQuote(_direction, amount, settings)
        : null;
    final validationError = amount != null
        ? validateAmount(_direction, amount, settings)
        : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rate hero.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blue, AppColors.blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              // 3D depth: a key shadow that lifts the hero off the page
              // plus a soft ambient shadow.
              boxShadow: const [
                BoxShadow(
                  color: Color(0x591E3A8A),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s('rateTitle'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OpenClosedPill(shop.isOpen),
                  ],
                ),
                const SizedBox(height: 10),
                _RateLine(
                  dirLabel: s('rateDirThb'),
                  value: s('rateLineThb', {
                    'rate': fmtNum(settings.rates.thbToMmk, 2),
                  }),
                ),
                const SizedBox(height: 6),
                _RateLine(
                  dirLabel: s('rateDirMmk'),
                  value: s('rateLineMmk', {
                    'rate': fmtNum(settings.rates.mmkToThb, 2),
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '${s('lastUpdated')}: $updatedLabel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (shop.announcement.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bluePale,
                border: Border.all(color: AppColors.blueLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                shop.announcement,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
          if (!shop.isOpen) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bluePale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                shop.openHours.isNotEmpty
                    ? '${s('shopClosed')} · ${s('openHours')}: ${shop.openHours}'
                    : s('shopClosed'),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.blueDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Calculator.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(s('calcTitle')),
                const SizedBox(height: 12),
                ChipRow(
                  options: [
                    (id: 'THB_TO_MMK', label: s('directionThbToMmk')),
                    (id: 'MMK_TO_THB', label: s('directionMmkToThb')),
                  ],
                  selected: _direction,
                  onSelected: (id) => setState(() => _direction = id),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: s('youSend'),
                    hintText: '0',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (quote != null) ...[
                  const SizedBox(height: 12),
                  KvRow(
                    label: s('rateUsed'),
                    value: fmtNum(quote.rate, 2),
                  ),
                  KvRow(
                    label: s('youReceive'),
                    value: fmtMoney(quote.gross, quote.receiveCurrency),
                  ),
                  KvRow(
                    label:
                        '${s('fee')} (${fmtNum(settings.fees.feePercent, 2)}%)',
                    value: fmtMoney(quote.fee, quote.receiveCurrency),
                  ),
                  KvRow(
                    label: s('netReceive'),
                    value: fmtMoney(quote.net, quote.receiveCurrency),
                  ),
                  if (validationError.isNotEmpty)
                    FieldError(validationError),
                ],
                const SizedBox(height: 10),
                Text(
                  s('ratesNote'),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // How it works.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardTitle(s('howTitle')),
                const SizedBox(height: 12),
                _HowStep(no: '1', title: s('step1Title'), text: s('step1Text')),
                const SizedBox(height: 10),
                _HowStep(no: '2', title: s('step2Title'), text: s('step2Text')),
                const SizedBox(height: 10),
                _HowStep(no: '3', title: s('step3Title'), text: s('step3Text')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: widget.onOrderNow,
            child: Text(
              widget.state.loggedIn ? s('orderNow') : s('loginToOrder'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateLine extends StatelessWidget {
  const _RateLine({required this.dirLabel, required this.value});

  final String dirLabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            dirLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({required this.no, required this.title, required this.text});

  final String no;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.blue,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            no,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
