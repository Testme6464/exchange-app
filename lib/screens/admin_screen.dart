// Admin shell: 6 tabs with the pending-count badge on the orders tab,
// realtime subscription + 20s polling. Mirrors renderAdmin() and
// startAdminLive() in js/app.js. The bottom nav is hidden here (this
// screen is pushed on top of the shell, like the website's admin
// pages). Non-admins see the admin-only message.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'admin_ledger.dart';
import 'admin_orders.dart';
import 'admin_overview.dart';
import 'admin_rates.dart';
import 'admin_settings.dart';
import 'admin_users.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({required this.state, super.key});

  final AppState state;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  int _tick = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _loadPendingCount();
    _startLive();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    final channel = _channel;
    if (channel != null) {
      widget.state.store.unsubscribeOrders(channel);
    }
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadPendingCount() async {
    try {
      final pending = await widget.state.store.listOrders(
        isAdmin: true,
        status: 'pending',
      );
      if (mounted) setState(() => _pendingCount = pending.length);
    } catch (_) {
      // Badge stays empty, like the website.
    }
  }

  void _startLive() {
    try {
      _channel = widget.state.store.subscribeOrders(() {
        if (!mounted) return;
        showSnack(context, s('newOrderArrived'));
        _guardedRefresh();
      });
    } catch (_) {
      // Realtime unavailable; polling still runs.
    }
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _guardedRefresh(),
    );
  }

  /// Mirrors guardedRefresh(): never yank a form out from under the
  /// admin while they are typing in a text field.
  void _guardedRefresh() {
    if (!mounted) return;
    final focused = FocusManager.instance.primaryFocus;
    if (focused != null &&
        focused.context != null &&
        focused.context!.widget is EditableText) {
      return;
    }
    setState(() => _tick++);
    _loadPendingCount();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(s('adminTitle'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s('adminOnly'), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s('backHome')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(
        title: Text(s('adminTitle')),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: s('tabOverview')),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s('tabOrders')),
                  if (_pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: s('tabRates')),
            Tab(text: s('tabUsers')),
            Tab(text: s('tabSettings')),
            Tab(text: s('tabLedger')),
          ],
        ),
      ),
      floatingActionButton: ContactFloat(settings: state.settings),
      body: TabBarView(
        controller: _tabs,
        children: [
          AdminOverviewTab(
            state: state,
            refreshTick: _tick,
            onViewOrders: () => _tabs.animateTo(1),
          ),
          AdminOrdersTab(state: state, refreshTick: _tick),
          AdminRatesTab(state: state),
          AdminUsersTab(state: state, refreshTick: _tick),
          AdminSettingsTab(state: state),
          AdminLedgerTab(state: state, refreshTick: _tick),
        ],
      ),
    );
  }
}
