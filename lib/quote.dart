// Pure helpers mirroring js/app.js exactly: quote math, amount limits,
// receive-method filtering, number/date formatting, contact links,
// order-number generation, file-name sanitizing. No Flutter imports,
// so this file is unit-testable on its own.

import 'dart:math' as math;

import 'models.dart';
import 'strings.dart';

/// Result of [calcQuote]: rate locked at order creation, gross/fee/net in
/// the RECEIVE currency.
class Quote {
  const Quote({
    required this.rate,
    required this.gross,
    required this.fee,
    required this.net,
    required this.sendCurrency,
    required this.receiveCurrency,
  });

  final double rate;
  final double gross;
  final double fee;
  final double net;
  final String sendCurrency;
  final String receiveCurrency;
}

/// Quote math (mirrors calcQuote in js/app.js and README.md):
/// THB_TO_MMK: gross = send * thb_to_mmk (MMK), fee on gross, net = gross - fee.
/// MMK_TO_THB: gross = send / mmk_to_thb (THB), fee on gross, net = gross - fee.
/// Fee is always in the RECEIVE currency. MMK rounds to whole kyat, THB to 2dp.
/// [rateOverride] (smart calculator): a custom rate typed by the user
/// replaces the shop rate; the fee percent still applies. Orders always
/// requote at the live shop rate.
Quote? calcQuote(
  String direction,
  double sendAmount,
  AppSettings settings, {
  double? rateOverride,
}) {
  final send = sendAmount;
  if (send.isNaN || send.isInfinite || send <= 0) return null;
  final feePct = settings.fees.feePercent;
  final requested = rateOverride;
  final customRate = (requested != null &&
          !requested.isNaN &&
          !requested.isInfinite &&
          requested > 0)
      ? requested
      : null;
  if (direction == 'THB_TO_MMK') {
    final rate = customRate ?? settings.rates.thbToMmk;
    final gross = send * rate;
    final fee = (gross * feePct / 100).roundToDouble();
    final grossRounded = gross.roundToDouble();
    return Quote(
      rate: rate,
      gross: grossRounded,
      fee: fee,
      net: grossRounded - fee,
      sendCurrency: 'THB',
      receiveCurrency: 'MMK',
    );
  }
  final rate = customRate ?? settings.rates.mmkToThb;
  final gross = send / rate;
  final fee = ((gross * feePct / 100 * 100).roundToDouble()) / 100;
  final net = ((gross - fee) * 100).roundToDouble() / 100;
  return Quote(
    rate: rate,
    gross: ((gross * 100).roundToDouble()) / 100,
    fee: fee,
    net: net,
    sendCurrency: 'MMK',
    receiveCurrency: 'THB',
  );
}

/// Reverse quote for the smart calculator (mirrors calcReverseQuote in
/// js/app.js): given the NET amount the user wants to receive, find the
/// smallest send amount (in the send currency's smallest unit) whose
/// forward quote nets at least that much. Uses the same rate override as
/// [calcQuote], so a custom rate round-trips exactly. Returns null for
/// invalid input.
({double send, Quote quote})? calcReverseQuote(
  String direction,
  double netAmount,
  AppSettings settings, {
  double? rateOverride,
}) {
  final target = netAmount;
  if (target.isNaN || target.isInfinite || target <= 0) return null;
  final feePct = settings.fees.feePercent;
  if (feePct >= 100) return null;
  final requested = rateOverride;
  final customRate = (requested != null &&
          !requested.isNaN &&
          !requested.isInfinite &&
          requested > 0)
      ? requested
      : null;
  final rate = customRate ??
      (direction == 'THB_TO_MMK'
          ? settings.rates.thbToMmk
          : settings.rates.mmkToThb);
  if (rate <= 0) return null;
  final grossNeeded = target / (1 - feePct / 100);
  if (direction == 'THB_TO_MMK') {
    // Send currency THB: smallest unit 0.01; iterate in integer cents
    // so float drift never skips a cent. Walk up to the first send that
    // reaches the target, then back down while the previous cent still
    // reaches it — gross rounding can make a smaller send sufficient.
    var cents = (grossNeeded / rate * 100).ceil();
    Quote? q;
    for (var i = 0; i < 10000; i++) {
      q = calcQuote(direction, cents / 100, settings, rateOverride: rate);
      if (q != null && q.net >= target) break;
      cents++;
    }
    if (q == null || q.net < target) return null;
    var found = q;
    while (cents > 1) {
      final prev = calcQuote(direction, (cents - 1) / 100, settings,
          rateOverride: rate);
      if (prev != null && prev.net >= target) {
        cents--;
        found = prev;
      } else {
        break;
      }
    }
    return (send: cents / 100, quote: found);
  }
  // Send currency MMK: whole kyat; same up-then-down walk.
  var send = (grossNeeded * rate).ceilToDouble();
  Quote? q;
  for (var i = 0; i < 10000; i++) {
    q = calcQuote(direction, send, settings, rateOverride: rate);
    if (q != null && q.net >= target) break;
    send += 1;
  }
  if (q == null || q.net < target) return null;
  var found = q;
  while (send > 1) {
    final prev =
        calcQuote(direction, send - 1, settings, rateOverride: rate);
    if (prev != null && prev.net >= target) {
      send -= 1;
      found = prev;
    } else {
      break;
    }
  }
  return (send: send, quote: found);
}

