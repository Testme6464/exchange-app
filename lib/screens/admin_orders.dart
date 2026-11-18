// Admin orders queue: search + status chips, slip thumbnails, receiver
// info, mark-reviewing quick action — mirrors renderAdminOrders().

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';

const List<String> _statuses = [
  '',
  'pending',
  'reviewing',
  'completed',
  'rejected',
  'cancelled',
];

class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({
    required this.state,
    required this.refreshTick,
    super.key,
  });

  final AppState state;
  final int refreshTick;

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  final _search = TextEditingController();
  String _status = '';
  String _query = '';
  Timer? _debounce;
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(AdminOrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<List<Order>> _load() => widget.state.store.listOrders(
        isAdmin: true,
        status: _status.isEmpty ? null : _status,
        search: _query.isEmpty ? null : _query,
      );

  void _reload() => setState(() => _future = _load());

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = value.trim();
      _reload();
    });
  }

  Future<void> _markReviewing(Order order) async {
    try {
      await widget.state.store.updateOrderStatus(order.id, 'reviewing');
      if (!mounted) return;
      showSnack(context, s('orderUpdated'));
      _reload();
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  void _openOrder(Order order) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailScreen(
              state: widget.state,
              orderId: order.id,
            ),
          ),
        )
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: s('searchPh'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 12),
              ChipRow(
                options: _statuses.map((st) {
                  return (
                    id: st,
                    label: st.isEmpty ? s('filterAll') : statusLabel(st),
                  );
                }).toList(),
                selected: _status,
                onSelected: (id) {
                  _status = id;
                  _reload();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Order>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return ErrorView(
                  message: s('errorLoad'),
                  onRetry: _reload,
                );
              }
              final orders = snapshot.data ?? const [];
              if (orders.isEmpty) return EmptyText(s('noOrders'));
              return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final order = orders[i];
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (order.slipPath != null)
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: SlipImage(
                                  store: widget.state.store,
                                  bucket: 'slips',
                                  path: order.slipPath!,
                                  height: 64,
                                ),
                              ),
                            if (order.slipPath != null)
                              const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _openOrder(order),
                                          child: Text(
                                            order.orderNo,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppColors.blue,
                                            ),
                                          ),
                                        ),
                                      ),
                                      StatusPill(order.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${fmtMoney(order.sendAmount, order.sendCurrency)} → '
                                    '${fmtMoney(order.receiveAmount, order.receiveCurrency)}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Text(
                                    '${order.receiveMethod} · ${order.receiverName} · '
                                    '${fmtDateTime(order.createdAt)}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (order.status == 'pending') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _markReviewing(order),
                                child: Text(s('markReviewing')),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _openOrder(order),
                                child: Text(s('view')),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
