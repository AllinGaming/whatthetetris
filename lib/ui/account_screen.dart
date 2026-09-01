import 'dart:async';

import 'package:flutter/material.dart';

import '../services/cloud_auth_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/live_services.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.live});

  final LiveServices live;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.live.auth.chosenPlayerName ?? '';
    unawaited(widget.live.analytics.screenViewed('account'));
    unawaited(widget.live.analytics.featureSelected('account'));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    final at = email.indexOf('@');
    if (at <= 0 ||
        at == email.length - 1 ||
        !email.substring(at).contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePlayerName(String? value) {
    final name = CloudAuthService.normalizePlayerName(value ?? '');
    if (name.isEmpty) return 'Choose a player name.';
    if (!CloudAuthService.isValidPlayerName(name)) {
      return 'Use 3–20 letters, numbers, spaces, _ or -.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  Future<void> _authenticate({required bool create}) async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    unawaited(
      widget.live.analytics.featureSelected(
        create ? 'account_create_email' : 'account_login_email',
      ),
    );
    final result = create
        ? await widget.live.auth.createEmailAccount(
            email: _emailController.text,
            password: _passwordController.text,
          )
        : await widget.live.auth.loginWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
    var nameSaved = false;
    if (result == EmailAuthResult.success) {
      nameSaved = await _applyPlayerName();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == EmailAuthResult.success) _passwordController.clear();
    _showMessage(
      result == EmailAuthResult.success && !nameSaved
          ? 'Logged in, but the player name could not be saved. Try again.'
          : _authMessage(result, create: create),
    );
  }

  Future<void> _savePlayerName() async {
    if (_busy) return;
    final error = _validatePlayerName(_nameController.text);
    if (error != null) {
      _showMessage(error);
      return;
    }
    setState(() => _busy = true);
    final success = await _applyPlayerName(syncIfUnchanged: true);
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(
      success
          ? 'Player name saved for future leaderboard entries.'
          : 'Could not save that player name. Please try again.',
    );
  }

  Future<bool> _applyPlayerName({bool syncIfUnchanged = false}) async {
    final desiredName = CloudAuthService.normalizePlayerName(
      _nameController.text,
    );
    final changed = widget.live.auth.chosenPlayerName != desiredName;

    if (changed) {
      unawaited(widget.live.analytics.featureSelected('account_name_changed'));
    }
    final saved =
        !changed || await widget.live.auth.updatePlayerName(desiredName);
    if (saved && (changed || syncIfUnchanged)) {
      // This reads only the four visible boards and writes only existing
      // entries whose public name actually changed.
      await widget.live.leaderboard.syncCurrentPlayerName(
        dailySeed: DailyChallengeService.seedForToday(),
      );
    }
    return saved;
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    final error = _validateEmail(_emailController.text);
    if (error != null) {
      _showMessage(error);
      return;
    }
    setState(() => _busy = true);
    unawaited(widget.live.analytics.featureSelected('account_reset_password'));
    final result = await widget.live.auth.sendPasswordReset(
      _emailController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(
      result == EmailAuthResult.success ||
              result == EmailAuthResult.invalidCredentials
          ? 'If an account exists for that email, a reset link was sent.'
          : _authMessage(result),
    );
  }

  String _authMessage(EmailAuthResult result, {bool create = false}) {
    return switch (result) {
      EmailAuthResult.success =>
        create
            ? 'Account created. Check your email for the verification link.'
            : 'Logged in successfully.',
      EmailAuthResult.invalidEmail => 'Enter a valid email address.',
      EmailAuthResult.invalidCredentials =>
        'The email or password is incorrect.',
      EmailAuthResult.weakPassword =>
        'Choose a stronger password with at least 6 characters.',
      EmailAuthResult.emailAlreadyInUse =>
        'An account already uses this email. Choose Log in instead.',
      EmailAuthResult.tooManyRequests =>
        'Too many attempts. Wait a moment and try again.',
      EmailAuthResult.networkError =>
        'Could not reach Firebase. Check your connection and try again.',
      EmailAuthResult.unavailable =>
        'Email login is unavailable. Enable Email/Password in Firebase Auth.',
      EmailAuthResult.failed => 'That did not complete. Please try again.',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _switchToAnonymous() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Your email account and leaderboard score stay available. This '
          'device will continue with a new anonymous player ID.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    unawaited(widget.live.analytics.featureSelected('account_logout'));
    final success = await widget.live.auth.useNewAnonymousAccount();
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(
      success
          ? 'Logged out. An anonymous player is active.'
          : 'Could not log out. Please try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.live.auth;
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: !auth.available
                        ? const _UnavailableAccount()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(
                                auth.isAnonymous
                                    ? Icons.person_outline
                                    : Icons.mark_email_read_outlined,
                                color: accent,
                                size: 48,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                auth.isAnonymous ? 'Log in' : 'Logged in',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                auth.playerName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Player ID ${auth.shortPlayerId}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                auth.isAnonymous
                                    ? 'Use email and password for a reusable '
                                          'leaderboard and 2 Player identity. '
                                          'Login remains optional.'
                                    : auth.email ?? 'Email account',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (auth.isAnonymous)
                                AutofillGroup(
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        TextFormField(
                                          controller: _nameController,
                                          enabled: !_busy,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.nickname,
                                          ],
                                          validator: _validatePlayerName,
                                          maxLength: 20,
                                          decoration: const InputDecoration(
                                            labelText: 'Player name',
                                            helperText:
                                                'Public on leaderboards; names are not unique.',
                                            prefixIcon: Icon(
                                              Icons.badge_outlined,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _emailController,
                                          enabled: !_busy,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.email,
                                            AutofillHints.username,
                                          ],
                                          autocorrect: false,
                                          validator: _validateEmail,
                                          decoration: const InputDecoration(
                                            labelText: 'Email',
                                            prefixIcon: Icon(
                                              Icons.email_outlined,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _passwordController,
                                          enabled: !_busy,
                                          obscureText: _obscurePassword,
                                          textInputAction: TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          validator: _validatePassword,
                                          onFieldSubmitted: (_) =>
                                              _authenticate(create: false),
                                          decoration: InputDecoration(
                                            labelText: 'Password',
                                            prefixIcon: const Icon(
                                              Icons.lock_outline,
                                            ),
                                            suffixIcon: IconButton(
                                              tooltip: _obscurePassword
                                                  ? 'Show password'
                                                  : 'Hide password',
                                              onPressed: _busy
                                                  ? null
                                                  : () => setState(
                                                      () => _obscurePassword =
                                                          !_obscurePassword,
                                                    ),
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                          .visibility_off_outlined,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        FilledButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _authenticate(
                                                  create: false,
                                                ),
                                          icon: const Icon(Icons.login),
                                          label: const Text('Log in'),
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () =>
                                                    _authenticate(create: true),
                                          icon: const Icon(
                                            Icons.person_add_outlined,
                                          ),
                                          label: const Text('Create account'),
                                        ),
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : _resetPassword,
                                          child: const Text('Forgot password?'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
                                TextFormField(
                                  controller: _nameController,
                                  enabled: !_busy,
                                  maxLength: 20,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _savePlayerName(),
                                  decoration: const InputDecoration(
                                    labelText: 'Player name',
                                    helperText:
                                        'Public on leaderboards; names are not unique.',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: _busy ? null : _savePlayerName,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save player name'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: _busy ? null : _switchToAnonymous,
                                  child: const Text('Log out'),
                                ),
                              ],
                              if (_busy) ...[
                                const SizedBox(height: 20),
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ],
                              const SizedBox(height: 20),
                              const Text(
                                'Your email is used only for Firebase login. '
                                'Your chosen player name is public on '
                                'leaderboards; your email address is never '
                                'shown there.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableAccount extends StatelessWidget {
  const _UnavailableAccount();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Icon(Icons.cloud_off_outlined, size: 48, color: Colors.white38),
      SizedBox(height: 14),
      Text(
        'Login is unavailable',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 8),
      Text(
        'Classic and Daily still work offline. Firebase accounts are '
        'currently enabled for the web build.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54),
      ),
    ],
  );
}