/// Plain (no thousands separators) amount text for prefilling inputs:
/// THB to 2dp trimmed, MMK whole. Mirrors fmtPlainAmount in js/app.js.
String plainAmount(double value, String currency) {
  if (value.isNaN || value.isInfinite) return '';
  if (currency == 'THB') {
    var fixed = value.toStringAsFixed(2);
    while (fixed.contains('.') && fixed.endsWith('0')) {
      fixed = fixed.substring(0, fixed.length - 1);
    }
    if (fixed.endsWith('.')) fixed = fixed.substring(0, fixed.length - 1);
    return fixed;
  }
  return value.round().toString();
}

/// Quick send amounts offered by the smart calculator, per direction.
/// Mirrors QUICK_SEND in js/app.js.
const Map<String, List<double>> quickSendAmounts = {
  'THB_TO_MMK': [100, 500, 1000, 5000, 10000],
  'MMK_TO_THB': [50000, 100000, 500000, 1000000, 2000000],
};

/// Mirrors amountLimits() in js/app.js.
({double min, double max, String currency}) amountLimits(
  String direction,
  AppSettings settings,
) {
  if (direction == 'THB_TO_MMK') {
    return (
      min: settings.fees.minThb,
      max: settings.fees.maxThb,
      currency: 'THB',
    );
  }
  return (
    min: settings.fees.minMmk,
    max: settings.fees.maxMmk,
    currency: 'MMK',
  );
}

/// Mirrors validateAmount(): '' when valid, otherwise a Burmese message.
String validateAmount(
  String direction,
  double sendAmount,
  AppSettings settings,
) {
  if (sendAmount.isNaN || sendAmount.isInfinite || sendAmount <= 0) {
    return s('invalidAmount');
  }
  final lim = amountLimits(direction, settings);
  if (sendAmount < lim.min) return s('belowMin');
  if (sendAmount > lim.max) return s('aboveMax');
  return '';
}

/// The receive-method labels from js/app.js RECEIVE_METHODS.
const List<String> receiveMethodsFallback = [
  'KBZPay',
  'WavePay',
  'AYA Pay',
  'CB Pay',
  'KBZ Bank',
  'PromptPay',
];

/// Mirrors enabledReceiveMethods() in js/app.js: only admin-enabled
/// methods; if the admin disabled everything, fall back to the full list
/// so ordering never hard-breaks.
List<String> enabledReceiveMethods(AppSettings settings) {
  final list = settings.receiveMethods;
  var enabled = list
      .where((m) => m.label.isNotEmpty && m.enabled)
      .map((m) => m.label)
      .toList();
  if (enabled.isEmpty) {
    enabled = list.where((m) => m.label.isNotEmpty).map((m) => m.label).toList();
  }
  if (enabled.isEmpty) {
    enabled = [...receiveMethodsFallback, 'Other'];
  }
  return enabled;
}

