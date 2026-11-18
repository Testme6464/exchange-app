// Admin settings tab: shop form, payment-method editors (THB + MMK),
// receive-method on/off toggles, admin management — mirrors
// renderAdminSettings() in js/app.js.

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../store.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({required this.state, super.key});

  final AppState state;

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  // Shop form.
  final _shopName = TextEditingController();
  final _announcement = TextEditingController();
  final _openHours = TextEditingController();
  final _telegram = TextEditingController();
  final _phone = TextEditingController();
  bool _isOpen = true;
  bool _shopFilled = false;

  // Receive-method toggles (local working copy of the settings list).
  List<ReceiveMethodEntry> _recvWorking = [];
  bool _recvFilled = false;

  // Admins.
  late Future<List<AdminEntry>> _adminsFuture;
  final _addAdminEmail = TextEditingController();
  String _addAdminError = '';

  @override
  void initState() {
    super.initState();
    _adminsFuture = _loadAdmins();
    widget.state.refreshSettings();
  }

  @override
  void dispose() {
    _shopName.dispose();
    _announcement.dispose();
    _openHours.dispose();
    _telegram.dispose();
    _phone.dispose();
    _addAdminEmail.dispose();
    super.dispose();
  }

  Future<List<AdminEntry>> _loadAdmins() async {
    try {
      return await widget.state.store.listAdmins();
    } catch (_) {
      return const [];
    }
  }

  void _fillFromSettings() {
    final settings = widget.state.settings;
    if (!_shopFilled) {
      _shopFilled = true;
      _shopName.text = settings.shop.name;
      _announcement.text = settings.shop.announcement;
      _openHours.text = settings.shop.openHours;
      _telegram.text = settings.shop.contactTelegram;
      _phone.text = settings.shop.contactPhone;
      _isOpen = settings.shop.isOpen;
    }
    if (!_recvFilled) {
      _recvFilled = true;
      _recvWorking = settings.receiveMethods
          .map((m) => ReceiveMethodEntry(label: m.label, enabled: m.enabled))
          .toList();
    }
  }

  Future<void> _saveShop() async {
    try {
      await widget.state.store.updateSettings({
        'shop': ShopSettings(
          name: _shopName.text.trim(),
          announcement: _announcement.text.trim(),
          isOpen: _isOpen,
          openHours: _openHours.text.trim(),
          contactTelegram: _telegram.text.trim(),
          contactPhone: _phone.text.trim(),
        ).toJson(),
      });
      await widget.state.refreshSettings();
      if (mounted) showSnack(context, s('settingsSaved'));
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  Future<void> _savePaymentMethods(
    String key,
    List<PaymentMethod> methods,
  ) async {
    try {
      await widget.state.store.updateSettings({
        key: {
          'methods': methods.map((m) => m.toJson()).toList(),
        },
      });
      await widget.state.refreshSettings();
      if (mounted) showSnack(context, s('settingsSaved'));
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  Future<void> _deletePaymentMethod(String key, String id) async {
    final ok = await showConfirm(
      context,
      title: s('deleteMethod'),
      body: s('confirmDelete'),
      confirmLabel: s('deleteMethod'),
      danger: true,
    );
    if (!ok || !mounted) return;
    final settings = widget.state.settings;
    final current = key == 'payments_thb'
        ? settings.paymentsThb
        : settings.paymentsMmk;
    final next = current.where((m) => m.id != id).toList();
    try {
      await widget.state.store.updateSettings({
        key: {
          'methods': next.map((m) => m.toJson()).toList(),
        },
      });
      await widget.state.refreshSettings();
      if (mounted) showSnack(context, s('savedOk'));
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  Future<void> _saveReceiveMethods() async {
    try {
      await widget.state.store.updateSettings({
        'receive_methods': {
          'methods': _recvWorking.map((m) => m.toJson()).toList(),
        },
      });
      await widget.state.refreshSettings();
      if (mounted) showSnack(context, s('settingsSaved'));
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  Future<void> _removeAdmin(AdminEntry admin) async {
    final selfId = widget.state.user?.id;
    if (admin.userId == selfId) {
      showSnack(context, s('cannotRemoveSelf'), isError: true);
      return;
    }
    final ok = await showConfirm(
      context,
      title: s('removeAdmin'),
      body: s('confirmDelete'),
      confirmLabel: s('removeAdmin'),
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.state.store.removeAdmin(admin.userId);
      if (!mounted) return;
      showSnack(context, s('adminRemoved'));
      setState(() => _adminsFuture = _loadAdmins());
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  Future<void> _addAdmin() async {
    final email = _addAdminEmail.text.trim();
    final user = widget.state.user;
    setState(() => _addAdminError = '');
    if (email.isEmpty) {
      setState(() => _addAdminError = s('fillAll'));
      return;
    }
    if (user == null) return;
    try {
      await widget.state.store.addAdmin(email, user.id);
      if (!mounted) return;
      showSnack(context, s('adminAdded'));
      _addAdminEmail.clear();
      setState(() => _adminsFuture = _loadAdmins());
    } on StoreException catch (e) {
      if (!mounted) return;
      setState(() {
        _addAdminError =
            e.code == 'user_not_found' ? s('userNotFoundAdmin') : s('errorGeneric');
      });
    } catch (_) {
      if (mounted) setState(() => _addAdminError = s('errorGeneric'));
    }
  }

  @override
  Widget build(BuildContext context) {
    _fillFromSettings();
    final settings = widget.state.settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shop form.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(s('settingsTitle')),
                const SizedBox(height: 14),
                TextField(
                  controller: _shopName,
                  decoration: InputDecoration(
                    labelText: s('shopName'),
                    hintText: s('appName'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _announcement,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: s('announcement'),
                    hintText: s('announcementPh'),
                  ),
                ),
                CheckboxListTile(
                  value: _isOpen,
                  onChanged: (v) => setState(() => _isOpen = v ?? true),
                  title: Text(s('isOpen')),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                TextField(
                  controller: _openHours,
                  decoration: InputDecoration(
                    labelText: s('openHours'),
                    hintText: s('openHoursPh'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _telegram,
                  decoration: InputDecoration(
                    labelText: s('contactTelegram'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: s('contactPhone'),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _saveShop,
                  child: Text(s('saveSettings')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Payment editors.
          _PaymentEditor(
            titleKey: s('paymentsThbTitle'),
            settingsKey: 'payments_thb',
            methods: settings.paymentsThb,
            onSave: (methods) => _savePaymentMethods('payments_thb', methods),
            onDelete: (id) => _deletePaymentMethod('payments_thb', id),
          ),
          const SizedBox(height: 12),
          _PaymentEditor(
            titleKey: s('paymentsMmkTitle'),
            settingsKey: 'payments_mmk',
            methods: settings.paymentsMmk,
            onSave: (methods) => _savePaymentMethods('payments_mmk', methods),
            onDelete: (id) => _deletePaymentMethod('payments_mmk', id),
          ),
          const SizedBox(height: 12),
          // Receive-method toggles.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(s('receiveMethodsTitle')),
                const SizedBox(height: 6),
                Text(
                  s('receiveMethodsHint'),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
                ..._recvWorking.asMap().entries.map((entry) {
                  final m = entry.value;
                  return CheckboxListTile(
                    value: m.enabled,
                    onChanged: (v) {
                      setState(() {
                        _recvWorking[entry.key] = ReceiveMethodEntry(
                          label: m.label,
                          enabled: v ?? true,
                        );
                      });
                    },
                    title: Text(receiveMethodLabel(m.label)),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _saveReceiveMethods,
                  child: Text(s('saveSettings')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Admins.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(s('adminsTitle')),
                const SizedBox(height: 10),
                FutureBuilder<List<AdminEntry>>(
                  future: _adminsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LoadingView();
                    }
                    final admins = snapshot.data ?? const [];
                    if (admins.isEmpty) {
                      return EmptyText(s('noHistory'));
                    }
                    final selfId = widget.state.user?.id;
                    return Column(
                      children: admins.map((a) {
                        final isSelf = a.userId == selfId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      a.email,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSelf)
                                OutlinedButton(
                                  onPressed: () => _removeAdmin(a),
                                  child: Text(s('removeAdmin')),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const Divider(height: 24),
                TextField(
                  controller: _addAdminEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: s('addAdminByEmail'),
                  ),
                ),
                FieldError(_addAdminError),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _addAdmin,
                  child: Text(s('addAdminBtn')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One payment-method editor (list + add/edit form), mirroring
/// methodsEditor() in js/app.js. The edit draft lives in this widget;
/// tapping Edit fills the form, Save writes the whole list.
class _PaymentEditor extends StatefulWidget {
  const _PaymentEditor({
    required this.titleKey,
    required this.settingsKey,
    required this.methods,
    required this.onSave,
    required this.onDelete,
  });

  final String titleKey;
  final String settingsKey;
  final List<PaymentMethod> methods;
  final Future<void> Function(List<PaymentMethod>) onSave;
  final Future<void> Function(String) onDelete;

  @override
  State<_PaymentEditor> createState() => _PaymentEditorState();
}

class _PaymentEditorState extends State<_PaymentEditor> {
  final _label = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _qrUrl = TextEditingController();
  bool _enabled = true;
  String? _editingId;

  @override
  void dispose() {
    _label.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _qrUrl.dispose();
    super.dispose();
  }

  void _startEdit(PaymentMethod m) {
    setState(() {
      _editingId = m.id;
      _label.text = m.label;
      _accountName.text = m.accountName;
      _accountNumber.text = m.accountNumber;
      _qrUrl.text = m.qrImageUrl;
      _enabled = m.enabled;
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _label.clear();
      _accountName.clear();
      _accountNumber.clear();
      _qrUrl.clear();
      _enabled = true;
    });
  }

  Future<void> _submit() async {
    final label = _label.text.trim();
    final accountNumber = _accountNumber.text.trim();
    if (label.isEmpty || accountNumber.isEmpty) {
      showSnack(context, s('fillAll'), isError: true);
      return;
    }
    final entry = PaymentMethod(
      id: _editingId ?? 'm-${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      accountName: _accountName.text.trim(),
      accountNumber: accountNumber,
      qrImageUrl: _qrUrl.text.trim(),
      enabled: _enabled,
    );
    final methods = [...widget.methods];
    final idx = methods.indexWhere((m) => m.id == entry.id);
    if (idx >= 0) {
      methods[idx] = entry;
    } else {
      methods.add(entry);
    }
    await widget.onSave(methods);
    if (mounted) _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(widget.titleKey),
          const SizedBox(height: 10),
          if (widget.methods.isEmpty)
            EmptyText(s('noMethods'))
          else
            ...widget.methods.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _EnabledPill(enabled: m.enabled),
                      ],
                    ),
                    Text(
                      '${m.accountName} · ${m.accountNumber}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (m.qrImageUrl.isNotEmpty)
                      Text(
                        m.qrImageUrl,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => _startEdit(m),
                          child: Text(s('editMethod')),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => widget.onDelete(m.id),
                          child: Text(s('deleteMethod')),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 24),
          TextField(
            controller: _label,
            decoration: InputDecoration(labelText: s('methodNameLabel')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountName,
            decoration: InputDecoration(labelText: s('accountName')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNumber,
            decoration: InputDecoration(labelText: s('accountNumber')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qrUrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: s('qrUrl')),
          ),
          CheckboxListTile(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v ?? true),
            title: Text(s('enabled')),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          ElevatedButton(
            onPressed: _submit,
            child: Text(_editingId == null ? s('addMethod') : s('save')),
          ),
        ],
      ),
    );
  }
}

/// Enabled = blue pill, disabled = grey pill (pill--open / pill--closed).
/// The disabled label reuses the website's 'blocked' string, as the
/// website's methodsEditor does.
class _EnabledPill extends StatelessWidget {
  const _EnabledPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? AppColors.blue : AppColors.line,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        enabled ? s('enabled') : s('blocked'),
        style: TextStyle(
          color: enabled ? Colors.white : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
