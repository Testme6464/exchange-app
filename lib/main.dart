// Baht-Kyat Exchange — Flutter app mirroring the exchange website.
// Supabase backend (same project/tables/RLS/storage as the website).
// No demo mode, no Firebase, no ads in v1.

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'config.dart';
import 'screens/admin_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_order_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';
import 'store.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  // Google sign-in is wired only once the Web client ID is configured;
  // until then the Google button stays hidden and nothing here crashes.
  // The try/catch keeps a misconfigured client ID from crashing launch:
  // sign-in then fails gracefully at tap time with an error toast.
  if (AppConfig.googleSignInConfigured) {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId,
      );
    } catch (_) {
      // Google sign-in unavailable; email/password still works.
    }
  }
  runApp(const ExchangeApp());
}

class ExchangeApp extends StatefulWidget {
  const ExchangeApp({super.key});

  @override
  State<ExchangeApp> createState() => _ExchangeAppState();
}

class _ExchangeAppState extends State<ExchangeApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState(ExchangeStore());
    _state.boot();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        return MaterialApp(
          title: 'Baht-Kyat Exchange',
          theme: buildTheme(),
          home: _state.booting ? _buildSplash() : Shell(state: _state),
        );
      },
    );
  }

  Widget _buildSplash() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s('appName'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.blueDark,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

enum ShellPage { home, dashboard, newOrder, orders, profile, login, register, forgot }

class Shell extends StatefulWidget {
  const Shell({required this.state, super.key});

  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  ShellPage _page = ShellPage.home;
  final Map<ShellPage, int> _visits = {for (final p in ShellPage.values) p: 0};
  bool _blockedNoticeShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A restored session that belonged to a blocked account was signed
    // out during boot; surface the blocked message once.
    if (widget.state.blockedNotice && !_blockedNoticeShown) {
      _blockedNoticeShown = true;
      widget.state.consumeBlockedNotice();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSnack(context, s('blockedMsg'), isError: true);
      });
    }
  }

  void _goTo(ShellPage page) {
    setState(() {
      _visits[page] = _visits[page]! + 1;
      _page = page;
    });
  }

  void _onAuthSuccess() {
    if (widget.state.isAdmin) {
      _goTo(ShellPage.dashboard);
      _openAdmin();
    } else {
      _goTo(ShellPage.dashboard);
    }
  }

  void _openAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminScreen(state: widget.state),
      ),
    );
  }

  void _openOrderDetail(String orderId) {
    // Fresh wizard state for the next visit, like the website's
    // freshWizard() on each route entry.
    _visits[ShellPage.newOrder] = _visits[ShellPage.newOrder]! + 1;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(state: widget.state, orderId: orderId),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.state.signOut();
    _goTo(ShellPage.home);
  }

  Widget _buildPage() {
    final state = widget.state;
    final key = ValueKey('${_page.name}-${_visits[_page]}');
    // Auth-required pages redirect to the login page when logged out,
    // mirroring requireAuth() in js/app.js.
    const authPages = {
      ShellPage.dashboard,
      ShellPage.newOrder,
      ShellPage.orders,
      ShellPage.profile,
    };
    if (authPages.contains(_page) && !state.loggedIn) {
      return _NotLoggedIn(key: key, onLogin: () => _goTo(ShellPage.login));
    }
    switch (_page) {
      case ShellPage.home:
        return HomeScreen(
          key: key,
          state: state,
          onOrderNow: () => _goTo(
            state.loggedIn ? ShellPage.newOrder : ShellPage.login,
          ),
        );
      case ShellPage.dashboard:
        return DashboardScreen(
          key: key,
          state: state,
          onViewOrders: () => _goTo(ShellPage.orders),
          onNewOrder: () => _goTo(ShellPage.newOrder),
        );
      case ShellPage.newOrder:
        return NewOrderScreen(
          key: key,
          state: state,
          onOrderCreated: _openOrderDetail,
        );
      case ShellPage.orders:
        return OrdersScreen(key: key, state: state);
      case ShellPage.profile:
        return ProfileScreen(key: key, state: state);
      case ShellPage.login:
        return LoginScreen(
          key: key,
          state: state,
          onGoRegister: () => _goTo(ShellPage.register),
          onGoForgot: () => _goTo(ShellPage.forgot),
          onAuthSuccess: _onAuthSuccess,
        );
      case ShellPage.register:
        return RegisterScreen(
          key: key,
          state: state,
          onGoLogin: () => _goTo(ShellPage.login),
          onAuthSuccess: _onAuthSuccess,
        );
      case ShellPage.forgot:
        return ForgotScreen(
          key: key,
          state: state,
          onGoLogin: () => _goTo(ShellPage.login),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final loggedIn = state.loggedIn;
    final shopName = state.settings.shop.name;
    final title = shopName.isNotEmpty ? shopName : s('appName');

    final navPages = loggedIn
        ? const [
            ShellPage.home,
            ShellPage.dashboard,
            ShellPage.newOrder,
            ShellPage.orders,
            ShellPage.profile,
          ]
        : const [ShellPage.home, ShellPage.login, ShellPage.register];
    var navIndex = navPages.indexOf(_page);
    if (navIndex < 0) navIndex = _page == ShellPage.forgot ? 1 : 0;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _goTo(ShellPage.home),
          child: Text(title),
        ),
        actions: [
          if (state.isAdmin)
            TextButton(
              onPressed: _openAdmin,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(s('navAdmin')),
            ),
          if (loggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: s('logout'),
              onPressed: _logout,
            )
          else
            TextButton(
              onPressed: () => _goTo(ShellPage.login),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(s('loginBtn')),
            ),
        ],
      ),
      floatingActionButton: ContactFloat(settings: state.settings),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navIndex,
        onTap: (i) => _goTo(navPages[i]),
        items: navPages.map((p) => _navItem(p)).toList(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _buildPage(),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(ShellPage page) {
    switch (page) {
      case ShellPage.home:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home),
          label: s('navHome'),
        );
      case ShellPage.dashboard:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.dashboard_outlined),
          activeIcon: const Icon(Icons.dashboard),
          label: s('navDashboard'),
        );
      case ShellPage.newOrder:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.add_circle_outline),
          activeIcon: const Icon(Icons.add_circle),
          label: s('navNewOrder'),
        );
      case ShellPage.orders:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.receipt_long_outlined),
          activeIcon: const Icon(Icons.receipt_long),
          label: s('navOrders'),
        );
      case ShellPage.profile:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          activeIcon: const Icon(Icons.person),
          label: s('navProfile'),
        );
      case ShellPage.login:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.login_outlined),
          activeIcon: const Icon(Icons.login),
          label: s('loginBtn'),
        );
      case ShellPage.register:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.person_add_outlined),
          activeIcon: const Icon(Icons.person_add),
          label: s('registerBtn'),
        );
      case ShellPage.forgot:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.lock_outline),
          label: s('resetTitle'),
        );
    }
  }
}

class _NotLoggedIn extends StatelessWidget {
  const _NotLoggedIn({required this.onLogin, super.key});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s('notLoggedIn'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onLogin,
              child: Text(s('loginBtn')),
            ),
          ],
        ),
      ),
    );
  }
}