/// Mirrors receiveMethodLabel(): the stored value 'Other' displays as
/// the localized "အခြား" label.
String receiveMethodLabel(String value) {
  return value == 'Other' ? s('methodOther') : value;
}

// ---------------------------------------------------------------------
// Formatting (mirrors fmtNum / fmtMoney / fmtDateTime / fmtTimeAgo).
// ---------------------------------------------------------------------

/// Thousands-separated number with fixed decimals, en-US style.
/// Mirrors Number.toLocaleString('en-US', ...) in js/app.js.
String fmtNum(num n, [int decimals = 0]) {
  final value = n.toDouble();
  if (value.isNaN || value.isInfinite) return '0';
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  var out = buf.toString();
  if (decimals > 0) out += '.${parts[1]}';
  return negative ? '-$out' : out;
}

/// Money with the Burmese currency label. THB shows 2 decimals, MMK whole.
String fmtMoney(num amount, String currency) {
  final decimals = currency == 'THB' ? 2 : 0;
  final label = currency == 'THB' ? s('thb') : s('mmk');
  return '${fmtNum(amount, decimals)} $label';
}

const List<String> _monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _pad2(int n) => n < 10 ? '0$n' : '$n';

/// Mirrors fmtDateTime(): "02 Nov 2026, 14:30" in local time.
String fmtDateTime(DateTime? dt) {
  if (dt == null) return s('neverUpdated');
  final local = dt.toLocal();
  return '${_pad2(local.day)} ${_monthAbbr[local.month - 1]} '
      '${local.year}, ${_pad2(local.hour)}:${_pad2(local.minute)}';
}

/// Mirrors fmtTimeAgo(): relative label, or "မသိရပါ" when unknown.
String fmtTimeAgo(DateTime? dt, {DateTime? now}) {
  if (dt == null) return s('neverUpdated');
  final current = (now ?? DateTime.now()).toLocal();
  final ms = current.difference(dt.toLocal()).inMilliseconds;
  if (ms < 0) return s('justNow');
  final mins = ms ~/ 60000;
  if (mins < 1) return s('justNow');
  if (mins < 60) return s('minutesAgo', {'n': '$mins'});
  final hours = mins ~/ 60;
  if (hours < 24) return s('hoursAgo', {'n': '$hours'});
  return s('daysAgo', {'n': '${hours ~/ 24}'});
}

/// Status pill label, mirroring statusLabel() in js/app.js.
String statusLabel(String status) {
  if (status.isEmpty) return status;
  final key = 'status${status[0].toUpperCase()}${status.substring(1)}';
  return s(key);
}

/// Direction label for an order row.
String orderDirectionLabel(String direction) {
  return direction == 'THB_TO_MMK'
      ? s('directionThbToMmk')
      : s('directionMmkToThb');
}

// ---------------------------------------------------------------------
// Contact links (mirrors telegramLink / viberLink in js/app.js).
// ---------------------------------------------------------------------

String telegramLink(String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(v)) return v;
  if (v.startsWith('t.me/')) return 'https://$v';
  return 'https://t.me/${v.replaceFirst(RegExp(r'^@'), '')}';
}

String viberLink(String phone) {
  final digits = phone.replaceAll(RegExp(r'[\s\-().]'), '');
  if (digits.isEmpty) return '';
  return 'viber://chat?number=${Uri.encodeComponent(digits)}';
}

// ---------------------------------------------------------------------
// Order numbers + file names (mirrors store.js helpers).
// ---------------------------------------------------------------------

const String _orderChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Mirrors generateOrderNo(): BKX-YYYYMMDD-XXXX.
String generateOrderNo([math.Random? random]) {
  final rng = random ?? math.Random();
  final now = DateTime.now();
  final date = '${now.year}${_pad2(now.month)}${_pad2(now.day)}';
  final suffix = String.fromCharCodes(
    List.generate(4, (_) => _orderChars.codeUnitAt(rng.nextInt(_orderChars.length))),
  );
  return 'BKX-$date-$suffix';
}

/// Mirrors sanitizeFileName(): keeps [A-Za-z0-9._-], max 60 chars.
String sanitizeFileName(String name) {
  final cleaned =
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  final trimmed = cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  return trimmed.isEmpty ? 'file' : trimmed;
}
