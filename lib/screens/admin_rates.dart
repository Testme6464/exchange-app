// Admin rates tab: rate + fee + limits editor and the last-14 history
// bar chart — mirrors renderAdminRates() in js/app.js.

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

class AdminRatesTab extends StatefulWidget {
  const AdminRatesTab({required this.state, super.key});

  final AppState state;

  @override
  State<AdminRatesTab> createState() => _AdminRatesTabState();
}

class _AdminRatesTabState extends State<AdminRatesTab> {
  final _thb = TextEditingController();
  final _mmk = TextEditingController();
  final _fee = TextEditingController();
  final _minThb = TextEditingController();
  final _maxThb = TextEditingController();
  final _minMmk = TextEditingController();
  final _maxMmk = TextEditingController();
  String _error = '';
  bool _saving = false;
  bool _fieldsFilled = false;
  late Future<List<RateHistoryEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
    _fillFields();
  }

  @override
  void dispose() {
    _thb.dispose();
    _mmk.dispose();
    _fee.dispose();
    _minThb.dispose();
    _maxThb.dispose();
    _minMmk.dispose();
    _maxMmk.dispose();
    super.dispose();
  }

  Future<List<RateHistoryEntry>> _loadHistory() async {
    try {
      return await widget.state.store.getRateHistory(14);
    } catch (_) {
      return const [];
    }
  }

  void _fillFields() {
    if (_fieldsFilled) return;
    _fieldsFilled = true;
    final settings = widget.state.settings;
    _thb.text = _num(settings.rates.thbToMmk);
    _mmk.text = _num(settings.rates.mmkToThb);
    _fee.text = _num(settings.fees.feePercent);
    _minThb.text = _num(settings.fees.minThb);
    _maxThb.text = _num(settings.fees.maxThb);
    _minMmk.text = _num(settings.fees.minMmk);
    _maxMmk.text = _num(settings.fees.maxMmk);
  }

  String _num(double v) {
    if (v == v.truncateToDouble()) return v.truncate().toString();
    return v.toString();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? double.nan;

  Future<void> _save() async {
    final user = widget.state.user;
    if (user == null) return;
    final thb = _parse(_thb);
    final mmk = _parse(_mmk);
    final feePct = _parse(_fee);
    final fees = FeesSettings(
      feePercent: feePct,
      minThb: _parse(_minThb),
      maxThb: _parse(_maxThb),
      minMmk: _parse(_minMmk),
      maxMmk: _parse(_maxMmk),
    );
    setState(() => _error = '');
    if (thb.isNaN || thb <= 0 || mmk.isNaN || mmk <= 0 || feePct.isNaN || feePct < 0) {
      setState(() => _error = s('invalidAmount'));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.state.store.setRates(thb, mmk, user.id);
      await widget.state.store.updateSettings({'fees': fees.toJson()});
      await widget.state.refreshSettings();
      if (!mounted) return;
      showSnack(context, s('ratesSaved'));
      setState(() {
        _saving = false;
        _historyFuture = _loadHistory();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = s('errorGeneric');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.state.settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(s('ratesTitle')),
                const SizedBox(height: 8),
                Text(
                  '${s('currentRates')}: '
                  '${s('rateLineThb', {'rate': fmtNum(settings.rates.thbToMmk, 2)})} · '
                  '${s('rateLineMmk', {'rate': fmtNum(settings.rates.mmkToThb, 2)})}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(s('ratesConfirmHint'),
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 14),
                _numberField(_thb, s('rateThbToMmkField')),
                const SizedBox(height: 12),
                _numberField(_mmk, s('rateMmkToThbField')),
                const SizedBox(height: 12),
                _numberField(_fee, s('feePercent')),
                const SizedBox(height: 12),
                _numberField(_minThb, s('minThb')),
                const SizedBox(height: 12),
                _numberField(_maxThb, s('maxThb')),
                const SizedBox(height: 12),
                _numberField(_minMmk, s('minMmk')),
                const SizedBox(height: 12),
                _numberField(_maxMmk, s('maxMmk')),
                FieldError(_error),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(s('saveRates')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardTitle(s('rateHistoryTitle')),
                const SizedBox(height: 12),
                FutureBuilder<List<RateHistoryEntry>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LoadingView();
                    }
                    final history = snapshot.data ?? const [];
                    if (history.isEmpty) {
                      return EmptyText(s('noHistory'));
                    }
                    final values =
                        history.map((h) => h.thbToMmk).toList();
                    final min =
                        values.reduce((a, b) => a < b ? a : b);
                    final max =
                        values.reduce((a, b) => a > b ? a : b);
                    final span = (max - min) == 0 ? 1.0 : max - min;
                    return Column(
                      children: history.map((h) {
                        final pct =
                            12 + ((h.thbToMmk - min) / span) * 88;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 118,
                                child: Text(
                                  fmtDateTime(h.createdAt),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: AppColors.bluePale,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: pct / 100,
                                    child: Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppColors.blue,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  fmtNum(h.thbToMmk, 2),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}
