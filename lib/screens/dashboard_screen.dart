// Dashboard: greeting, own order counts, new-order CTA and recent
// orders — mirrors renderDashboard() in js/app.js.

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.state,
    required this.onViewOrders,
    required this.onNewOrder,
    required this.onOrderWithAmount,
    super.key,
  });

  final AppState state;
  final VoidCallback onViewOrders;
  final VoidCallback onNewOrder;
  final void Function(String direction, double sendAmount) onOrderWithAmount;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Order>> _load() {
    final user = widget.state.user;
    if (user == null) return Future.value(const []);
    return widget.state.store.listOrders(userId: user.id);
  }

  void _openOrder(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(
          state: widget.state,
          orderId: order.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.state.displayName;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s('dashboardTitle'),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          if (name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${s('hello')} $name',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
          const SizedBox(height: 14),
          FutureBuilder<List<Order>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return ErrorView(
                  message: s('errorLoad'),
                  onRetry: () => setState(() => _future = _load()),
                );
              }
              final orders = snapshot.data ?? const [];
              final pending = orders
                  .where((o) => o.status == 'pending' || o.status == 'reviewing')
                  .length;
              final completed =
                  orders.where((o) => o.status == 'completed').length;
              final recent = orders.take(5).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          value: '$pending',
                          label: s('statPending'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          value: '$completed',
                          label: s('statCompleted'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          value: '${orders.length}',
                          label: s('statTotalOrders'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: widget.onNewOrder,
                    child: Text(s('orderNow')),
                  ),
                  const SizedBox(height: 14),
                  _SmartCalculator(
                    settings: widget.state.settings,
                    shopOpen: widget.state.settings.shop.isOpen,
                    onOrderWithAmount: widget.onOrderWithAmount,
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: CardTitle(s('recentOrders'))),
                            TextButton(
                              onPressed: widget.onViewOrders,
                              child: Text(s('viewAll')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (recent.isEmpty)
                          EmptyText(s('noOrders'))
                        else
                          ...recent.map(
                            (o) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OrderRow(
                                order: o,
                                onTap: () => _openOrder(o),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.blueDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Smart calculator: the user types any rate they like, then calculates
/// either way (send -> receive, or receive -> send). Mirrors the
/// dashboard calculator in js/app.js. The custom rate is for calculating
/// only; the order button carries just the direction + send amount, and
/// the wizard requotes at the live shop rate.
class _SmartCalculator extends StatefulWidget {
  const _SmartCalculator({
    required this.settings,
    required this.shopOpen,
    required this.onOrderWithAmount,
  });

  final AppSettings settings;
  final bool shopOpen;
  final void Function(String direction, double sendAmount) onOrderWithAmount;

  @override
  State<_SmartCalculator> createState() => _SmartCalculatorState();
}

class _SmartCalculatorState extends State<_SmartCalculator> {
  String _direction = 'THB_TO_MMK';
  late final TextEditingController _rate;
  final _send = TextEditingController();
  final _receive = TextEditingController();

  /// Which amount field the user last typed in; the other one is derived.
  String? _lastEdited;

  @override
  void initState() {
    super.initState();
    _rate = TextEditingController(text: plainAmount(_liveRate, 'THB'));
  }

  @override
  void dispose() {
    _rate.dispose();
    _send.dispose();
    _receive.dispose();
    super.dispose();
  }

  double get _liveRate => _direction == 'THB_TO_MMK'
      ? widget.settings.rates.thbToMmk
      : widget.settings.rates.mmkToThb;

  String get _sendCurrency => _direction == 'THB_TO_MMK' ? 'THB' : 'MMK';

  String get _receiveCurrency =>
      _direction == 'THB_TO_MMK' ? 'MMK' : 'THB';

  double? get _customRate {
    final r = double.tryParse(_rate.text.trim());
    return (r != null && r > 0) ? r : null;
  }

  double? get _sendAmount => double.tryParse(_send.text.trim());

  Quote? get _quote {
    final rate = _customRate;
    final send = _sendAmount;
    if (rate == null || send == null) return null;
    return calcQuote(_direction, send, widget.settings, rateOverride: rate);
  }

  String get _validationError {
    final send = _sendAmount;
    if (send == null) return '';
    return validateAmount(_direction, send, widget.settings);
  }

  void _onSendChanged() {
    _lastEdited = 'send';
    final rate = _customRate;
    final send = _sendAmount;
    final quote = (rate != null && send != null)
        ? calcQuote(_direction, send, widget.settings, rateOverride: rate)
        : null;
    // Setting .text programmatically does not fire onChanged, so this
    // cannot loop back into _onReceiveChanged.
    _receive.text =
        quote == null ? '' : plainAmount(quote.net, _receiveCurrency);
    setState(() {});
  }

  void _onReceiveChanged() {
    _lastEdited = 'receive';
    final rate = _customRate;
    final net = double.tryParse(_receive.text.trim());
    final rev = (rate != null && net != null)
        ? calcReverseQuote(_direction, net, widget.settings,
            rateOverride: rate)
        : null;
    _send.text = rev == null ? '' : plainAmount(rev.send, _sendCurrency);
    setState(() {});
  }

  void _recomputeFromLastEdited() {
    if (_lastEdited == 'send') {
      _onSendChanged();
    } else if (_lastEdited == 'receive') {
      _onReceiveChanged();
    } else {
      setState(() {});
    }
  }

  void _setDirection(String dir) {
    setState(() {
      _direction = dir;
      // A fresh direction starts from its live shop rate; the user can
      // then type any rate they like.
      _rate.text = plainAmount(_liveRate, 'THB');
    });
    _recomputeFromLastEdited();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final quote = _quote;
    final validationError = _validationError;
    final send = _sendAmount;
    final canOrder = widget.shopOpen &&
        quote != null &&
        send != null &&
        validationError.isEmpty;
    final orderSend = canOrder ? send : null;

    return AppCard(
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
            onSelected: _setDirection,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rate,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: s('rate'),
              helperText: '${s('rateTitle')}: ${fmtNum(_liveRate, 2)}',
            ),
            onChanged: (_) => _recomputeFromLastEdited(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _send,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: s('youSend'),
              hintText: '0',
            ),
            onChanged: (_) => _onSendChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receive,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: s('youReceive'),
              hintText: '0',
            ),
            onChanged: (_) => _onReceiveChanged(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in quickSendAmounts[_direction]!)
                ActionChip(
                  label: Text(fmtNum(a)),
                  onPressed: () {
                    _send.text = plainAmount(a, _sendCurrency);
                    _onSendChanged();
                  },
                ),
            ],
          ),
          if (quote != null) ...[
            const SizedBox(height: 12),
            KvRow(label: s('rateUsed'), value: fmtNum(quote.rate, 2)),
            KvRow(
              label: s('youReceive'),
              value: fmtMoney(quote.gross, quote.receiveCurrency),
            ),
            KvRow(
              label: '${s('fee')} (${fmtNum(settings.fees.feePercent, 2)}%)',
              value: fmtMoney(quote.fee, quote.receiveCurrency),
            ),
            KvRow(
              label: s('netReceive'),
              value: fmtMoney(quote.net, quote.receiveCurrency),
            ),
            if (validationError.isNotEmpty) FieldError(validationError),
          ],
          const SizedBox(height: 12),
          if (widget.shopOpen)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: orderSend == null
                  ? null
                  : () => widget.onOrderWithAmount(_direction, orderSend),
              child: Text(s('orderWithAmount')),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bluePale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                s('shopClosedBlock'),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.blueDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
