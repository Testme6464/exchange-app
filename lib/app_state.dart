// App-wide state: the signed-in user, their profile, admin flag and the
// merged shop settings. Mirrors the website's `state` object + boot()
// and afterAuthChanged() in js/app.js.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'store.dart';

class AppState extends ChangeNotifier {
  AppState(this.store);

  final ExchangeStore store;

  User? user;
  Profile? profile;
  bool isAdmin = false;
  AppSettings settings = const AppSettings();

  /// Timestamp of the newest rate_history row; drives the
  /// "last updated" label on the home rate card.
  DateTime? ratesUpdatedAt;

  bool booting = true;

  /// True when a restored session belonged to a blocked account and
  /// was signed out. The shell shows the blocked message once.
  bool blockedNotice = false;

  bool get loggedIn => user != null;

  String get displayName {
    final name = profile?.displayName ?? '';
    if (name.isNotEmpty) return name;
    return user?.email?.split('@').first ?? '';
  }

  /// Mirrors boot(): restores the session, ensures the profile, signs
  /// blocked accounts back out, checks admin, loads settings.
  Future<void> boot() async {
    final current = store.currentUser;
    if (current != null) {
      try {
        final p = await store.ensureProfile(current);
        if (p != null && p.isBlocked) {
          await store.signOut();
          blockedNotice = true;
        } else {
          user = current;
          profile = p;
          isAdmin = await store.isAdmin(current.id);
        }
      } catch (_) {
        // Network/DB hiccup: keep the session, profile stays null and
        // screens show their own error states with retry.
        user = current;
      }
    }
    await refreshSettings();
    booting = false;
    notifyListeners();
  }

  /// Mirrors loadSettings(): settings + newest rate_history timestamp.
  /// Failures keep the previous (or default) settings, like the website.
  Future<void> refreshSettings() async {
    try {
      settings = await store.getAppSettings();
    } catch (_) {
      // Keep previous settings.
    }
    try {
      final history = await store.getRateHistory(1);
      if (history.isNotEmpty) ratesUpdatedAt = history.first.createdAt;
    } catch (_) {
      // "Last updated" simply stays unknown.
    }
    notifyListeners();
  }

  /// Mirrors afterAuthChanged(): re-read user/profile/admin after any
  /// sign-in, sign-up or sign-out.
  Future<void> refreshAuth() async {
    final current = store.currentUser;
    user = current;
    if (current == null) {
      profile = null;
      isAdmin = false;
    } else {
      try {
        profile = await store.ensureProfile(current);
        isAdmin = await store.isAdmin(current.id);
      } catch (_) {
        profile = null;
        isAdmin = false;
      }
    }
    notifyListeners();
  }

  /// Updates the cached profile (e.g. after the user edits it) and
  /// notifies listeners, mirroring `state.profile = ...` in js/app.js.
  void setProfile(Profile profile) {
    this.profile = profile;
    notifyListeners();
  }

  Future<void> reloadProfile() async {
    final current = user;
    if (current == null) return;
    try {
      profile = await store.getProfile(current.id);
    } catch (_) {
      // Keep the previous profile.
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await store.signOut();
    user = null;
    profile = null;
    isAdmin = false;
    notifyListeners();
  }

  void consumeBlockedNotice() {
    blockedNotice = false;
  }
}
