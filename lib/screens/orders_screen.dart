// Orders list: search by order number + status filter chips —
// mirrors renderOrders() in js/app.js.

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
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

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({required this.state, super.key});

  final AppState state;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
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
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<List<Order>> _load() {
    final user = widget.state.user;
    if (user == null) return Future.value(const []);
    return widget.state.store.listOrders(
      userId: user.id,
      status: _status.isEmpty ? null : _status,
      search: _query.isEmpty ? null : _query,
    );
  }

  void _reload() => setState(() => _future = _load());

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _query = value.trim();
      _reload();
    });
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
              Text(
                s('ordersTitle'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
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
                itemBuilder: (context, i) => OrderRow(
                  order: orders[i],
                  onTap: () => _openOrder(orders[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
