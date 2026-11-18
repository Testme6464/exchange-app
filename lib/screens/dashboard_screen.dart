// Dashboard: greeting, own order counts, new-order CTA and recent
// orders — mirrors renderDashboard() in js/app.js.

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.state,
    required this.onViewOrders,
    required this.onNewOrder,
    super.key,
  });

  final AppState state;
  final VoidCallback onViewOrders;
  final VoidCallback onNewOrder;

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
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.ink,
                    ),
                    onPressed: widget.onNewOrder,
                    child: Text(s('orderNow')),
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
