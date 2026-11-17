import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/platform/clipboard_service.dart';
import 'core/storage/encrypted_vault_store.dart';
import 'domain/repositories/vault_repository.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/unlock_screen.dart';
import 'presentation/screens/recovery_screen.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/vault_dashboard.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/state/auto_lock_timer.dart';
import 'presentation/widgets/vault_app_icon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // App-private sandboxed directory on Android
  final appDir = await getApplicationDocumentsDirectory();
  final store = EncryptedVaultStore(storageDirectoryPath: appDir.path);
  final repository = VaultRepository(store: store);
  final clipboardService = SafeClipboardService();
  final preferences = await SharedPreferences.getInstance();
  final initialThemeMode = preferences.getString('theme_mode') == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;
  final initialThemeColor = AppTheme.parseHexColor(
        preferences.getString('theme_color') ?? '',
      ) ??
      AppTheme.brandColor;

  runApp(SecureVaultApp(
    repository: repository,
    store: store,
    clipboardService: clipboardService,
    initialThemeMode: initialThemeMode,
    initialThemeColor: initialThemeColor,
  ));
}

class SecureVaultApp extends StatefulWidget {
  final VaultRepository repository;
  final EncryptedVaultStore store;
  final SafeClipboardService clipboardService;
  final ThemeMode initialThemeMode;
  final Color initialThemeColor;

  const SecureVaultApp({
    super.key,
    required this.repository,
    required this.store,
    required this.clipboardService,
    this.initialThemeMode = ThemeMode.light,
    this.initialThemeColor = AppTheme.brandColor,
  });

  @override
  State<SecureVaultApp> createState() => _SecureVaultAppState();
}

class _SecureVaultAppState extends State<SecureVaultApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isInitialized = false;
  bool _showSplash = true;
  bool _showWelcome = true;
  Timer? _splashTimer;
  String? _startupError;
  late ThemeMode _themeMode;
  late Color _themeColor;
  late AutoLockManager _autoLockManager;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    _themeColor = widget.initialThemeColor;
    _isInitialized = widget.store.vaultExistsSync;
    _checkVaultExists();
    _autoLockManager = AutoLockManager(
      onLockTriggered: _lockVault,
      timeoutDuration: const Duration(minutes: 3),
    );
  }

  Future<void> _handleResetVault() async {
    await widget.repository.resetVault();
    if (mounted) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() {
        _isInitialized = false;
        _showWelcome = false;
        _showSplash = false;
      });
    }
  }

  Future<void> _checkVaultExists() async {
    try {
      final exists = await widget.store.vaultExists();
      if (!mounted) return;
      setState(() {
        _isInitialized = exists;
      });

      bool isTest = false;
      try {
        isTest = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}

      final duration = isTest
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 1100);

      _splashTimer?.cancel();
      _splashTimer = Timer(duration, () {
        if (mounted) {
          setState(() => _showSplash = false);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _startupError = 'Could not check the vault: $error';
        _showSplash = false;
      });
    }
  }

  void _lockVault() {
    if (widget.repository.isUnlocked) {
      setState(() {
        widget.repository.lock();
      });
    }
  }

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'theme_mode',
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
    if (mounted) setState(() => _themeMode = themeMode);
  }

  Future<void> _setThemeColor(Color color) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('theme_color', AppTheme.hexColor(color));
    if (mounted) setState(() => _themeColor = color);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _autoLockManager.dispose();
    widget.clipboardService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _autoLockManager.resetTimer(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Secure Vault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightWithColor(_themeColor),
        darkTheme: AppTheme.darkWithColor(_themeColor),
        themeMode: _themeMode,
        home: _startupError != null
            ? _StartupErrorScreen(
                error: _startupError!,
                onRetry: () {
                  setState(() {
                    _startupError = null;
                    _showSplash = true;
                  });
                  _checkVaultExists();
                },
              )
            : _showSplash
                ? (_isInitialized
                    ? const _BrandSplashScreen()
                    : const _StartupScreen())
                : (!_isInitialized && _showWelcome)
                    ? WelcomeScreen(
                        hasVault: _isInitialized,
                        onContinue: () =>
                            setState(() => _showWelcome = false),
                      )
                    : !_isInitialized
                        ? OnboardingScreen(
                            repository: widget.repository,
                            onVaultCreated: () =>
                                setState(() => _isInitialized = true),
                          )
                        : widget.repository.isUnlocked
                            ? VaultDashboard(
                                repository: widget.repository,
                                clipboardService: widget.clipboardService,
                                onLock: _lockVault,
                                onResetVault: _handleResetVault,
                                themeMode: _themeMode,
                                onThemeModeChanged: _setThemeMode,
                                themeColor: _themeColor,
                                onThemeColorChanged: _setThemeColor,
                              )
                            : Builder(
                                builder: (ctx) => UnlockScreen(
                                  repository: widget.repository,
                                  onUnlocked: () => setState(() {}),
                                  onResetVault: _handleResetVault,
                                  onNavigateToRecover: () {
                                    Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (_) => RecoveryScreen(
                                          repository: widget.repository,
                                          onRecovered: () {
                                            Navigator.pop(ctx);
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        key: const ValueKey('startup_splash_background'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: 0.38),
              colors.primary.withValues(alpha: 0.12),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VaultAppIcon(
                markKey: const ValueKey('startup_splash_icon'),
                size: 96,
                primaryColor: colors.primary,
                secondaryColor: colors.secondary,
              ),
              const SizedBox(height: 26),
              Text(
                'Secure Vault',
                key: const ValueKey('startup_splash_title'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your passwords, one safe place.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
              ),
              const SizedBox(height: 32),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.18),
                ),
                child: Icon(Icons.shield_outlined, size: 14, color: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandSplashScreen extends StatelessWidget {
  const _BrandSplashScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        key: const ValueKey('brand_splash_background'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: 0.40),
              colors.primary.withValues(alpha: 0.14),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VaultAppIcon(
                markKey: const ValueKey('brand_splash_mark'),
                size: 108,
                primaryColor: colors.primary,
                secondaryColor: colors.secondary,
              ),
              const SizedBox(height: 28),
              Text(
                'Secure Vault',
                key: const ValueKey('brand_splash_title'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 34,
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Private by design.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _StartupErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 12),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
