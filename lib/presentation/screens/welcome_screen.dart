import 'package:flutter/material.dart';
import '../widgets/vault_app_icon.dart';

class WelcomeScreen extends StatefulWidget {
  final bool hasVault;
  final VoidCallback onContinue;

  const WelcomeScreen({
    super.key,
    required this.hasVault,
    required this.onContinue,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    ));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primary.withValues(alpha: 0.08),
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).scaffoldBackgroundColor,
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        VaultAppIcon(
                          size: 112,
                          primaryColor: scheme.primary,
                          secondaryColor: scheme.secondary,
                        ),
                        const SizedBox(height: 28),
                        if (widget.hasVault) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'VAULT DETECTED • READY TO UNLOCK',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontSize: 10.5,
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_outlined,
                                    size: 15, color: scheme.onSecondaryContainer),
                                const SizedBox(width: 6),
                                Text(
                                  'PRIVATE BY DESIGN',
                                  style: TextStyle(
                                    color: scheme.onSecondaryContainer,
                                    fontSize: 11,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          widget.hasVault
                              ? 'Welcome back to\nSecure Vault.'
                              : 'Your passwords,\none safe place.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 34,
                            height: 1.12,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.hasVault
                              ? 'Your local encrypted vault is locked and secure. Ready to unlock.'
                              : 'A calmer, safer way to keep your logins, notes, and important files together.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.55,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _WelcomeFeature(
                          icon: Icons.lock_outline,
                          title: 'Private by design',
                          description: 'Your vault stays encrypted on this device.',
                        ),
                        const SizedBox(height: 12),
                        const _WelcomeFeature(
                          icon: Icons.bolt_outlined,
                          title: 'Everything in one place',
                          description:
                              'Find and manage your saved logins in seconds.',
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const ValueKey('welcome_action_button'),
                            onPressed: widget.onContinue,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.hasVault
                                      ? Icons.lock_open_rounded
                                      : Icons.add_circle_outline_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  widget.hasVault
                                      ? 'Unlock your vault'
                                      : 'Create my vault',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 19),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off_outlined,
                                size: 15, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              'Your data stays on this device.',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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

class _WelcomeFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
