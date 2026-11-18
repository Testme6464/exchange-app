// Supabase data layer — mirrors the cloud backend in js/store.js
// (same tables, same RLS policies, same storage buckets as the website).
// No demo/local mode: Supabase is the only backend.

import 'dart:async';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';
import 'quote.dart';

/// Error with a stable machine-readable [code], mirroring makeError()
/// in js/store.js. Codes: blocked, email_in_use, wrong_password,
/// user_not_found, google_cancelled, google_not_configured, generic.
class StoreException implements Exception {
  const StoreException(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => 'StoreException($code): $message';
}

class ExchangeStore {
  ExchangeStore() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  // ------------------------------------------------------------------
  // Auth
  // ------------------------------------------------------------------

  User? get currentUser => _client.auth.currentUser;

  /// Mirrors signUp(): creates the account, upserts the profile when a
  /// session exists, otherwise reports that confirmation is needed.
  Future<({bool needsConfirmation, User? user})> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      final user = res.user;
      if (user != null && res.session != null) {
        await ensureProfile(user);
        return (needsConfirmation: false, user: user);
      }
      return (needsConfirmation: true, user: user);
    } on AuthException catch (e) {
      throw StoreException(_mapAuthError(e), e.message);
    }
  }

  /// Mirrors signIn(): wrong password maps to 'wrong_password'; a blocked
  /// profile is signed straight back out with the 'blocked' error.
  Future<User> signIn(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw const StoreException('wrong_password', 'No user returned.');
      }
      final profile = await ensureProfile(user);
      if (profile != null && profile.isBlocked) {
        await _client.auth.signOut();
        throw const StoreException('blocked', 'Account is blocked.');
      }
      return user;
    } on AuthException catch (e) {
      throw StoreException(_mapAuthError(e), e.message);
    }
  }

  /// Google sign-in via google_sign_in + Supabase signInWithIdToken.
  /// Throws 'google_not_configured' when the client ID placeholder is
  /// still empty, and 'google_cancelled' when the user dismisses the
  /// account picker. The button is hidden while unconfigured, so the
  /// first error should never surface in normal use.
  Future<User> signInWithGoogle() async {
    if (!AppConfig.googleSignInConfigured) {
      throw const StoreException(
        'google_not_configured',
        'Google sign-in is not configured yet.',
      );
    }
    GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const StoreException('google_cancelled', 'Sign-in cancelled.');
      }
      rethrow;
    }
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const StoreException('google_failed', 'No ID token returned.');
    }
    try {
      // google_sign_in v7 exposes only the ID token here (no access
      // token); Supabase signInWithIdToken accepts the ID token alone.
      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final user = res.user;
      if (user == null) {
        throw const StoreException('google_failed', 'No user returned.');
      }
      final profile = await ensureProfile(user);
      if (profile != null && profile.isBlocked) {
        await signOut();
        throw const StoreException('blocked', 'Account is blocked.');
      }
      return user;
    } on AuthException catch (e) {
      throw StoreException(_mapAuthError(e), e.message);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    if (AppConfig.googleSignInConfigured) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Google sign-out is best-effort; the Supabase session is gone.
      }
    }
  }

  /// Sends the password-reset email. The link opens the website's login
  /// page (same redirect the website itself uses), where the recovery
  /// session is picked up. See README for the future deep-link option.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://baht-kyat-exchange.vercel.app/#/login',
    );
  }

  String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'email_in_use';
    }
    if (msg.contains('invalid login credentials')) return 'wrong_password';
    return 'generic';
  }

  // ------------------------------------------------------------------
  // Profiles
  // ------------------------------------------------------------------

  /// Mirrors ensureProfile(): returns the profile, creating it when the
  /// account has none yet (e.g. first Google sign-in).
  Future<Profile?> ensureProfile(User user) async {
    final existing = await getProfile(user.id);
    if (existing != null) return existing;
    final meta = user.userMetadata ?? {};
    final displayName = (meta['display_name'] ?? meta['full_name'] ?? '')
        .toString();
    final fallbackName = displayName.isNotEmpty
        ? displayName
        : user.email?.split('@').first ?? '';
    final data = await _client
        .from('profiles')
        .upsert(
          {
            'id': user.id,
            'email': user.email ?? '',
            'display_name': fallbackName,
            'phone': '',
            'receivers': [],
          },
          onConflict: 'id',
        )
        .select()
        .single();
    return Profile.fromJson(data);
  }

  Future<Profile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Mirrors updateProfile(): only display_name/phone/receivers may be
  /// changed by the owner (RLS + the blocked-flag trigger enforce this).
  Future<Profile> updateProfile(
    String userId, {
    String? displayName,
    String? phone,
    List<Receiver>? receivers,
  }) async {
    final patch = <String, dynamic>{};
    if (displayName != null) patch['display_name'] = displayName;
    if (phone != null) patch['phone'] = phone;
    if (receivers != null) {
      patch['receivers'] = receivers.map((r) => r.toJson()).toList();
    }
    final data = await _client
        .from('profiles')
        .update(patch)
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(data);
  }

  // ------------------------------------------------------------------
  // Admins
  // ------------------------------------------------------------------

  Future<bool> isAdmin(String userId) async {
    final data = await _client
        .from('admins')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    return data != null;
  }

  Future<List<AdminEntry>> listAdmins() async {
    final data = await _client
        .from('admins')
        .select('user_id, granted_by, created_at')
        .order('created_at');
    final entries = <AdminEntry>[];
    for (final row in data) {
      final userId = row['user_id'].toString();
      final profile = await getProfile(userId);
      entries.add(
        AdminEntry(
          userId: userId,
          email: profile?.email ?? '',
          displayName: profile?.displayName ?? '',
          createdAt: DateTime.tryParse(row['created_at'].toString()),
        ),
      );
    }
    return entries;
  }

  /// Mirrors addAdmin(): looks the user up by exact email, then grants.
  Future<void> addAdmin(String email, String grantedBy) async {
    final profile = await _client
        .from('profiles')
        .select('id')
        .eq('email', email.trim())
        .maybeSingle();
    if (profile == null) {
      throw const StoreException('user_not_found', 'No user with that email.');
    }
    await _client.from('admins').upsert(
      {
        'user_id': profile['id'].toString(),
        'granted_by': grantedBy,
      },
      onConflict: 'user_id',
    );
  }

  Future<void> removeAdmin(String userId) async {
    await _client.from('admins').delete().eq('user_id', userId);
  }

  // ------------------------------------------------------------------
  // Settings + rates
  // ------------------------------------------------------------------

  /// Mirrors getSettings(): the raw {key: value} map.
  Future<Map<String, dynamic>> getSettings() async {
    final data = await _client.from('settings').select('key, value');
    final out = <String, dynamic>{};
    for (final row in data) {
      out[row['key'].toString()] = row['value'];
    }
    return out;
  }

  /// Merged settings over the website defaults.
  Future<AppSettings> getAppSettings() async {
    return AppSettings.merge(await getSettings());
  }

  /// Mirrors updateSettings(): upserts one row per key.
  Future<void> updateSettings(Map<String, dynamic> patch) async {
    for (final entry in patch.entries) {
      await _client.from('settings').upsert(
        {'key': entry.key, 'value': entry.value},
        onConflict: 'key',
      );
    }
  }

  /// Mirrors setRates(): writes the rates setting AND appends a
  /// rate_history row (the history row drives the "last updated" label).
  Future<void> setRates(
    double thbToMmk,
    double mmkToThb,
    String changedBy,
  ) async {
    await updateSettings({
      'rates': {'thb_to_mmk': thbToMmk, 'mmk_to_thb': mmkToThb},
    });
    await _client.from('rate_history').insert({
      'thb_to_mmk': thbToMmk,
      'mmk_to_thb': mmkToThb,
      'changed_by': changedBy,
    });
  }

  Future<List<RateHistoryEntry>> getRateHistory([int limit = 14]) async {
    final data = await _client
        .from('rate_history')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return data.map(RateHistoryEntry.fromJson).toList();
  }

  // ------------------------------------------------------------------
  // Orders
  // ------------------------------------------------------------------

  /// Mirrors listOrders(): own orders for users, all for admins; optional
  /// status filter and order_no search; newest first, max 200.
  Future<List<Order>> listOrders({
    String? userId,
    bool isAdmin = false,
    String? status,
    String? search,
  }) async {
    var query = _client.from('orders').select();
    if (!isAdmin && userId != null) query = query.eq('user_id', userId);
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('order_no', '%${search.trim()}%');
    }
    final data = await query
        .order('created_at', ascending: false)
        .limit(200);
    return data.map(Order.fromJson).toList();
  }

  Future<Order?> getOrder(String id) async {
    final data =
        await _client.from('orders').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Order.fromJson(data);
  }

  /// Mirrors createOrder(): the rate is locked at creation; status
  /// starts 'pending'. Returns the created order.
  Future<Order> createOrder({
    required String userId,
    required String direction,
    required double sendAmount,
    required String sendCurrency,
    required double receiveAmount,
    required String receiveCurrency,
    required double rate,
    required double fee,
    required String receiveMethod,
    required String receiverName,
    required String receiverAccount,
    required String receiverPhone,
    required String slipPath,
    required String slipTxnId,
  }) async {
    final data = await _client
        .from('orders')
        .insert({
          'order_no': generateOrderNo(),
          'user_id': userId,
          'direction': direction,
          'send_amount': sendAmount,
          'send_currency': sendCurrency,
          'receive_amount': receiveAmount,
          'receive_currency': receiveCurrency,
          'rate': rate,
          'fee': fee,
          'receive_method': receiveMethod,
          'receiver_name': receiverName,
          'receiver_account': receiverAccount,
          'receiver_phone': receiverPhone,
          'slip_path': slipPath,
          'slip_txn_id': slipTxnId,
          'status': 'pending',
        })
        .select()
        .single();
    return Order.fromJson(data);
  }

  /// Mirrors updateOrderStatus(): admin-only via RLS. Sets completed_at
  /// when the order completes.
  Future<void> updateOrderStatus(
    String id,
    String status, {
    String? adminNote,
    String? proofPath,
  }) async {
    final patch = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (adminNote != null) patch['admin_note'] = adminNote;
    if (proofPath != null) patch['proof_path'] = proofPath;
    if (status == 'completed') {
      patch['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _client.from('orders').update(patch).eq('id', id);
  }

  /// Mirrors cancelOrder(): only the owner, only while pending (RLS
  /// enforces both as well).
  Future<void> cancelOrder(String id, String userId) async {
    await _client
        .from('orders')
        .update({'status': 'cancelled'})
        .eq('id', id)
        .eq('user_id', userId)
        .eq('status', 'pending');
  }

  // ------------------------------------------------------------------
  // Storage (private buckets: slips, proofs)
  // ------------------------------------------------------------------

  /// Mirrors uploadSlip()/uploadProof(): path is
  /// `<ownerId>/<timestamp>-<sanitized-name>`, upsert disabled.
  /// Proofs are uploaded into the ORDER OWNER's folder so the customer
  /// can view them under the storage policies.
  Future<String> uploadFile(
    String bucket,
    String ownerId,
    List<int> bytes,
    String fileName, {
    String contentType = 'image/jpeg',
  }) async {
    final path =
        '$ownerId/${DateTime.now().millisecondsSinceEpoch}-${sanitizeFileName(fileName)}';
    await _client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  /// Mirrors getFileUrl(): a 1-hour signed URL, or null when the file
  /// cannot be signed (e.g. it was deleted).
  Future<String?> getFileUrl(String bucket, String path) async {
    try {
      return await _client.storage.from(bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Users (admin)
  // ------------------------------------------------------------------

  Future<List<Profile>> listUsers() async {
    final data = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false)
        .limit(200);
    return data.map(Profile.fromJson).toList();
  }

  Future<void> setBlocked(String userId, bool blocked) async {
    await _client
        .from('profiles')
        .update({'is_blocked': blocked})
        .eq('id', userId);
  }

  /// Mirrors getOrderCountsByUser(): {userId: order count}.
  Future<Map<String, int>> getOrderCountsByUser() async {
    final data =
        await _client.from('orders').select('user_id').limit(1000);
    final counts = <String, int>{};
    for (final row in data) {
      final id = row['user_id'].toString();
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  // ------------------------------------------------------------------
  // Realtime
  // ------------------------------------------------------------------

  /// Mirrors subscribeOrders(): fires [onChange] on any orders change.
  /// The caller must call [unsubscribeOrders] when done.
  RealtimeChannel subscribeOrders(void Function() onChange) {
    final channel = _client.channel('orders-changes');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      callback: (_) => onChange(),
    );
    channel.subscribe();
    return channel;
  }

  Future<void> unsubscribeOrders(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
