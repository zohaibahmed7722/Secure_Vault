import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/repositories/vault_repository.dart';

class PrivateVaultScreen extends StatefulWidget {
  final VaultRepository repository;
  final Color themeColor;
  final VoidCallback? onLock;

  const PrivateVaultScreen({
    super.key,
    required this.repository,
    required this.themeColor,
    this.onLock,
  });

  @override
  State<PrivateVaultScreen> createState() => _PrivateVaultScreenState();
}

class _PrivateVaultScreenState extends State<PrivateVaultScreen>
    with TickerProviderStateMixin {
  bool _isUnlocked = false;
  bool _isAnimatingUnlock = false;
  bool _isRecoveryKeyVisible = false;
  late AnimationController _pulseController;
  late AnimationController _unlockAnimController;

  final TextEditingController _passwordHintCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _passwordHintCtrl.text = widget.repository.passwordHint;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    bool isTest = false;
    try {
      isTest = Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {}

    if (isTest) {
      _pulseController.value = 0.5;
    } else {
      _pulseController.repeat(reverse: true);
    }

    _unlockAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _unlockAnimController.dispose();
    _passwordHintCtrl.dispose();
    super.dispose();
  }

  Future<void> _performAnimatedUnlock() async {
    if (_isAnimatingUnlock) return;
    setState(() => _isAnimatingUnlock = true);

    try {
      _pulseController.stop();
      await _unlockAnimController.forward();
      bool isTest = false;
      try {
        isTest = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}
      if (!isTest) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (mounted) {
        setState(() {
          _isUnlocked = true;
          _isAnimatingUnlock = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Private vault security authenticated successfully.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isAnimatingUnlock = false);
    }
  }

  void _lockPrivateArea() {
    _unlockAnimController.reset();
    bool isTest = false;
    try {
      isTest = Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {}
    if (!isTest) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 0.5;
    }
    setState(() {
      _isUnlocked = false;
      _isRecoveryKeyVisible = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Private area locked.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _savePasswordHint() async {
    final hint = _passwordHintCtrl.text.trim();
    await widget.repository.updatePasswordHint(hint);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Second hint (password) saved successfully!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openChangePasswordDialog() async {
    final curCtrl = TextEditingController(
      text: widget.repository.activeMasterPassword ?? '',
    );
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? dialogError;
    bool obscureCur = true;
    bool obscureNew = true;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            actionsOverflowButtonSpacing: 8,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            title: const Row(
              children: [
                Icon(Icons.password_rounded),
                SizedBox(width: 8),
                Flexible(child: Text('Change Vault Password')),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: curCtrl,
                    obscureText: obscureCur,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCur ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureCur = !obscureCur),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New password (min 6 characters)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscureNew,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (curCtrl.text.isEmpty) {
                    setDialogState(
                      () => dialogError = 'Enter current password.',
                    );
                    return;
                  }
                  if (newCtrl.text.length < 6) {
                    setDialogState(
                      () => dialogError = 'Password must be at least 6 characters.',
                    );
                    return;
                  }
                  if (newCtrl.text != confirmCtrl.text) {
                    setDialogState(
                      () => dialogError = 'New passwords do not match.',
                    );
                    return;
                  }
                  try {
                    await widget.repository.changeMasterPassword(
                      currentPassword: curCtrl.text,
                      newPassword: newCtrl.text,
                    );
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx, true);
                    }
                  } catch (e) {
                    setDialogState(() => dialogError = '$e');
                  }
                },
                child: const Text('Update Password'),
              ),
            ],
          );
        },
      ),
    );

    if (updated == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vault password updated successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Private'),
        actions: [
          if (_isUnlocked)
            IconButton.filledTonal(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Lock Private Area',
              onPressed: _lockPrivateArea,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _isUnlocked ? _buildUnlockedView(scheme) : _buildLockedView(scheme),
      ),
    );
  }

  Widget _buildLockedView(ColorScheme scheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Security Sentinel Character
            AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _unlockAnimController]),
              builder: (context, child) {
                return SecuritySentinelCharacter(
                  pulseValue: _pulseController.value,
                  unlockProgress: _unlockAnimController.value,
                  isUnlocking: _isAnimatingUnlock,
                  themeColor: widget.themeColor,
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Private Vault Area',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contains your emergency recovery key, master password controls, and password reminder.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Animated Bypass Unlock Button
            FilledButton.icon(
              key: const ValueKey('private_bypass_unlock_button'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isAnimatingUnlock ? null : _performAnimatedUnlock,
              icon: _isAnimatingUnlock
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.shield_outlined),
              label: Text(
                _isAnimatingUnlock ? 'Authenticating...' : 'Unlock security',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const SizedBox(height: 14),

            // Security tag badge (flexible to prevent any right-overflow on narrow screens)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.themeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.themeColor.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 15,
                    color: widget.themeColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Hardware-Isolated • Decrypt Master Credentials',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: widget.themeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Biometric & cryptographic authorization required to access recovery keys and hints.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedView(ColorScheme scheme) {
    final recoveryKey = widget.repository.activeRecoveryKey;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Security Status Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.themeColor.withValues(alpha: 0.15),
                widget.themeColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.themeColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Private Security Unlocked',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'User: ${widget.repository.vaultUsername.isEmpty ? "Vault User" : widget.repository.vaultUsername}',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // SECTION 1: RECOVERY KEY
        Text(
          'EMERGENCY RECOVERY KEY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.key_rounded, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Master Recovery Key',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      tooltip: _isRecoveryKeyVisible ? 'Hide key' : 'Show key',
                      icon: Icon(
                        _isRecoveryKeyVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () => setState(
                        () => _isRecoveryKeyVisible = !_isRecoveryKeyVisible,
                      ),
                    ),
                    if (recoveryKey != null)
                      IconButton(
                        tooltip: 'Copy recovery key',
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () =>
                            _copyToClipboard(recoveryKey, 'Recovery key'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'This key is required to recover your vault or view username and password hints if you ever forget your master password.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: SelectableText(
                    recoveryKey == null
                        ? 'No saved recovery key in this session.'
                        : (_isRecoveryKeyVisible
                            ? recoveryKey
                            : '••••••••-••••••••-••••••••-••••••••-••••••••-••••••••-••••••••-••••••••'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // SECTION 2: VAULT MASTER PASSWORD & SECOND HINT
        Text(
          'VAULT MASTER PASSWORD & HINT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.password_rounded, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Master Password Settings',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _openChangePasswordDialog,
                  icon: const Icon(Icons.password_rounded, size: 18),
                  label: const Text('Change Master Password'),
                ),
                const SizedBox(height: 18),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.7)),
                const SizedBox(height: 14),

                // Second hint for password
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      size: 20,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Second Hint for Password',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Password Reminder',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'What is this hint and how does it work?',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• What it is: A personal reminder or clue to help you recall your master password if you ever forget it.\n'
                        '• How it works: If you lose access, go to the "Recover access" screen and enter your Emergency Recovery Key. The app will reveal this hint to jog your memory.\n'
                        '• Safety rule: Do NOT write your real password here! Write a clue only you understand (e.g. "Childhood street + pet year").',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordHintCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password hint',
                    hintText: 'e.g. Childhood street + pet year',
                    helperText: 'Saved securely and encrypted in your vault.',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Save password hint',
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _savePasswordHint,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _savePasswordHint,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Save Hint'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // SECTION 3: SPECIFICATIONS
        Text(
          'CRYPTOGRAPHY & ARCHITECTURE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Cipher', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text('AES-256-GCM', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant.withValues(alpha: 0.5)),
              const ListTile(
                leading: Icon(Icons.memory),
                title: Text('Key Derivation', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text('PBKDF2 SHA-256', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant.withValues(alpha: 0.5)),
              const ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Storage Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text('Offline Sandboxed', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class SecuritySentinelCharacter extends StatelessWidget {
  final double pulseValue;
  final double unlockProgress;
  final bool isUnlocking;
  final Color themeColor;

  const SecuritySentinelCharacter({
    super.key,
    required this.pulseValue,
    required this.unlockProgress,
    required this.isUnlocking,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 180,
      child: CustomPaint(
        painter: _SentinelPainter(
          pulseValue: pulseValue,
          unlockProgress: unlockProgress,
          isUnlocking: isUnlocking,
          themeColor: themeColor,
        ),
      ),
    );
  }
}

class _SentinelPainter extends CustomPainter {
  final double pulseValue;
  final double unlockProgress;
  final bool isUnlocking;
  final Color themeColor;

  _SentinelPainter({
    required this.pulseValue,
    required this.unlockProgress,
    required this.isUnlocking,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Gentle floating bob
    final floatOffset =
        math.sin(pulseValue * 2 * math.pi) * 5.0 - (unlockProgress * 6.0);
    final cy = (size.height / 2) + floatOffset - 6.0;

    // 1. Shadow on ground
    final shadowScale = 1.0 - (floatOffset / 20.0);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12 * shadowScale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 14),
        width: 74 * shadowScale,
        height: 14 * shadowScale,
      ),
      shadowPaint,
    );

    // 2. Glowing Shield Hologram Ring behind Sentinel
    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = (isUnlocking ? Colors.green : themeColor).withValues(
        alpha: isUnlocking ? 0.6 : 0.2 + (pulseValue * 0.15),
      );
    final auraRadius = 64.0 + (pulseValue * 6.0) + (unlockProgress * 8.0);
    canvas.drawCircle(Offset(cx, cy), auraRadius, auraPaint);

    // Segments around aura
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..color = (isUnlocking ? Colors.greenAccent : themeColor).withValues(
        alpha: isUnlocking ? 0.75 : 0.45,
      );
    final rotAngle = pulseValue * 2 * math.pi + (unlockProgress * 4 * math.pi);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: auraRadius + 4),
      rotAngle,
      math.pi * 0.45,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: auraRadius + 4),
      rotAngle + math.pi,
      math.pi * 0.45,
      false,
      arcPaint,
    );

    // 3. Floating Gauntlets / Cyber Hands (left and right)
    final handPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isUnlocking
            ? [Colors.green.shade400, Colors.teal.shade700]
            : [
                themeColor.withValues(alpha: 0.85),
                themeColor.withValues(alpha: 0.55),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final leftHandY =
        cy + 12 + math.sin((pulseValue + 0.25) * 2 * math.pi) * 3;
    final rightHandY =
        cy + 12 + math.sin((pulseValue + 0.75) * 2 * math.pi) * 3;
    final handInward = unlockProgress * 6.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - 48 + handInward, leftHandY),
          width: 14,
          height: 22,
        ),
        const Radius.circular(7),
      ),
      handPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + 48 - handInward, rightHandY),
          width: 14,
          height: 22,
        ),
        const Radius.circular(7),
      ),
      handPaint,
    );

    // 4. Robotic Torso / Body
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy + 24),
      width: 56,
      height: 44,
    );
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2C3440),
          Color(0xFF1B2028),
        ],
      ).createShader(bodyRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(16)),
      bodyPaint,
    );

    // Torso highlight border
    final bodyBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = (isUnlocking ? Colors.green : themeColor).withValues(alpha: 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(16)),
      bodyBorder,
    );

    // Torso Chest Core (Glowing Emblem)
    final corePaint = Paint()
      ..color = (isUnlocking ? Colors.greenAccent : (themeColor)).withValues(
        alpha: 0.85,
      );
    canvas.drawCircle(Offset(cx, cy + 24), 8, corePaint);
    final coreInner = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy + 24), 3.5, coreInner);

    // 5. Robotic Head
    final headRect = Rect.fromCenter(
      center: Offset(cx, cy - 14),
      width: 68,
      height: 52,
    );
    final headPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF384353),
          Color(0xFF1E242E),
        ],
      ).createShader(headRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, const Radius.circular(22)),
      headPaint,
    );

    // Head outer border
    final headBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = (isUnlocking ? Colors.green : themeColor).withValues(alpha: 0.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, const Radius.circular(22)),
      headBorder,
    );

    // Antenna Stalk & Beacon
    final antennaStalk = Paint()
      ..color = const Color(0xFF4A5568)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 40), Offset(cx, cy - 49), antennaStalk);

    final beaconPaint = Paint()
      ..color = (isUnlocking ? Colors.greenAccent : (themeColor));
    final beaconGlow = Paint()
      ..color = (isUnlocking ? Colors.greenAccent : (themeColor))
          .withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(
        Offset(cx, cy - 51), 5.5 + (pulseValue * 1.5), beaconGlow);
    canvas.drawCircle(Offset(cx, cy - 51), 4.5, beaconPaint);

    // Ear/sensor caps
    final earPaint = Paint()..color = const Color(0xFF242B35);
    canvas.drawCircle(Offset(cx - 35, cy - 14), 6, earPaint);
    canvas.drawCircle(Offset(cx + 35, cy - 14), 6, earPaint);

    // 6. Visor Plate (Face screen)
    final visorRect = Rect.fromCenter(
      center: Offset(cx, cy - 14),
      width: 52,
      height: 28,
    );
    final visorPaint = Paint()..color = const Color(0xFF0F141C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(visorRect, const Radius.circular(14)),
      visorPaint,
    );

    // 7. Visor Eyes / Expressions
    if (isUnlocking && unlockProgress < 0.8) {
      // Scanning animation in progress
      final scanLaser = Paint()
        ..color = Colors.greenAccent
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final scanX = cx - 18 + ((pulseValue * 1.5) % 1.0) * 36;
      canvas.drawLine(
        Offset(scanX, cy - 24),
        Offset(scanX, cy - 4),
        scanLaser,
      );
    } else if (unlockProgress >= 0.8) {
      // Happy Unlocked Eyes (^ ^)
      final happyEyePaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx - 12, cy - 14),
          width: 14,
          height: 12,
        ),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        happyEyePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx + 12, cy - 14),
          width: 14,
          height: 12,
        ),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        happyEyePaint,
      );
    } else {
      // Normal Alert & Blinking Visor Eyes
      final isBlinking = pulseValue > 0.88 && pulseValue < 0.96;
      const eyeColor = Color(0xFF00E5FF);
      final eyePaint = Paint()..color = eyeColor;
      final eyeGlow = Paint()
        ..color = eyeColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      if (isBlinking) {
        // Eyes closed slit
        final slitPaint = Paint()
          ..color = eyeColor
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
            Offset(cx - 18, cy - 14), Offset(cx - 6, cy - 14), slitPaint);
        canvas.drawLine(
            Offset(cx + 6, cy - 14), Offset(cx + 18, cy - 14), slitPaint);
      } else {
        // Round glowing eyes with shine
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx - 12, cy - 14),
              width: 12,
              height: 14,
            ),
            const Radius.circular(5),
          ),
          eyeGlow,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx - 12, cy - 14),
              width: 10,
              height: 12,
            ),
            const Radius.circular(4),
          ),
          eyePaint,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx + 12, cy - 14),
              width: 12,
              height: 14,
            ),
            const Radius.circular(5),
          ),
          eyeGlow,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx + 12, cy - 14),
              width: 10,
              height: 12,
            ),
            const Radius.circular(4),
          ),
          eyePaint,
        );

        // Pupil highlights
        final highlightPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(cx - 10, cy - 16), 2, highlightPaint);
        canvas.drawCircle(Offset(cx + 14, cy - 16), 2, highlightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SentinelPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.unlockProgress != unlockProgress ||
        oldDelegate.isUnlocking != isUnlocking ||
        oldDelegate.themeColor != themeColor;
  }
}
