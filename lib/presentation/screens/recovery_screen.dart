import 'package:flutter/material.dart';
import '../../domain/repositories/vault_repository.dart';

class RecoveryScreen extends StatefulWidget {
  final VaultRepository repository;
  final VoidCallback onRecovered;

  const RecoveryScreen(
      {super.key, required this.repository, required this.onRecovered});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _keyCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingHint = false;
  bool _isHintVisible = false;
  bool _isPasswordHintVisible = false;
  int _hintReveals = 0;
  int _passwordHintReveals = 0;
  String? _usernameHint;
  String? _passwordHint;
  String? _error;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRecover() async {
    if (_isLoading) return;
    if (_keyCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your recovery key.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await widget.repository.recoverWithKey(_keyCtrl.text);
      if (!mounted) return;
      if (success) {
        widget.onRecovered();
      } else {
        setState(() {
          _isLoading = false;
          _error = 'That recovery key did not work. Check it and try again.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not restore access: $error';
        });
      }
    }
  }

  Future<void> _checkUsernameHint() async {
    if (_isLoading || _isCheckingHint) return;
    if (_keyCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your recovery key to check the hint.');
      return;
    }

    setState(() {
      _isCheckingHint = true;
      _error = null;
      _isHintVisible = false;
      _isPasswordHintVisible = false;
    });

    try {
      final hint = await widget.repository.getUsernameHintWithRecoveryKey(
        _keyCtrl.text,
      );
      if (!mounted) return;
      if (hint == null) {
        setState(() {
          _isCheckingHint = false;
          _error =
              'The recovery key was not accepted or this vault has no hint.';
        });
        return;
      }
      final passHint = await widget.repository.getPasswordHintWithRecoveryKey(
        _keyCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _isCheckingHint = false;
        _usernameHint = hint;
        _passwordHint = passHint ?? 'Vault master password';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isCheckingHint = false;
          _error = 'Could not check the recovery key: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recover Vault')),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the recovery key you saved when you created your vault. You can use it to reveal your vault hints up to twice, or restore access to your vault.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyCtrl,
              maxLines: 2,
              scrollPadding: const EdgeInsets.all(24),
              decoration: InputDecoration(
                hintText: 'Paste your recovery key',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  _isCheckingHint || _isLoading ? null : _checkUsernameHint,
              icon: _isCheckingHint
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.help_outline_rounded),
              label: Text(
                _isCheckingHint ? 'Checking key...' : 'Get hint',
              ),
            ),
            if (_usernameHint != null) ...[
              const SizedBox(height: 16),
              // PRIMARY HINT CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Hint',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Vault Hints',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isHintVisible) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        _usernameHint!,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${2 - _hintReveals} ${2 - _hintReveals == 1 ? 'reveal' : 'reveals'} remaining',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isHintVisible
                          ? () => setState(() => _isHintVisible = false)
                          : _hintReveals >= 2
                              ? null
                              : () => setState(() {
                                    _isHintVisible = true;
                                    _hintReveals++;
                                  }),
                      child: Text(
                        _isHintVisible ? 'Hide hint' : 'Reveal hint',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // SEPARATE SECOND HINT: PASSWORD HINT (restricted to 2 reveals)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.password_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Password Hint',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Password Reminder',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personal reminder to recall your vault master password.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_isPasswordHintVisible) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: SelectableText(
                          _passwordHint ?? 'Vault master password',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${2 - _passwordHintReveals} ${2 - _passwordHintReveals == 1 ? 'reveal' : 'reveals'} remaining',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isPasswordHintVisible
                          ? () => setState(() => _isPasswordHintVisible = false)
                          : _passwordHintReveals >= 2
                              ? null
                              : () => setState(() {
                                    _isPasswordHintVisible = true;
                                    _passwordHintReveals++;
                                  }),
                      child: Text(
                        _isPasswordHintVisible
                            ? 'Hide password hint'
                            : 'Reveal password hint',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading || _isCheckingHint ? null : _handleRecover,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Recover Vault'),
            ),
          ],
        ),
      ),
    );
  }
}
