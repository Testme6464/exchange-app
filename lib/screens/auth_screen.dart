// Auth screens: login, register, forgot password. Mirrors
// renderLogin / renderRegister / renderForgot in js/app.js.
// The Google button appears only when GOOGLE_WEB_CLIENT_ID is set.

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../store.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.state,
    required this.onGoRegister,
    required this.onGoForgot,
    required this.onAuthSuccess,
    super.key,
  });

  final AppState state;
  final VoidCallback onGoRegister;
  final VoidCallback onGoForgot;
  final VoidCallback onAuthSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    setState(() => _error = '');
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = s('fillAll'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.store.signIn(email, password);
      await widget.state.refreshAuth();
      if (!mounted) return;
      showSnack(context, s('welcomeBack'));
      widget.onAuthSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(e);
        _busy = false;
      });
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _error = '';
      _busy = true;
    });
    try {
      await widget.state.store.signInWithGoogle();
      await widget.state.refreshAuth();
      if (!mounted) return;
      showSnack(context, s('welcomeBack'));
      widget.onAuthSuccess();
    } on StoreException catch (e) {
      // Dismissing the account picker is not an error.
      if (e.code == 'google_cancelled') {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(e);
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = s('errorGeneric');
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardTitle(s('loginTitle')),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: s('email')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: s('password')),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            FieldError(_error),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(s('loginBtn')),
            ),
            if (AppConfig.googleSignInConfigured) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _googleSignIn,
                icon: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.bluePale,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                label: Text(s('googleSignIn')),
              ),
            ],
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: widget.onGoForgot,
                child: Text(s('forgotPassword')),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s('noAccount'),
                      style: const TextStyle(fontSize: 14)),
                  TextButton(
                    onPressed: widget.onGoRegister,
                    child: Text(s('goRegister')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.state,
    required this.onGoLogin,
    required this.onAuthSuccess,
    super.key,
  });

  final AppState state;
  final VoidCallback onGoLogin;
  final VoidCallback onAuthSuccess;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    setState(() => _error = '');
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = s('fillAll'));
      return;
    }
    if (password.length < 6) {
      setState(() => _error = s('passwordShort'));
      return;
    }
    setState(() => _busy = true);
    try {
      final res =
          await widget.state.store.signUp(email, password, name);
      if (!mounted) return;
      if (res.needsConfirmation) {
        showSnack(context, s('confirmEmailMsg'));
        widget.onGoLogin();
        return;
      }
      await widget.state.refreshAuth();
      if (!mounted) return;
      showSnack(context, s('accountCreated'));
      widget.onAuthSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardTitle(s('registerTitle')),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: s('displayName'),
                hintText: s('displayNamePh'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: s('email')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: s('password'),
                hintText: s('passwordPh'),
              ),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            FieldError(_error),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(s('registerBtn')),
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s('haveAccount'),
                      style: const TextStyle(fontSize: 14)),
                  TextButton(
                    onPressed: widget.onGoLogin,
                    child: Text(s('goLogin')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({required this.state, required this.onGoLogin, super.key});

  final AppState state;
  final VoidCallback onGoLogin;

  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _email = TextEditingController();
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    setState(() => _error = '');
    if (email.isEmpty) {
      setState(() => _error = s('fillAll'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.store.resetPassword(email);
      if (!mounted) return;
      showSnack(context, s('resetSent'));
      widget.onGoLogin();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = s('errorGeneric');
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardTitle(s('resetTitle')),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: s('email')),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            FieldError(_error),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: Text(s('resetBtn')),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: widget.onGoLogin,
                child: Text(s('goLogin')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
