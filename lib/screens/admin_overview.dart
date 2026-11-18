// Admin overview tab: pending count, completed-today, today's volumes,
// fees collected, recent 8 orders — mirrors renderAdminOverview().

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({
    required this.state,
    required this.refreshTick,
    required this.onViewOrders,
    super.key,
  });

  final AppState state;
  final int refreshTick;
  final VoidCallback onViewOrders;

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(AdminOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _future = _load();
    }
  }

  Future<List<Order>> _load() =>
      widget.state.store.listOrders(isAdmin: true);

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _openOrder(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OrderDetailScreen(state: widget.state, orderId: order.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Order>>(
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
        final todayStart = _startOfToday();
        final pending =
            orders.where((o) => o.status == 'pending').length;
        final completedToday = orders.where((o) {
          if (o.status != 'completed') return false;
          final t = o.completedAt ?? o.updatedAt;
          return t != null && !t.isBefore(todayStart);
        }).length;
        final todayThb = orders
            .where(
              (o) =>
                  o.createdAt != null &&
                  !o.createdAt!.isBefore(todayStart) &&
                  o.direction == 'THB_TO_MMK',
            )
            .fold<double>(0, (sum, o) => sum + o.sendAmount);
        final todayMmk = orders
            .where(
              (o) =>
                  o.createdAt != null &&
                  !o.createdAt!.isBefore(todayStart) &&
                  o.direction == 'MMK_TO_THB',
            )
            .fold<double>(0, (sum, o) => sum + o.sendAmount);
        final feesMmk = orders
            .where((o) => o.status == 'completed' && o.receiveCurrency == 'MMK')
            .fold<double>(0, (sum, o) => sum + o.fee);
        final feesThb = orders
            .where((o) => o.status == 'completed' && o.receiveCurrency == 'THB')
            .fold<double>(0, (sum, o) => sum + o.fee);
        final recent = orders.take(8).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Stat(value: '$pending', label: s('pendingCount')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      value: '$completedToday',
                      label: s('completedCount'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: fmtNum(todayThb, 2),
                      label: '${s('todayVolume')} (${s('thb')})',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      value: fmtNum(todayMmk),
                      label: '${s('todayVolume')} (${s('mmk')})',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardTitle(s('feesCollected')),
                    const SizedBox(height: 8),
                    KvRow(
                      label: s('ledgerFeesMmk'),
                      value: fmtMoney(feesMmk, 'MMK'),
                    ),
                    KvRow(
                      label: s('ledgerFeesThb'),
                      value: fmtMoney(feesThb, 'THB'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: CardTitle(s('recentOrdersAdmin'))),
                        TextButton(
                          onPressed: widget.onViewOrders,
                          child: Text(s('viewAll')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (recent.isEmpty)
                      EmptyText(s('allCaughtUp'))
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
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

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
