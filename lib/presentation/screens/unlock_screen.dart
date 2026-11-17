import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/vault_repository.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/vault_app_icon.dart';

class UnlockScreen extends StatefulWidget {
  final VaultRepository repository;
  final VoidCallback onUnlocked;
  final VoidCallback onNavigateToRecover;
  final VoidCallback? onResetVault;

  const UnlockScreen({
    super.key,
    required this.repository,
    required this.onUnlocked,
    required this.onNavigateToRecover,
    this.onResetVault,
  });

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _usernameController = TextEditingController();
  final _passphraseController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassphrase = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final cachedUser = widget.repository.lastVaultUsername;
    if (cachedUser.isNotEmpty) {
      _usernameController.text = cachedUser;
    }
    _loadSavedUsername();
  }

  Future<void> _loadSavedUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('saved_vault_username');
      if (mounted && _usernameController.text.isEmpty && savedUser != null && savedUser.isNotEmpty) {
        setState(() {
          _usernameController.text = savedUser;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleUnlock() async {
    if (_isLoading) return;
    final enteredUsername = _usernameController.text.trim();
    final enteredPassphrase = _passphraseController.text;

    if (enteredUsername.isEmpty || enteredPassphrase.isEmpty) {
      setState(() => _errorMessage = 'Enter your username and vault password.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    late bool success;
    try {
      success = await widget.repository.unlockWithCredentials(
        username: enteredUsername,
        passphrase: enteredPassphrase,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not open your vault: $error';
        });
      }
      return;
    }

    if (mounted) {
      if (success) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_vault_username', enteredUsername);
        } catch (_) {}
        _passphraseController.clear();
        widget.onUnlocked();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'That username or password did not work. Try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('unlock_screen_background'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primary.withValues(alpha: 0.12),
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor,
          ],
          stops: const [0, 0.40, 1],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Unlock your vault'),
          backgroundColor: Colors.transparent,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: VaultAppIcon(
                        markKey: const ValueKey('unlock_app_icon'),
                        size: 80,
                        primaryColor: colors.primary,
                        secondaryColor: colors.secondary,
                      ),
                    ),
                  ),
                  const Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock your private space to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    scrollPadding: const EdgeInsets.all(24),
                    decoration: const InputDecoration(
                      labelText: 'Username',
                    ),
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passphraseController,
                    textInputAction: TextInputAction.done,
                    obscureText: _obscurePassphrase,
                    enableSuggestions: false,
                    autocorrect: false,
                    scrollPadding: const EdgeInsets.all(24),
                    decoration: InputDecoration(
                      labelText: 'Vault password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassphrase
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _obscurePassphrase
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassphrase = !_obscurePassphrase,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _handleUnlock(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AnimatedPressable(
                    onTap: _isLoading ? null : _handleUnlock,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleUnlock,
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onPrimary,
                                ),
                              )
                            : const Text('Unlock'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.onNavigateToRecover,
                    child: const Text('Recover Vault'),
                  ),
                  if (widget.onResetVault != null) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Reset Vault?'),
                              ],
                            ),
                            content: const Text(
                              'This will permanently delete the current vault and all saved data on this device so you can set up a new vault and user.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Reset Vault'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await widget.repository.resetVault();
                          widget.onResetVault!();
                        }
                      },
                      child: Text(
                        'Reset vault & start fresh',
                        style: TextStyle(color: colors.error.withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
