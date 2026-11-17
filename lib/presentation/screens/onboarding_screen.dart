import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/vault_repository.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/vault_app_icon.dart';
import 'password_generator_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  final VaultRepository repository;
  final VoidCallback onVaultCreated;

  const OnboardingScreen(
      {super.key, required this.repository, required this.onVaultCreated});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _usernameCtrl = TextEditingController();
  final _passphraseCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _generatedRecoveryKey = '';
  bool _confirmedOfflineSave = false;
  bool _obscurePassphrase = true;
  bool _obscureConfirmation = true;
  bool _isLoading = false;
  String? _error;

  int get _passwordStrength {
    final password = _passphraseCtrl.text;
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score;
  }

  Future<void> _createVault() async {
    if (_usernameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a username for your vault.');
      return;
    }
    if (_passphraseCtrl.text.length < 12) {
      setState(() => _error = 'Use at least 12 characters.');
      return;
    }
    if (_passphraseCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final username = _usernameCtrl.text.trim();
      final recKey = await widget.repository.initializeVault(
        username: username,
        masterPassphrase: _passphraseCtrl.text,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_vault_username', username);
      } catch (_) {}
      _usernameCtrl.clear();
      _passphraseCtrl.clear();
      _confirmCtrl.clear();
      setState(() {
        _generatedRecoveryKey = recKey;
        _step = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openGenerator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PasswordGeneratorSheet(
        onPasswordSelected: (pwd) {
          setState(() {
            _passphraseCtrl.text = pwd;
            _confirmCtrl.text = pwd;
            _error = null;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passphraseCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('onboarding_screen_background'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primary.withValues(alpha: 0.10),
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor,
          ],
          stops: const [0, 0.40, 1],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Set up your vault'),
          backgroundColor: Colors.transparent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _step == 0 ? _buildPassphraseStep() : _buildRecoveryKeyStep(),
        ),
      ),
    );
  }

  Widget _buildPassphraseStep() {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: VaultAppIcon(
              size: 68,
              primaryColor: colors.primary,
              secondaryColor: colors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your private vault',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a vault password to protect your saved passwords and notes. Keep it safe: your recovery key is the only way back in if you forget it. Your data stays on this device.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _usernameCtrl,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            scrollPadding: const EdgeInsets.all(24),
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'For example, testuser',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passphraseCtrl,
            textInputAction: TextInputAction.next,
            obscureText: _obscurePassphrase,
            scrollPadding: const EdgeInsets.all(24),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Vault password',
              helperText: 'Use at least 12 characters.',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('onboarding_generate_password_button'),
                    tooltip: 'Generate Strong Password',
                    icon: const Icon(Icons.auto_awesome),
                    onPressed: _openGenerator,
                  ),
                  IconButton(
                    tooltip: _obscurePassphrase ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscurePassphrase ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassphrase = !_obscurePassphrase,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openGenerator,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text(
                'Generate strong password',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_passphraseCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PasswordStrengthIndicator(strength: _passwordStrength),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _confirmCtrl,
            textInputAction: TextInputAction.done,
            obscureText: _obscureConfirmation,
            scrollPadding: const EdgeInsets.all(24),
            decoration: InputDecoration(
              labelText: 'Confirm vault password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscureConfirmation
                    ? 'Show confirmation'
                    : 'Hide confirmation',
                icon: Icon(
                  _obscureConfirmation
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedPressable(
            onTap: _isLoading ? null : _createVault,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _createVault,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create vault'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryKeyStep() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: VaultAppIcon(
              size: 68,
              primaryColor: Theme.of(context).colorScheme.primary,
              secondaryColor: Theme.of(context).colorScheme.secondary,
              icon: Icons.key_outlined,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recovery key',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'If you forget your master passphrase, this key is the only way to get back into your vault. Save it somewhere private and safe.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: SelectableText(
              _generatedRecoveryKey,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            title: const Text('I have saved this recovery key somewhere safe.'),
            value: _confirmedOfflineSave,
            onChanged: (val) =>
                setState(() => _confirmedOfflineSave = val ?? false),
          ),
          const SizedBox(height: 16),
          AnimatedPressable(
            onTap: _confirmedOfflineSave ? widget.onVaultCreated : null,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _confirmedOfflineSave ? widget.onVaultCreated : null,
                child: const Text('Continue to vault'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  final int strength;

  const _PasswordStrengthIndicator({required this.strength});

  @override
  Widget build(BuildContext context) {
    final color = strength < 2
        ? Theme.of(context).colorScheme.error
        : strength < 4
            ? Colors.orange.shade800
            : Colors.green.shade700;
    final label = strength < 2
        ? 'Weak'
        : strength < 4
            ? 'Fair'
            : strength < 5
                ? 'Good'
                : 'Strong';
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: strength / 5,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
