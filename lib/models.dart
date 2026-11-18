// Data models mirroring the Supabase schema (supabase/schema.sql) and
// the settings shapes in js/app.js DEFAULT_SETTINGS. All parsing is
// defensive: missing/odd fields fall back to safe defaults, never crash.

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String _asString(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

bool _asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  return fallback;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

/// A saved receiver: {method, name, account, phone} (profiles.receivers).
class Receiver {
  const Receiver({
    this.method = '',
    this.name = '',
    this.account = '',
    this.phone = '',
  });

  factory Receiver.fromJson(Map<String, dynamic> json) => Receiver(
        method: _asString(json['method']),
        name: _asString(json['name']),
        account: _asString(json['account']),
        phone: _asString(json['phone']),
      );

  final String method;
  final String name;
  final String account;
  final String phone;

  Map<String, dynamic> toJson() => {
        'method': method,
        'name': name,
        'account': account,
        'phone': phone,
      };
}

/// One row of public.profiles.
class Profile {
  const Profile({
    required this.id,
    this.email = '',
    this.displayName = '',
    this.phone = '',
    this.receivers = const [],
    this.isBlocked = false,
    this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final rawReceivers = json['receivers'];
    final receivers = <Receiver>[];
    if (rawReceivers is List) {
      for (final item in rawReceivers) {
        if (item is Map) receivers.add(Receiver.fromJson(_asMap(item)));
      }
    }
    return Profile(
      id: _asString(json['id']),
      email: _asString(json['email']),
      displayName: _asString(json['display_name']),
      phone: _asString(json['phone']),
      receivers: receivers,
      isBlocked: _asBool(json['is_blocked']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  final String id;
  final String email;
  final String displayName;
  final String phone;
  final List<Receiver> receivers;
  final bool isBlocked;
  final DateTime? createdAt;
}

DateTime? _parseDate(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// One row of public.admins, joined with the profile for display.
class AdminEntry {
  const AdminEntry({
    required this.userId,
    this.email = '',
    this.displayName = '',
    this.createdAt,
  });

  final String userId;
  final String email;
  final String displayName;
  final DateTime? createdAt;
}

/// One row of public.orders. The rate is LOCKED at creation.
class Order {
  const Order({
    required this.id,
    this.orderNo = '',
    this.userId = '',
    this.direction = 'THB_TO_MMK',
    this.sendAmount = 0,
    this.sendCurrency = 'THB',
    this.receiveAmount = 0,
    this.receiveCurrency = 'MMK',
    this.rate = 0,
    this.fee = 0,
    this.receiveMethod = '',
    this.receiverName = '',
    this.receiverAccount = '',
    this.receiverPhone = '',
    this.slipPath,
    this.slipTxnId = '',
    this.status = 'pending',
    this.adminNote = '',
    this.proofPath,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: _asString(json['id']),
        orderNo: _asString(json['order_no']),
        userId: _asString(json['user_id']),
        direction: _asString(json['direction'], 'THB_TO_MMK'),
        sendAmount: _asDouble(json['send_amount']),
        sendCurrency: _asString(json['send_currency'], 'THB'),
        receiveAmount: _asDouble(json['receive_amount']),
        receiveCurrency: _asString(json['receive_currency'], 'MMK'),
        rate: _asDouble(json['rate']),
        fee: _asDouble(json['fee']),
        receiveMethod: _asString(json['receive_method']),
        receiverName: _asString(json['receiver_name']),
        receiverAccount: _asString(json['receiver_account']),
        receiverPhone: _asString(json['receiver_phone']),
        slipPath: json['slip_path'] as String?,
        slipTxnId: _asString(json['slip_txn_id']),
        status: _asString(json['status'], 'pending'),
        adminNote: _asString(json['admin_note']),
        proofPath: json['proof_path'] as String?,
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
        completedAt: _parseDate(json['completed_at']),
      );

  final String id;
  final String orderNo;
  final String userId;
  final String direction;
  final double sendAmount;
  final String sendCurrency;
  final double receiveAmount;
  final String receiveCurrency;
  final double rate;
  final double fee;
  final String receiveMethod;
  final String receiverName;
  final String receiverAccount;
  final String receiverPhone;
  final String? slipPath;
  final String slipTxnId;
  final String status;
  final String adminNote;
  final String? proofPath;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
}

/// One row of public.rate_history.
class RateHistoryEntry {
  const RateHistoryEntry({
    required this.thbToMmk,
    required this.mmkToThb,
    this.createdAt,
  });

  factory RateHistoryEntry.fromJson(Map<String, dynamic> json) =>
      RateHistoryEntry(
        thbToMmk: _asDouble(json['thb_to_mmk']),
        mmkToThb: _asDouble(json['mmk_to_thb']),
        createdAt: _parseDate(json['created_at']),
      );

  final double thbToMmk;
  final double mmkToThb;
  final DateTime? createdAt;
}

/// Settings key `rates`: {thb_to_mmk, mmk_to_thb}.
class RatesSettings {
  const RatesSettings({this.thbToMmk = 141.85, this.mmkToThb = 146.41});

  factory RatesSettings.fromJson(Map<String, dynamic> json) => RatesSettings(
        thbToMmk: _asDouble(json['thb_to_mmk'], 141.85),
        mmkToThb: _asDouble(json['mmk_to_thb'], 146.41),
      );

  final double thbToMmk;
  final double mmkToThb;

  Map<String, dynamic> toJson() => {
        'thb_to_mmk': thbToMmk,
        'mmk_to_thb': mmkToThb,
      };
}

/// Settings key `fees`.
class FeesSettings {
  const FeesSettings({
    this.feePercent = 0,
    this.minThb = 100,
    this.maxThb = 50000,
    this.minMmk = 10000,
    this.maxMmk = 5000000,
  });

  factory FeesSettings.fromJson(Map<String, dynamic> json) => FeesSettings(
        feePercent: _asDouble(json['fee_percent']),
        minThb: _asDouble(json['min_thb'], 100),
        maxThb: _asDouble(json['max_thb'], 50000),
        minMmk: _asDouble(json['min_mmk'], 10000),
        maxMmk: _asDouble(json['max_mmk'], 5000000),
      );

  final double feePercent;
  final double minThb;
  final double maxThb;
  final double minMmk;
  final double maxMmk;

  Map<String, dynamic> toJson() => {
        'fee_percent': feePercent,
        'min_thb': minThb,
        'max_thb': maxThb,
        'min_mmk': minMmk,
        'max_mmk': maxMmk,
      };
}

/// One shop payment account inside `payments_thb` / `payments_mmk`.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    this.label = '',
    this.accountName = '',
    this.accountNumber = '',
    this.qrImageUrl = '',
    this.enabled = true,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: _asString(json['id']),
        label: _asString(json['label']),
        accountName: _asString(json['account_name']),
        accountNumber: _asString(json['account_number']),
        qrImageUrl: _asString(json['qr_image_url']),
        enabled: json['enabled'] == null ? true : _asBool(json['enabled']),
      );

  final String id;
  final String label;
  final String accountName;
  final String accountNumber;
  final String qrImageUrl;
  final bool enabled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'account_name': accountName,
        'account_number': accountNumber,
        'qr_image_url': qrImageUrl,
        'enabled': enabled,
      };
}

/// One entry of the `receive_methods` settings key: {label, enabled}.
class ReceiveMethodEntry {
  const ReceiveMethodEntry({this.label = '', this.enabled = true});

  factory ReceiveMethodEntry.fromJson(Map<String, dynamic> json) =>
      ReceiveMethodEntry(
        label: _asString(json['label']),
        enabled: json['enabled'] == null ? true : _asBool(json['enabled']),
      );

  final String label;
  final bool enabled;

  Map<String, dynamic> toJson() => {'label': label, 'enabled': enabled};
}

/// Settings key `shop`.
class ShopSettings {
  const ShopSettings({
    this.name = '',
    this.announcement = '',
    this.isOpen = true,
    this.openHours = '',
    this.contactTelegram = '',
    this.contactPhone = '',
  });

  factory ShopSettings.fromJson(Map<String, dynamic> json) => ShopSettings(
        name: _asString(json['name']),
        announcement: _asString(json['announcement']),
        isOpen: json['is_open'] == null ? true : _asBool(json['is_open']),
        openHours: _asString(json['open_hours']),
        contactTelegram: _asString(json['contact_telegram']),
        contactPhone: _asString(json['contact_phone']),
      );

  final String name;
  final String announcement;
  final bool isOpen;
  final String openHours;
  final String contactTelegram;
  final String contactPhone;

  Map<String, dynamic> toJson() => {
        'name': name,
        'announcement': announcement,
        'is_open': isOpen,
        'open_hours': openHours,
        'contact_telegram': contactTelegram,
        'contact_phone': contactPhone,
      };
}

/// All settings keys merged over the website's DEFAULT_SETTINGS.
class AppSettings {
  const AppSettings({
    this.rates = const RatesSettings(),
    this.fees = const FeesSettings(),
    this.paymentsThb = const [],
    this.paymentsMmk = const [],
    this.receiveMethods = defaultReceiveMethods,
    this.shop = const ShopSettings(),
  });

  /// Mirrors DEFAULT_SETTINGS.receive_methods in js/app.js.
  static const List<ReceiveMethodEntry> defaultReceiveMethods = [
    ReceiveMethodEntry(label: 'KBZPay', enabled: true),
    ReceiveMethodEntry(label: 'WavePay', enabled: true),
    ReceiveMethodEntry(label: 'AYA Pay', enabled: true),
    ReceiveMethodEntry(label: 'CB Pay', enabled: true),
    ReceiveMethodEntry(label: 'KBZ Bank', enabled: true),
    ReceiveMethodEntry(label: 'PromptPay', enabled: true),
    ReceiveMethodEntry(label: 'Other', enabled: true),
  ];

  /// Mirrors mergeSettings() in js/app.js: stored values overlay the
  /// defaults field-by-field; missing keys keep their defaults.
  factory AppSettings.merge(Map<String, dynamic>? stored) {
    if (stored == null) return const AppSettings();
    final rates = stored['rates'];
    final fees = stored['fees'];
    final paymentsThb = stored['payments_thb'];
    final paymentsMmk = stored['payments_mmk'];
    final receiveMethods = stored['receive_methods'];
    final shop = stored['shop'];
    return AppSettings(
      rates: rates is Map
          ? RatesSettings.fromJson(_mergeDefaults(
              const RatesSettings().toJson(), _asMap(rates)))
          : const RatesSettings(),
      fees: fees is Map
          ? FeesSettings.fromJson(
              _mergeDefaults(const FeesSettings().toJson(), _asMap(fees)))
          : const FeesSettings(),
      paymentsThb: _paymentList(paymentsThb),
      paymentsMmk: _paymentList(paymentsMmk),
      receiveMethods: _receiveList(receiveMethods),
      shop: shop is Map
          ? ShopSettings.fromJson(
              _mergeDefaults(const ShopSettings().toJson(), _asMap(shop)))
          : const ShopSettings(),
    );
  }

  final RatesSettings rates;
  final FeesSettings fees;
  final List<PaymentMethod> paymentsThb;
  final List<PaymentMethod> paymentsMmk;
  final List<ReceiveMethodEntry> receiveMethods;
  final ShopSettings shop;

  static Map<String, dynamic> _mergeDefaults(
    Map<String, dynamic> defaults,
    Map<String, dynamic> stored,
  ) {
    final out = Map<String, dynamic>.from(defaults);
    stored.forEach((key, value) {
      out[key] = value;
    });
    return out;
  }

  static List<PaymentMethod> _paymentList(Object? stored) {
    if (stored is! Map) return const [];
    final methods = _asMap(stored)['methods'];
    if (methods is! List) return const [];
    return methods
        .whereType<Map>()
        .map((m) => PaymentMethod.fromJson(_asMap(m)))
        .toList();
  }

  static List<ReceiveMethodEntry> _receiveList(Object? stored) {
    if (stored is! Map) return defaultReceiveMethods;
    final methods = _asMap(stored)['methods'];
    if (methods is! List || methods.isEmpty) return defaultReceiveMethods;
    return methods
        .whereType<Map>()
        .map((m) => ReceiveMethodEntry.fromJson(_asMap(m)))
        .toList();
  }
}
