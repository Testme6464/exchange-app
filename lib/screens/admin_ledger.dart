// Admin ledger tab: volumes + fees from COMPLETED orders only, counts
// per status, date-range chips — mirrors renderAdminLedger().

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

const List<String> _statuses = [
  'pending',
  'reviewing',
  'completed',
  'rejected',
  'cancelled',
];

class AdminLedgerTab extends StatefulWidget {
  const AdminLedgerTab({
    required this.state,
    required this.refreshTick,
    super.key,
  });

  final AppState state;
  final int refreshTick;

  @override
  State<AdminLedgerTab> createState() => _AdminLedgerTabState();
}

class _AdminLedgerTabState extends State<AdminLedgerTab> {
  String _range = 'today';
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(AdminLedgerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _future = _load();
    }
  }

  Future<List<Order>> _load() =>
      widget.state.store.listOrders(isAdmin: true);

  DateTime? _cutoff() {
    final now = DateTime.now();
    switch (_range) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case '7':
        return now.subtract(const Duration(days: 7));
      case '30':
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: ChipRow(
            options: [
              (id: 'today', label: s('rangeToday')),
              (id: '7', label: s('range7')),
              (id: '30', label: s('range30')),
              (id: 'all', label: s('rangeAll')),
            ],
            selected: _range,
            onSelected: (id) => setState(() => _range = id),
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
                  onRetry: () => setState(() => _future = _load()),
                );
              }
              final all = snapshot.data ?? const [];
              final cutoff = _cutoff();
              final rows = cutoff == null
                  ? all
                  : all
                      .where(
                        (o) =>
                            o.createdAt != null &&
                            !o.createdAt!.isBefore(cutoff),
                      )
                      .toList();
              final counts = <String, int>{
                for (final st in _statuses) st: 0,
              };
              for (final o in rows) {
                if (counts.containsKey(o.status)) {
                  counts[o.status] = counts[o.status]! + 1;
                }
              }
              final completed =
                  rows.where((o) => o.status == 'completed').toList();
              final volThb = completed
                  .where((o) => o.direction == 'THB_TO_MMK')
                  .fold<double>(0, (sum, o) => sum + o.sendAmount);
              final volMmk = completed
                  .where((o) => o.direction == 'MMK_TO_THB')
                  .fold<double>(0, (sum, o) => sum + o.sendAmount);
              final feesMmk = completed
                  .where((o) => o.receiveCurrency == 'MMK')
                  .fold<double>(0, (sum, o) => sum + o.fee);
              final feesThb = completed
                  .where((o) => o.receiveCurrency == 'THB')
                  .fold<double>(0, (sum, o) => sum + o.fee);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CardTitle(s('ledgerTitle')),
                          const SizedBox(height: 8),
                          KvRow(
                            label: s('totalOrders'),
                            value: '${rows.length}',
                          ),
                          KvRow(
                            label: s('ledgerVolumeThbToMmk'),
                            value: fmtMoney(volThb, 'THB'),
                          ),
                          KvRow(
                            label: s('ledgerVolumeMmkToThb'),
                            value: fmtMoney(volMmk, 'MMK'),
                          ),
                          KvRow(
                            label: s('ledgerFeesMmk'),
                            value: fmtMoney(feesMmk, 'MMK'),
                          ),
                          KvRow(
                            label: s('ledgerFeesThb'),
                            value: fmtMoney(feesThb, 'THB'),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s('ledgerNote'),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CardTitle(s('ledgerCounts')),
                          const SizedBox(height: 8),
                          ..._statuses.map(
                            (st) => KvRow(
                              label: statusLabel(st),
                              value: '${counts[st]}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
