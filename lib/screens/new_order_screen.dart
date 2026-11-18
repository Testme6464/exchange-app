// 3-step order wizard — mirrors renderWizardStep1/2/3 in js/app.js:
// (1) direction + amount + live quote, (2) shop payment accounts,
// (3) receiver + slip upload. The rate is locked at creation from a
// fresh settings re-read, like the website.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({
    required this.state,
    required this.onOrderCreated,
    this.initialDirection,
    this.initialSendAmount,
    super.key,
  });

  final AppState state;
  final ValueChanged<String> onOrderCreated;

  /// Optional prefill from the dashboard smart calculator: direction +
  /// send amount. The quote always uses the live shop rate.
  final String? initialDirection;
  final double? initialSendAmount;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  int _step = 1;
  String _direction = 'THB_TO_MMK';
  final _amount = TextEditingController();
  String _receiveMethod = 'KBZPay';
  final _recvName = TextEditingController();
  final _recvAccount = TextEditingController();
  final _recvPhone = TextEditingController();
  final _txn = TextEditingController();
  bool _saveReceiver = false;
  PickedImage? _slip;
  bool _pickingSlip = false;
  bool _submitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    // Prefill receiver from saved receivers / profile, like the website.
    final profile = widget.state.profile;
    if (profile != null) {
      final saved = profile.receivers;
      if (saved.isNotEmpty) {
        _receiveMethod = saved.first.method.isNotEmpty
            ? saved.first.method
            : 'KBZPay';
        _recvName.text = saved.first.name;
        _recvAccount.text = saved.first.account;
        _recvPhone.text = saved.first.phone;
      } else if (profile.displayName.isNotEmpty) {
        _recvName.text = profile.displayName;
        _recvPhone.text = profile.phone;
      }
    }
    // Prefill from the dashboard smart calculator, if the user tapped
    // "order with this amount". Only direction + send amount carry
    // over; the quote always uses the live shop rate.
    if (widget.initialDirection != null) {
      _direction = widget.initialDirection!;
    }
    if (widget.initialSendAmount != null) {
      _amount.text = plainAmount(
        widget.initialSendAmount!,
        _direction == 'THB_TO_MMK' ? 'THB' : 'MMK',
      );
    }
    _normalizeMethod();
    // Fresh shop status on entry, so a shop closed since boot blocks
    // orders immediately instead of using stale cached settings.
    widget.state.refreshSettings();
  }

  @override
  void dispose() {
    _amount.dispose();
    _recvName.dispose();
    _recvAccount.dispose();
    _recvPhone.dispose();
    _txn.dispose();
    super.dispose();
  }

  /// Step 3 resets the method to the first enabled one when the current
  /// method was disabled by the admin.
  void _normalizeMethod() {
    final enabled = enabledReceiveMethods(widget.state.settings);
    if (enabled.isNotEmpty && !enabled.contains(_receiveMethod)) {
      _receiveMethod = enabled.first;
    }
  }

  double? get _sendAmount => double.tryParse(_amount.text.trim());

  Quote? get _quote {
    final amount = _sendAmount;
    if (amount == null) return null;
    return calcQuote(_direction, amount, widget.state.settings);
  }

  void _nextFromStep1() {
    final amount = _sendAmount;
    final err = amount == null
        ? s('invalidAmount')
        : validateAmount(_direction, amount, widget.state.settings);
    if (err.isNotEmpty) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = '';
      _step = 2;
    });
  }

  Future<void> _pickSlip() async {
    setState(() => _pickingSlip = true);
    final picked = await pickSlipImage(context);
    if (!mounted) return;
    setState(() {
      _pickingSlip = false;
      if (picked != null) _slip = picked;
    });
  }

  void _useSaved(Receiver r) {
    setState(() {
      _receiveMethod = r.method;
      _recvName.text = r.name;
      _recvAccount.text = r.account;
      _recvPhone.text = r.phone;
      _normalizeMethod();
    });
  }

  Future<void> _submit() async {
    final user = widget.state.user;
    if (user == null || _submitting) return;
    final receiverName = _recvName.text.trim();
    final receiverAccount = _recvAccount.text.trim();
    setState(() => _error = '');
    if (receiverName.isEmpty || receiverAccount.isEmpty) {
      setState(() => _error = s('fillAll'));
      return;
    }
    if (_slip == null) {
      setState(() => _error = s('slipRequired'));
      return;
    }
    final amount = _sendAmount;
    final err = amount == null
        ? s('invalidAmount')
        : validateAmount(_direction, amount, widget.state.settings);
    if (err.isNotEmpty) {
      setState(() => _error = err);
      return;
    }
    setState(() => _submitting = true);
    try {
      // Re-read settings so the locked rate is the freshest one.
      await widget.state.refreshSettings();
      // The shop may have closed mid-wizard: refuse before uploading.
      if (!widget.state.settings.shop.isOpen) {
        if (!mounted) return;
        setState(() {
          _error = s('shopClosedBlock');
          _submitting = false;
        });
        return;
      }
      final freshQuote = calcQuote(
        _direction,
        amount!,
        widget.state.settings,
      );
      if (freshQuote == null) throw StateError('no quote');
      final slipPath = await widget.state.store.uploadFile(
        'slips',
        user.id,
        _slip!.bytes,
        _slip!.fileName,
      );
      final order = await widget.state.store.createOrder(
        userId: user.id,
        direction: _direction,
        sendAmount: amount,
        sendCurrency: freshQuote.sendCurrency,
        receiveAmount: freshQuote.net,
        receiveCurrency: freshQuote.receiveCurrency,
        rate: freshQuote.rate,
        fee: freshQuote.fee,
        receiveMethod: _receiveMethod,
        receiverName: receiverName,
        receiverAccount: receiverAccount,
        receiverPhone: _recvPhone.text.trim(),
        slipPath: slipPath,
        slipTxnId: _txn.text.trim(),
      );
      if (_saveReceiver) {
        // Best-effort, like the website: dedup on method + account.
        try {
          final current = widget.state.profile?.receivers ?? [];
          final exists = current.any(
            (r) => r.method == _receiveMethod && r.account == receiverAccount,
          );
          if (!exists) {
            final updated = await widget.state.store.updateProfile(
              user.id,
              receivers: [
                ...current,
                Receiver(
                  method: _receiveMethod,
                  name: receiverName,
                  account: receiverAccount,
                  phone: _recvPhone.text.trim(),
                ),
              ],
            );
            widget.state.setProfile(updated);
          }
        } catch (_) {
          // Non-fatal: the order is already created.
        }
      }
      if (!mounted) return;
      showSnack(context, s('orderCreated'));
      widget.onOrderCreated(order.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = s('errorGeneric');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shop closed: no order form at all, just the closed message.
    if (!widget.state.settings.shop.isOpen) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s('newOrderTitle'),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.bluePale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                s('shopClosedBlock'),
                style: const TextStyle(
                  color: AppColors.blueDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s('newOrderTitle'),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _StepsIndicator(step: _step),
          const SizedBox(height: 12),
          if (_step == 1) _buildStep1(),
          if (_step == 2) _buildStep2(),
          if (_step == 3) _buildStep3(),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final settings = widget.state.settings;
    final lim = amountLimits(_direction, settings);
    final quote = _quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s('directionLabel'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ChipRow(
                options: [
                  (id: 'THB_TO_MMK', label: s('directionThbToMmk')),
                  (id: 'MMK_TO_THB', label: s('directionMmkToThb')),
                ],
                selected: _direction,
                onSelected: (id) => setState(() {
                  _direction = id;
                  _error = '';
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: s('youSend')),
                onChanged: (_) => setState(() => _error = ''),
              ),
              const SizedBox(height: 4),
              Text(
                s('minMax', {
                  'min': fmtMoney(lim.min, lim.currency),
                  'max': fmtMoney(lim.max, lim.currency),
                }),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
              if (quote != null) ...[
                const SizedBox(height: 12),
                KvRow(label: s('rateUsed'), value: fmtNum(quote.rate, 2)),
                KvRow(
                  label: s('youReceive'),
                  value: fmtMoney(quote.gross, quote.receiveCurrency),
                ),
                KvRow(
                  label:
                      '${s('fee')} (${fmtNum(settings.fees.feePercent, 2)}%)',
                  value: fmtMoney(quote.fee, quote.receiveCurrency),
                ),
                KvRow(
                  label: s('netReceive'),
                  value: fmtMoney(quote.net, quote.receiveCurrency),
                ),
              ],
              FieldError(_error),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _nextFromStep1,
                child: Text(s('next')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final settings = widget.state.settings;
    final quote = _quote;
    final methods = _direction == 'THB_TO_MMK'
        ? settings.paymentsThb
        : settings.paymentsMmk;
    final enabled = methods.where((m) => m.enabled).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardTitle(s('payInstructions')),
              const SizedBox(height: 10),
              KvRow(
                label: s('youSend'),
                value: quote == null
                    ? ''
                    : fmtMoney(_sendAmount ?? 0, quote.sendCurrency),
              ),
              KvRow(
                label: s('netReceive'),
                value: quote == null
                    ? ''
                    : fmtMoney(quote.net, quote.receiveCurrency),
              ),
              const SizedBox(height: 12),
              if (enabled.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bluePale,
                    border: Border.all(color: AppColors.blueLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    [
                      s('noPayMethod'),
                      if (settings.shop.contactTelegram.isNotEmpty ||
                          settings.shop.contactPhone.isNotEmpty)
                        '${s('contactUs')}: '
                            '${[
                              settings.shop.contactTelegram,
                              settings.shop.contactPhone,
                            ].where((v) => v.isNotEmpty).join(' · ')}',
                    ].join('\n'),
                    style: const TextStyle(fontSize: 14),
                  ),
                )
              else
                ...enabled.map(_paymentMethodCard),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                child: Text(s('back')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  _normalizeMethod();
                  setState(() => _step = 3);
                },
                child: Text(s('next')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paymentMethodCard(PaymentMethod m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
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
              OutlinedButton(
                onPressed: () => copyText(context, m.accountNumber),
                child: Text(s('copy')),
              ),
            ],
          ),
          KvRow(label: s('accountName'), value: m.accountName),
          KvRow(label: s('accountNumber'), value: m.accountNumber),
          if (m.qrImageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                m.qrImageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (ctx, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final settings = widget.state.settings;
    final quote = _quote;
    final saved = widget.state.profile?.receivers ?? [];
    final enabled = enabledReceiveMethods(settings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardTitle(s('confirmTitle')),
              const SizedBox(height: 8),
              KvRow(
                label: s('youSend'),
                value: quote == null
                    ? ''
                    : fmtMoney(_sendAmount ?? 0, quote.sendCurrency),
              ),
              KvRow(
                label: s('rate'),
                value: quote == null ? '' : fmtNum(quote.rate, 2),
              ),
              KvRow(
                label: s('fee'),
                value: quote == null
                    ? ''
                    : fmtMoney(quote.fee, quote.receiveCurrency),
              ),
              KvRow(
                label: s('netReceive'),
                value: quote == null
                    ? ''
                    : fmtMoney(quote.net, quote.receiveCurrency),
              ),
              const SizedBox(height: 6),
              Text(
                s('confirmText'),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (saved.isNotEmpty) ...[
                Text(
                  s('savedReceivers'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...saved.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${receiveMethodLabel(r.method)} — ${r.name} · ${r.account}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _useSaved(r),
                          child: Text(s('useSaved')),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
              ],
              LabeledDropdown(
                label: s('receiveMethod'),
                value: enabled.contains(_receiveMethod)
                    ? _receiveMethod
                    : enabled.first,
                items: enabled
                    .map((m) => (value: m, label: receiveMethodLabel(m)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _receiveMethod = v);
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
              CheckboxListTile(
                value: _saveReceiver,
                onChanged: (v) => setState(() => _saveReceiver = v ?? false),
                title: Text(s('saveReceiver')),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s('slipUpload'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickingSlip ? null : _pickSlip,
                icon: const Icon(Icons.upload_outlined),
                label: Text(
                  _slip == null ? s('slipUpload') : _slip!.fileName,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s('slipUploadHint'),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
              if (_slip != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    Uint8List.fromList(_slip!.bytes),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _txn,
                decoration: InputDecoration(labelText: s('slipTxn')),
              ),
              const SizedBox(height: 4),
              Text(
                s('txnHint'),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
              FieldError(_error),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _step = 2),
                      child: Text(s('back')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(s('submitOrder')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepsIndicator extends StatelessWidget {
  const _StepsIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final labels = [s('wizardStep1'), s('wizardStep2'), s('wizardStep3')];
    return Row(
      children: List.generate(3, (i) {
        final active = step == i + 1;
        final done = step > i + 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.blue
                  : done
                      ? AppColors.blueLight
                      : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppColors.blue : AppColors.line,
              ),
            ),
            child: Text(
              labels[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active
                    ? Colors.white
                    : done
                        ? AppColors.blueDark
                        : AppColors.muted,
              ),
            ),
          ),
        );
      }),
    );
  }
}
