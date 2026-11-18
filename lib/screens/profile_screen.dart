// Profile: display name + phone, saved receivers CRUD, change-password
// (reset email) — mirrors renderProfile() in js/app.js.

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.state, super.key});

  final AppState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _recvName = TextEditingController();
  final _recvAccount = TextEditingController();
  final _recvPhone = TextEditingController();
  String _recvMethod = '';
  Profile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _phone.dispose();
    _recvName.dispose();
    _recvAccount.dispose();
    _recvPhone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = widget.state.user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = await widget.state.store.getProfile(user.id);
      if (!mounted) return;
      setState(() {
        _profile = profile ?? widget.state.profile;
        _loading = false;
      });
      _syncFields();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profile = widget.state.profile;
        _loading = false;
      });
      _syncFields();
    }
  }

  void _syncFields() {
    final profile = _profile;
    if (profile == null || _loadedFor == profile.id) return;
    _loadedFor = profile.id;
    _email.text = profile.email;
    _name.text = profile.displayName;
    _phone.text = profile.phone;
    final methods = enabledReceiveMethods(widget.state.settings);
    if (methods.isNotEmpty && _recvMethod.isEmpty) {
      _recvMethod = methods.first;
    }
  }

  Future<void> _saveProfile() async {
    final user = widget.state.user;
    final profile = _profile;
    if (user == null || profile == null) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.state.store.updateProfile(
        user.id,
        displayName: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      widget.state.setProfile(updated);
      if (!mounted) return;
      showSnack(context, s('savedOk'));
      setState(() => _profile = updated);
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addReceiver() async {
    final user = widget.state.user;
    final profile = _profile;
    if (user == null || profile == null) return;
    final name = _recvName.text.trim();
    final account = _recvAccount.text.trim();
    if (name.isEmpty || account.isEmpty) {
      showSnack(context, s('fillAll'), isError: true);
      return;
    }
    final next = [
      ...profile.receivers,
      Receiver(
        method: _recvMethod,
        name: name,
        account: account,
        phone: _recvPhone.text.trim(),
      ),
    ];
    try {
      final updated = await widget.state.store.updateProfile(
        user.id,
        receivers: next,
      );
      widget.state.setProfile(updated);
      if (!mounted) return;
      showSnack(context, s('savedOk'));
      setState(() {
        _profile = updated;
        _recvName.clear();
        _recvAccount.clear();
        _recvPhone.clear();
      });
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  Future<void> _removeReceiver(int index) async {
    final user = widget.state.user;
    final profile = _profile;
    if (user == null || profile == null) return;
    final next = [...profile.receivers]..removeAt(index);
    try {
      final updated = await widget.state.store.updateProfile(
        user.id,
        receivers: next,
      );
      widget.state.setProfile(updated);
      if (!mounted) return;
      showSnack(context, s('savedOk'));
      setState(() => _profile = updated);
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  Future<void> _changePassword() async {
    final user = widget.state.user;
    if (user == null || user.email == null) return;
    try {
      await widget.state.store.resetPassword(user.email!);
      if (mounted) showSnack(context, s('resetSent'));
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final profile = _profile;
    if (profile == null) {
      return ErrorView(message: s('errorLoad'), onRetry: _load);
    }
    final methods = enabledReceiveMethods(widget.state.settings);
    if (_recvMethod.isEmpty && methods.isNotEmpty) {
      _recvMethod = methods.first;
    }
    if (_recvMethod.isNotEmpty && !methods.contains(_recvMethod)) {
      _recvMethod = methods.first;
    }
    final receivers = profile.receivers;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(s('profileTitle')),
                const SizedBox(height: 14),
                TextField(
                  controller: _email,
                  enabled: false,
                  decoration: InputDecoration(labelText: s('email')),
                ),
                const SizedBox(height: 4),
                Text(
                  s('emailReadonly'),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: s('displayName')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: s('phone')),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: Text(s('save')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(s('receiversTitle')),
                const SizedBox(height: 10),
                if (receivers.isEmpty)
                  EmptyText(s('noReceivers'))
                else
                  ...receivers.asMap().entries.map((entry) {
                    final r = entry.value;
                    return Padding(
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
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => _removeReceiver(entry.key),
                            child: Text(s('removeReceiver')),
                          ),
                        ],
                      ),
                    );
                  }),
                const Divider(height: 24),
                LabeledDropdown(
                  label: s('methodLabel'),
                  value: _recvMethod,
                  items: methods
                      .map((m) => (value: m, label: receiveMethodLabel(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _recvMethod = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recvName,
                  decoration: InputDecoration(labelText: s('receiverName')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recvAccount,
                  decoration: InputDecoration(labelText: s('receiverAccount')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recvPhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: s('receiverPhone')),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: _addReceiver,
                  child: Text(s('addReceiver')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(s('changePassword')),
                const SizedBox(height: 8),
                Text(
                  s('changePasswordHint'),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _changePassword,
                  child: Text(s('changePasswordBtn')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
