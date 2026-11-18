// Admin users tab: search, order counts, joined date, block/unblock
// (never yourself) — mirrors renderAdminUsers() in js/app.js.

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({
    required this.state,
    required this.refreshTick,
    super.key,
  });

  final AppState state;
  final int refreshTick;

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _search = TextEditingController();
  String _query = '';
  late Future<({List<Profile> users, Map<String, int> counts})> _future;
  List<Profile>? _users;
  Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(AdminUsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<({List<Profile> users, Map<String, int> counts})> _load() async {
    final users = await widget.state.store.listUsers();
    final counts = await widget.state.store.getOrderCountsByUser();
    _users = users;
    _counts = counts;
    return (users: users, counts: counts);
  }

  Future<void> _toggleBlock(Profile user) async {
    final next = !user.isBlocked;
    try {
      await widget.state.store.setBlocked(user.id, next);
      if (!mounted) return;
      showSnack(context, s('savedOk'));
      setState(() {
        _users = _users
            ?.map(
              (u) => u.id == user.id
                  ? Profile(
                      id: u.id,
                      email: u.email,
                      displayName: u.displayName,
                      phone: u.phone,
                      receivers: u.receivers,
                      isBlocked: next,
                      createdAt: u.createdAt,
                    )
                  : u,
            )
            .toList();
      });
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
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
                s('usersTitle'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: s('searchUsersPh'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _users == null) {
                return const LoadingView();
              }
              if (snapshot.hasError && _users == null) {
                return ErrorView(
                  message: s('errorLoad'),
                  onRetry: () => setState(() => _future = _load()),
                );
              }
              final users = _users ?? const [];
              final q = _query.toLowerCase();
              final filtered = users.where((u) {
                if (q.isEmpty) return true;
                return u.displayName.toLowerCase().contains(q) ||
                    u.email.toLowerCase().contains(q);
              }).toList();
              if (filtered.isEmpty) return EmptyText(s('noHistory'));
              return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final u = filtered[i];
                  final isSelf = u.id == widget.state.user?.id;
                  return AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                u.email,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                              if (u.phone.isNotEmpty)
                                Text(u.phone,
                                    style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                '${s('orderCount')}: ${_counts[u.id] ?? 0} · '
                                '${s('joined')}: ${fmtDateTime(u.createdAt)}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _BlockedPill(blocked: u.isBlocked),
                            ],
                          ),
                        ),
                        if (!isSelf)
                          OutlinedButton(
                            onPressed: () => _toggleBlock(u),
                            child: Text(
                              u.isBlocked ? s('unblock') : s('block'),
                            ),
                          ),
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

/// Blocked = red pill, active = blue pill (pill--rejected / pill--open).
class _BlockedPill extends StatelessWidget {
  const _BlockedPill({required this.blocked});

  final bool blocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: blocked ? AppColors.redPale : AppColors.blue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        blocked ? s('blocked') : s('active'),
        style: TextStyle(
          color: blocked ? AppColors.red : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
