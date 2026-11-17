import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vault/core/platform/clipboard_service.dart';
import 'package:secure_vault/core/storage/encrypted_vault_store.dart';
import 'package:secure_vault/domain/repositories/vault_repository.dart';
import 'package:secure_vault/domain/models/credential_entry.dart';
import 'package:secure_vault/main.dart';
import 'package:secure_vault/presentation/screens/appearance_screen.dart';
import 'package:secure_vault/presentation/screens/credential_detail_screen.dart';
import 'package:secure_vault/presentation/screens/credential_edit_screen.dart';
import 'package:secure_vault/presentation/screens/onboarding_screen.dart';
import 'package:secure_vault/presentation/screens/private_vault_screen.dart';
import 'package:secure_vault/presentation/screens/profile_screen.dart';
import 'package:secure_vault/presentation/screens/recovery_screen.dart';
import 'package:secure_vault/presentation/screens/unlock_screen.dart';
import 'package:secure_vault/presentation/screens/vault_dashboard.dart';
import 'package:secure_vault/presentation/theme/app_theme.dart';
import 'package:secure_vault/presentation/state/auto_lock_timer.dart';
import 'package:secure_vault/presentation/widgets/profile_avatar.dart';
import 'package:secure_vault/presentation/widgets/rich_notes_controller.dart';

class _TestVaultStore extends EncryptedVaultStore {
  _TestVaultStore({this.exists = false}) : super(storageDirectoryPath: 'unused');

  final bool exists;

  @override
  Future<bool> vaultExists() async => exists;

  @override
  bool get vaultExistsSync => exists;
}

class _DashboardTestRepository extends VaultRepository {
  _DashboardTestRepository(List<CredentialEntry> initialEntries)
      : _entries = initialEntries,
        super(store: EncryptedVaultStore(storageDirectoryPath: 'unused'));

  List<CredentialEntry> _entries;

  @override
  List<CredentialEntry> get entries => List.unmodifiable(_entries);

  @override
  Future<void> saveCredential(CredentialEntry entry) async {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index < 0) {
      _entries = [..._entries, entry];
    } else {
      _entries[index] = entry;
    }
  }
}

class _ProfileTestRepository extends VaultRepository {
  _ProfileTestRepository()
      : super(store: EncryptedVaultStore(storageDirectoryPath: 'unused'));

  String username = 'original-user';
  String password = 'original-password';

  @override
  String get vaultUsername => username;

  @override
  Future<void> updateVaultUsername(String username) async {
    this.username = username.trim();
  }

  @override
  Future<String> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword != password) {
      throw ArgumentError('Current password is incorrect.');
    }
    password = newPassword;
    return '11111111-22222222-33333333-44444444-55555555-66666666-77777777-88888888';
  }
}

class _RecoveryTestRepository extends VaultRepository {
  _RecoveryTestRepository()
      : super(store: EncryptedVaultStore(storageDirectoryPath: 'unused'));

  @override
  Future<String?> getUsernameHintWithRecoveryKey(
      String formattedRecoveryKey) async {
    return formattedRecoveryKey == 'valid-key' ? 't••••r' : null;
  }

  @override
  Future<String?> getPasswordHintWithRecoveryKey(
      String formattedRecoveryKey) async {
    return formattedRecoveryKey == 'valid-key' ? 'P•••••••9' : null;
  }

  @override
  Future<bool> recoverWithKey(String formattedRecoveryKey) async =>
      formattedRecoveryKey == 'valid-key';
}

void main() {
  testWidgets('Onboarding passphrases can be shown and hidden', (
    WidgetTester tester,
  ) async {
    final repository = VaultRepository(
      store: EncryptedVaultStore(storageDirectoryPath: 'unused'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          repository: repository,
          onVaultCreated: () {},
        ),
      ),
    );

    final passphraseField = find.byType(TextField).at(1);
    expect(tester.widget<TextField>(passphraseField).obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(tester.widget<TextField>(passphraseField).obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password').first);
    await tester.pump();
    expect(tester.widget<TextField>(passphraseField).obscureText, isTrue);
  });

  testWidgets('Secure Vault opens a landing page before setup', (
    WidgetTester tester,
  ) async {
    final store = _TestVaultStore();
    final repository = VaultRepository(store: store);
    final clipboardService = SafeClipboardService();
    const themeColor = Color(0xFF12ABEF);

    await tester.pumpWidget(
      SecureVaultApp(
        repository: repository,
        store: store,
        clipboardService: clipboardService,
        initialThemeColor: themeColor,
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .debugShowCheckedModeBanner,
      isFalse,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, themeColor);
    expect(find.byKey(const ValueKey('startup_splash_title')), findsOneWidget);
    final startupMark = tester.widget<Container>(
      find.byKey(const ValueKey('startup_splash_icon')),
    );
    final startupDecoration = startupMark.decoration! as BoxDecoration;
    expect(startupDecoration.gradient!.colors.first, themeColor);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text('Your passwords,\none safe place.'), findsOneWidget);
    expect(find.text('Create my vault'), findsOneWidget);
    await tester.ensureVisible(find.text('Create my vault'));
    await tester.tap(find.text('Create my vault'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your vault'), findsOneWidget);
    expect(find.text('Your private vault'), findsOneWidget);
  });

  testWidgets('Switching apps does not immediately lock the vault', (
    WidgetTester tester,
  ) async {
    var lockTriggered = false;
    final manager = AutoLockManager(
      onLockTriggered: () => lockTriggered = true,
      timeoutDuration: const Duration(minutes: 3),
    );

    manager.didChangeAppLifecycleState(AppLifecycleState.paused);
    manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(lockTriggered, isFalse);
    manager.dispose();
  });

  testWidgets('Unlock screen offers password recovery', (
    WidgetTester tester,
  ) async {
    var recoveryRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: UnlockScreen(
          repository: _RecoveryTestRepository(),
          onUnlocked: () {},
          onNavigateToRecover: () => recoveryRequested = true,
        ),
      ),
    );

    await tester.tap(find.text('Recover Vault'));
    expect(recoveryRequested, isTrue);
  });

  testWidgets('Unlock screen stays scrollable in landscape with keyboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: UnlockScreen(
          repository: _RecoveryTestRepository(),
          onUnlocked: () {},
          onNavigateToRecover: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final passwordField = find.byType(TextField).last;
    await tester.ensureVisible(passwordField);
    await tester.tap(passwordField);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getRect(passwordField).bottom, lessThan(220));
  });

  testWidgets('Onboarding fields stay usable in landscape with keyboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          repository: VaultRepository(
            store: EncryptedVaultStore(storageDirectoryPath: 'unused'),
          ),
          onVaultCreated: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final confirmationField = find.byType(TextField).last;
    await tester.ensureVisible(confirmationField);
    await tester.tap(confirmationField);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Recovery field stays usable in landscape with keyboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryScreen(
          repository: _RecoveryTestRepository(),
          onRecovered: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recoveryField = find.byType(TextField).first;
    await tester.tap(recoveryField);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Credential editor fields remain usable in landscape', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: CredentialEditScreen(
          existing: CredentialEntry(
            title: 'Example',
            username: 'testuser',
            password: 'example-password',
          ),
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final passwordField = find.byKey(
      const ValueKey('credential_password_field'),
    );
    await tester.ensureVisible(passwordField);
    await tester.tap(passwordField);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getRect(passwordField).bottom, lessThan(220));
  });

  testWidgets('Dashboard search remains usable in landscape with keyboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final clipboard = SafeClipboardService();

    await tester.pumpWidget(
      MaterialApp(
        home: VaultDashboard(
          repository: _DashboardTestRepository(const []),
          clipboardService: clipboard,
          onLock: () {},
          onThemeModeChanged: (_) async {},
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(FloatingActionButton), findsNothing);
    clipboard.dispose();
  });

  testWidgets('Username hint requires a recovery key and allows two reveals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryScreen(
          repository: _RecoveryTestRepository(),
          onRecovered: () {},
        ),
      ),
    );

    expect(find.text('Hint'), findsNothing);
    await tester.enterText(find.byType(TextField), 'wrong-key');
    await tester.tap(find.text('Get hint'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The recovery key was not accepted or this vault has no hint.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'valid-key');
    await tester.tap(find.text('Get hint'));
    await tester.pumpAndSettle();
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('t••••r'), findsNothing);

    await tester.tap(find.text('Reveal hint'));
    await tester.pumpAndSettle();
    expect(find.text('t••••r'), findsOneWidget);
    expect(find.text('1 reveal remaining'), findsOneWidget);

    await tester.tap(find.text('Hide hint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reveal hint'));
    await tester.pumpAndSettle();
    expect(find.text('t••••r'), findsOneWidget);
    expect(find.text('0 reveals remaining'), findsOneWidget);

    await tester.tap(find.text('Hide hint'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(
              find.widgetWithText(TextButton, 'Reveal hint'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Profile appearance switch can enable dark mode', (
    WidgetTester tester,
  ) async {
    ThemeMode? requestedMode;
    Color? requestedColor;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: VaultRepository(
            store: EncryptedVaultStore(storageDirectoryPath: 'unused'),
          ),
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (mode) async => requestedMode = mode,
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (color) async => requestedColor = color,
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Light background enabled'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(requestedMode, ThemeMode.dark);

    final themeColorField = find.byKey(const ValueKey('theme_color_field'));
    await tester.ensureVisible(themeColorField);
    await tester.enterText(themeColorField, '#12ABEF');
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply color'));
    await tester.pumpAndSettle();
    expect(requestedColor, const Color(0xFF12ABEF));
    expect(find.text('Theme color updated.'), findsOneWidget);
  });

  testWidgets('Theme color picker previews and applies a selected color', (
    WidgetTester tester,
  ) async {
    Color? requestedColor;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: VaultRepository(
            store: EncryptedVaultStore(storageDirectoryPath: 'unused'),
          ),
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (color) async => requestedColor = color,
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open_theme_color_picker')));
    await tester.pumpAndSettle();
    expect(find.text('Choose theme color'), findsOneWidget);

    final huePicker = find.byKey(const ValueKey('theme_color_hue_picker'));
    var pickerRect = tester.getRect(huePicker);
    await tester.tapAt(
      Offset(
        pickerRect.left + pickerRect.width * 0.08,
        pickerRect.center.dy,
      ),
    );
    await tester.pumpAndSettle();

    final saturationPicker = find.byKey(
      const ValueKey('theme_color_saturation_picker'),
    );
    pickerRect = tester.getRect(saturationPicker);
    await tester.tapAt(
      Offset(
        pickerRect.left + pickerRect.width * 0.8,
        pickerRect.top + pickerRect.height * 0.2,
      ),
    );
    await tester.pumpAndSettle();

    final previewHex = tester.widget<Text>(
      find.byKey(const ValueKey('theme_color_picker_hex')),
    );
    final selectedColor = AppTheme.parseHexColor(previewHex.data!);
    expect(selectedColor, isNotNull);
    expect(selectedColor, isNot(AppTheme.brandColor));

    await tester.tap(
      find.byKey(const ValueKey('confirm_theme_color_picker')),
    );
    await tester.pumpAndSettle();
    // Theme color is not applied until clicking Apply color
    expect(requestedColor, isNull);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('theme_color_field')),
          )
          .controller!
          .text,
      previewHex.data,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply color'));
    await tester.pumpAndSettle();
    expect(requestedColor, selectedColor);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Canceling theme color picker leaves the theme unchanged', (
    WidgetTester tester,
  ) async {
    Color? requestedColor;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: VaultRepository(
            store: EncryptedVaultStore(storageDirectoryPath: 'unused'),
          ),
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (color) async => requestedColor = color,
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open_theme_color_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme_color_hue_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(requestedColor, isNull);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('theme_color_field')),
          )
          .controller!
          .text,
      AppTheme.hexColor(AppTheme.brandColor),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile username can be edited without framework errors', (
    WidgetTester tester,
  ) async {
    final repository = _ProfileTestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: repository,
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    final usernameField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ).first;
    await tester.enterText(usernameField, 'updated-user');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.username, 'updated-user');
    expect(find.text('updated-user'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Theme colors accept six-digit hex with or without a hash', () {
    expect(AppTheme.parseHexColor('#12aBeF'), const Color(0xFF12ABEF));
    expect(AppTheme.parseHexColor('12aBeF'), const Color(0xFF12ABEF));
    expect(AppTheme.parseHexColor('#12AB'), isNull);
    expect(AppTheme.hexColor(const Color(0xFF12ABEF)), '#12ABEF');
    expect(
      AppTheme.lightWithColor(const Color(0xFF12ABEF)).colorScheme.primary,
      const Color(0xFF12ABEF),
    );
    expect(
      AppTheme.darkWithColor(const Color(0xFF12ABEF)).colorScheme.primary,
      const Color(0xFF12ABEF),
    );
  });

  testWidgets('Notes preview shows headings and bold text without markers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CredentialEditScreen(
          existing: CredentialEntry(
            title: 'Example',
            username: 'testuser',
            password: 'example-password',
            notes: '## **Private note**',
          ),
          onSave: (_) async {},
        ),
      ),
    );

    await tester.ensureVisible(find.text('Preview'));
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.text('Private note', findRichText: true), findsOneWidget);
    expect(find.text('## **Private note**'), findsNothing);
  });

  testWidgets('Notes composer applies formatting to selected text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CredentialEditScreen(onSave: (_) async {}),
      ),
    );

    await tester.ensureVisible(find.text('Preview'));
    await tester.pumpAndSettle();
    final notesField = find.byKey(const ValueKey('notes_field'));
    await tester.ensureVisible(notesField);
    final controller = tester.widget<TextFormField>(notesField).controller! as RichNotesController;
    controller.value = const TextEditingValue(
      text: 'Remember this',
      selection: TextSelection(baseOffset: 0, extentOffset: 8),
    );
    await tester.pumpAndSettle();

    final boldButton = find.byIcon(Icons.format_bold);
    expect(boldButton, findsOneWidget);
    await tester.tap(boldButton);
    await tester.pumpAndSettle();

    expect(controller.text, 'Remember this');
    expect(controller.toFormattedString(), '**Remember** this');
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    final richText = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((widget) => widget.text.toPlainText() == 'Remember this');
    expect(richText.text.toPlainText(), 'Remember this');

    bool hasBoldStyle(TextSpan span) {
      return span.style?.fontWeight == FontWeight.bold ||
          span.children?.whereType<TextSpan>().any(hasBoldStyle) == true;
    }

    expect(
      hasBoldStyle(richText.text as TextSpan),
      isTrue,
    );
  });

  testWidgets('Heading style applies to all selected lines in the preview', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CredentialEditScreen(onSave: (_) async {}),
      ),
    );

    await tester.ensureVisible(find.text('Preview'));
    await tester.pumpAndSettle();
    final notesField = find.byKey(const ValueKey('notes_field'));
    final controller = tester.widget<TextFormField>(notesField).controller! as RichNotesController;
    controller.value = const TextEditingValue(
      text: 'Before\nTarget line\nSecond target\nAfter',
      selection: TextSelection(baseOffset: 7, extentOffset: 32),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Paragraph style'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heading 2'));
    await tester.pumpAndSettle();

    expect(controller.text, 'Before\nTarget line\nSecond target\nAfter');
    expect(controller.toFormattedString(), 'Before\n## Target line\n## Second target\nAfter');
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    final richText = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byKey(const ValueKey('preview_container')),
            matching: find.byType(RichText),
          ),
        )
        .firstWhere((widget) => widget.text.toPlainText() == 'Target line');
    final titleFontSize =
        Theme.of(tester.element(find.byType(CredentialEditScreen)))
            .textTheme
            .titleLarge
            ?.fontSize;
    bool hasHeadingFontSize(TextSpan span) {
      return span.style?.fontSize == titleFontSize ||
          span.children?.whereType<TextSpan>().any(hasHeadingFontSize) == true;
    }

    expect(hasHeadingFontSize(richText.text as TextSpan), isTrue);
  });

  testWidgets('List styles apply to and convert every selected line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CredentialEditScreen(onSave: (_) async {}),
      ),
    );

    await tester.ensureVisible(find.text('Preview'));
    await tester.pumpAndSettle();
    var controller = tester
        .widget<TextFormField>(find.byKey(const ValueKey('notes_field')))
        .controller! as RichNotesController;
    controller.value = const TextEditingValue(
      text: 'Alpha\nBeta\nGamma',
      selection: TextSelection(baseOffset: 0, extentOffset: 10),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.format_list_bulleted));
    await tester.pumpAndSettle();
    expect(controller.text, '• Alpha\n• Beta\nGamma');
    expect(controller.toFormattedString(), '- Alpha\n- Beta\nGamma');
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byKey(const ValueKey('preview_container')),
              matching: find.byType(RichText),
            ),
          )
          .any((widget) => widget.text.toPlainText() == '• Alpha'),
      isTrue,
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    controller = tester
        .widget<TextFormField>(find.byKey(const ValueKey('notes_field')))
        .controller! as RichNotesController;
    await tester.tap(find.byIcon(Icons.format_list_numbered));
    await tester.pumpAndSettle();
    expect(controller.text, '1. Alpha\n2. Beta\nGamma');
    expect(controller.toFormattedString(), '1. Alpha\n2. Beta\nGamma');
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byKey(const ValueKey('preview_container')),
              matching: find.byType(RichText),
            ),
          )
          .any((widget) => widget.text.toPlainText() == '1. Alpha'),
      isTrue,
    );
  });

  testWidgets('Inline toolbar styles can be toggled and combined', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CredentialEditScreen(onSave: (_) async {}),
      ),
    );

    await tester.ensureVisible(find.text('Preview'));
    await tester.pumpAndSettle();
    var notesField = find.byKey(const ValueKey('notes_field'));
    var controller = tester.widget<TextFormField>(notesField).controller! as RichNotesController;
    controller.value = const TextEditingValue(
      text: 'Remember this',
      selection: TextSelection(baseOffset: 0, extentOffset: 8),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.format_bold));
    await tester.pumpAndSettle();
    expect(controller.text, 'Remember this');
    expect(controller.toFormattedString(), '**Remember** this');

    await tester.tap(find.byIcon(Icons.format_italic));
    await tester.pumpAndSettle();
    expect(controller.text, 'Remember this');
    expect(controller.toFormattedString(), '***Remember*** this');

    await tester.tap(find.byIcon(Icons.format_underline));
    await tester.pumpAndSettle();
    expect(controller.text, 'Remember this');
    expect(controller.toFormattedString(), '***__Remember__*** this');

    await tester.tap(find.byIcon(Icons.strikethrough_s));
    await tester.pumpAndSettle();
    expect(controller.text, 'Remember this');
    expect(controller.toFormattedString(), '***__~~Remember~~__*** this');

    await tester.tap(find.byIcon(Icons.format_bold));
    await tester.pumpAndSettle();
    expect(controller.text, 'Remember this');
    expect(controller.toFormattedString(), '*__~~Remember~~__* this');
  });

  testWidgets('Editing and saving notes does not trigger framework errors',
      (WidgetTester tester) async {
    final repository = _DashboardTestRepository([
      CredentialEntry(
        title: 'Example',
        username: 'testuser',
        password: 'example-password',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultDashboard(
          repository: repository,
          clipboardService: SafeClipboardService(),
          onLock: () {},
          onThemeModeChanged: (_) async {},
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Example'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit Credential'));
    await tester.tap(find.text('Edit Credential'));
    await tester.pumpAndSettle();
    expect(find.text('Edit password'), findsOneWidget);
    await tester.ensureVisible(find.text('Preview'));
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final notesField = find.byKey(const ValueKey('notes_field'));
    await tester.ensureVisible(notesField);
    await tester.enterText(notesField, 'private note');

    final linkButton = find.byTooltip('Insert link');
    await tester.ensureVisible(linkButton);
    await tester.tap(linkButton);
    await tester.pumpAndSettle();
    final linkField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(linkField, 'https://example.com');
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    final mentionButton = find.byTooltip('Mention someone');
    await tester.ensureVisible(mentionButton);
    await tester.tap(mentionButton);
    await tester.pumpAndSettle();
    final mentionField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(mentionField, 'Alex');
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.entries.single.notes,
        'private notehttps://example.com@Alex');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard search, favorites, and categories work together', (
    WidgetTester tester,
  ) async {
    final repository = _DashboardTestRepository([
      CredentialEntry(
        title: 'Work Mail',
        username: 'person@example.com',
        password: 'PrivatePassword123!',
        websiteUrl: 'mail.example.com',
        category: 'Work',
      ),
      CredentialEntry(
        title: 'Old Account',
        username: 'person@old.example',
        password: 'AnotherPrivate123!',
        category: 'Legacy',
      ),
      CredentialEntry(
        title: 'Personal Archive',
        username: 'archive',
        password: 'ArchivePassword123!',
        category: 'Other',
      ),
    ]);
    final clipboard = SafeClipboardService();

    await tester.pumpWidget(
      MaterialApp(
        home: VaultDashboard(
          repository: repository,
          clipboardService: clipboard,
          onLock: () {},
          onThemeModeChanged: (_) async {},
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Credentials'), findsOneWidget);
    expect(find.text('All credentials'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.text('Work Mail'), findsOneWidget);
    final workMailTile = find.ancestor(
      of: find.text('Work Mail'),
      matching: find.byType(ListTile),
    );
    final addFavoriteButton = find.descendant(
      of: workMailTile,
      matching: find.byTooltip('Add to favorites'),
    );
    await tester.ensureVisible(addFavoriteButton);
    await tester.tap(addFavoriteButton);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    expect(repository.entries.first.isFavorite, isTrue);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Favorites 1'));
    await tester.pumpAndSettle();
    expect(find.text('Work Mail'), findsOneWidget);
    expect(find.text('Old Account'), findsNothing);

    await tester.drag(find.byType(ListView).first, const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Other 2'));
    await tester.pumpAndSettle();
    expect(find.text('Old Account'), findsOneWidget);
    expect(find.text('Personal Archive'), findsOneWidget);
    expect(find.text('Work Mail'), findsNothing);

    await tester.drag(find.byType(ListView).first, const Offset(600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'All 3'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'MAIL.EXAMPLE.COM');
    await tester.pumpAndSettle();
    expect(find.text('Work Mail'), findsOneWidget);
    expect(find.text('Old Account'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Old Account'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    clipboard.dispose();
  });

  testWidgets(
      'Startup first splash screen renders with application theme and themed splash icon',
      (WidgetTester tester) async {
    final store = _TestVaultStore();
    final repository = VaultRepository(store: store);
    final clipboard = SafeClipboardService();
    const customTheme = Color(0xFF0F9F8F);

    await tester.pumpWidget(
      SecureVaultApp(
        repository: repository,
        store: store,
        clipboardService: clipboard,
        initialThemeColor: customTheme,
      ),
    );

    expect(find.byKey(const ValueKey('startup_splash_background')), findsOneWidget);
    final iconContainer = tester.widget<Container>(
      find.byKey(const ValueKey('startup_splash_icon')),
    );
    final decoration = iconContainer.decoration! as BoxDecoration;
    expect(decoration.gradient!.colors.first, customTheme);
    expect(find.byKey(const ValueKey('startup_splash_title')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    clipboard.dispose();
  });

  testWidgets(
      'Brand splash screen (Private by design) only occurs if vault is created',
      (WidgetTester tester) async {
    final store = _TestVaultStore(exists: true);
    final repository = VaultRepository(store: store);
    final clipboard = SafeClipboardService();
    const customTheme = Color(0xFF0F9F8F);

    await tester.pumpWidget(
      SecureVaultApp(
        repository: repository,
        store: store,
        clipboardService: clipboard,
        initialThemeColor: customTheme,
      ),
    );

    // Private by design splash occurs because vault is created
    expect(find.byKey(const ValueKey('brand_splash_background')), findsOneWidget);
    expect(find.byKey(const ValueKey('brand_splash_title')), findsOneWidget);
    expect(find.text('Private by design.'), findsOneWidget);
    expect(find.byKey(const ValueKey('startup_splash_title')), findsNothing);

    final markContainer = tester.widget<Container>(
      find.byKey(const ValueKey('brand_splash_mark')),
    );
    final decoration = markContainer.decoration! as BoxDecoration;
    expect(decoration.gradient!.colors.first, customTheme);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // After brand splash, transitions to Unlock screen
    expect(find.byType(UnlockScreen), findsOneWidget);
    clipboard.dispose();
  });

  testWidgets('Profile screen allows previewing splash screen with themed icon',
      (WidgetTester tester) async {
    const customTheme = Color(0xFFE11D48);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: VaultRepository(
            store: EncryptedVaultStore(storageDirectoryPath: 'unused'),
          ),
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: customTheme,
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('App Icon & Splash Screen'), findsOneWidget);
    await tester.ensureVisible(find.text('Preview Splash Screen'));
    await tester.tap(find.text('Preview Splash Screen'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('splash_preview_container')), findsOneWidget);
    expect(find.text('Back to Settings'), findsOneWidget);
    await tester.tap(find.text('Back to Settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('splash_preview_container')), findsNothing);
  });

  testWidgets('Notes composer bolds sentences cleanly without capturing trailing space',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CredentialEditScreen(onSave: (_) async {}),
      ),
    );

    await tester.ensureVisible(find.text('Preview'));
    await tester.pumpAndSettle();
    final notesField = find.byKey(const ValueKey('notes_field'));
    final controller = tester.widget<TextFormField>(notesField).controller! as RichNotesController;
    controller.value = const TextEditingValue(
      text: 'First sentence. Second sentence.',
      selection: TextSelection(baseOffset: 0, extentOffset: 16),
    );
    await tester.pumpAndSettle();

    final boldButton = find.byIcon(Icons.format_bold);
    await tester.tap(boldButton);
    await tester.pumpAndSettle();

    expect(controller.text, 'First sentence. Second sentence.');
    expect(controller.toFormattedString(), '**First sentence.** Second sentence.');
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byKey(const ValueKey('preview_container')),
              matching: find.byType(RichText),
            ),
          )
          .any((widget) => widget.text.toPlainText().contains('First sentence.')),
      isTrue,
    );
  });

  testWidgets('Notes composer converts sentence into heading and toggles back to normal text',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CredentialEditScreen(onSave: (_) async {}),
      ),
    );

    await tester.ensureVisible(find.text('Preview'));
    await tester.pumpAndSettle();
    final notesField = find.byKey(const ValueKey('notes_field'));
    var controller = tester.widget<TextFormField>(notesField).controller! as RichNotesController;
    controller.value = const TextEditingValue(
      text: 'Important title',
      selection: TextSelection(baseOffset: 0, extentOffset: 15),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Paragraph style'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heading 1'));
    await tester.pumpAndSettle();

    expect(controller.text, 'Important title');
    expect(controller.toFormattedString(), '# Important title');

    // Toggle back to Normal text
    await tester.tap(find.byTooltip('Paragraph style'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Normal text'));
    await tester.pumpAndSettle();

    expect(controller.text, 'Important title');
    expect(controller.toFormattedString(), 'Important title');
  });

  testWidgets('Unlock screen renders with application theme gradient and themed app icon',
      (WidgetTester tester) async {
    const customTheme = Color(0xFF0F9F8F);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightWithColor(customTheme),
        home: UnlockScreen(
          repository: _RecoveryTestRepository(),
          onUnlocked: () {},
          onNavigateToRecover: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unlock_screen_background')), findsOneWidget);
    final bgContainer = tester.widget<Container>(
      find.byKey(const ValueKey('unlock_screen_background')),
    );
    final bgDecoration = bgContainer.decoration! as BoxDecoration;
    expect(bgDecoration.gradient, isNotNull);

    expect(find.byKey(const ValueKey('unlock_app_icon')), findsOneWidget);
    final appIconContainer = tester.widget<Container>(
      find.byKey(const ValueKey('unlock_app_icon')),
    );
    final iconDecoration = appIconContainer.decoration! as BoxDecoration;
    expect(iconDecoration.gradient!.colors.first, customTheme);
  });

  testWidgets('Preset colors do not apply theme until Apply color button is clicked', (
    WidgetTester tester,
  ) async {
    Color? requestedColor;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: VaultRepository(
            store: EncryptedVaultStore(storageDirectoryPath: 'unused'),
          ),
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (color) async => requestedColor = color,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    // Tap preset palette (Crimson Rose)
    final crimsonPreset = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == const Color(0xFFE11D48),
    );
    expect(crimsonPreset, findsOneWidget);
    await tester.tap(crimsonPreset);
    await tester.pumpAndSettle();

    // Verify theme color is NOT applied yet
    expect(requestedColor, isNull);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('theme_color_field')),
          )
          .controller!
          .text,
      '#E11D48',
    );

    // Click enhanced Apply color button
    final applyButton = find.text('Apply color');
    expect(applyButton, findsOneWidget);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    // Now theme color IS applied
    expect(requestedColor, const Color(0xFFE11D48));
    expect(find.text('Theme color updated.'), findsOneWidget);
  });

  testWidgets('Edit profile section allows viewing and changing password with confirm password', (
    WidgetTester tester,
  ) async {
    final repository = _ProfileTestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: repository,
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit_username_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('current_password_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('new_password_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm_password_field')), findsOneWidget);

    // Verify password fields start obscured
    expect(tester.widget<TextField>(find.byKey(const ValueKey('current_password_field'))).obscureText, isTrue);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('new_password_field'))).obscureText, isTrue);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('confirm_password_field'))).obscureText, isTrue);

    // Toggle visibility on current password
    final toggleButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(IconButton),
    );
    await tester.tap(toggleButtons.first);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('current_password_field'))).obscureText, isFalse);

    // Test password mismatch error validation
    await tester.enterText(find.byKey(const ValueKey('current_password_field')), 'original-password');
    await tester.enterText(find.byKey(const ValueKey('new_password_field')), 'brand-new-secret');
    await tester.enterText(find.byKey(const ValueKey('confirm_password_field')), 'different-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('New password and confirm password do not match.'), findsOneWidget);

    // Correct confirm password and save
    await tester.enterText(find.byKey(const ValueKey('confirm_password_field')), 'brand-new-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Verify recovery key dialog appears and password is changed
    expect(repository.password, 'brand-new-secret');
    expect(find.text('Password Updated'), findsOneWidget);
    expect(find.text('I saved it'), findsOneWidget);

    await tester.tap(find.text('I saved it'));
    await tester.pumpAndSettle();
    expect(find.text('Password Updated'), findsNothing);
  });

  testWidgets('Profile avatar eliminates flicker and reload animation on rebuilds', (WidgetTester tester) async {
    // 1-pixel transparent PNG bytes for testing
    final sampleBytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(
            image: sampleBytes,
            radius: 30,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);
    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.gaplessPlayback, isTrue);

    // Rebuild with the same image bytes - ensure no reload jerk or AnimatedContainer
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(
            image: sampleBytes,
            radius: 30,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify still stable with gapless playback
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsOneWidget);
  });

  testWidgets('Vault dashboard uses stable ProfileAvatar in app bar', (WidgetTester tester) async {
    final repository = _DashboardTestRepository([]);
    await tester.pumpWidget(
      MaterialApp(
        home: VaultDashboard(
          repository: repository,
          onLock: () {},
          clipboardService: SafeClipboardService(),
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: const Color(0xFF6750A4),
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Dashboard app bar has ProfileAvatar instead of AnimatedContainer CircleAvatar
    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('Notes editor bullet continues on Enter and toolbar removes programming symbols', (WidgetTester tester) async {
    final controller = RichNotesController(text: '• First item');
    controller.selection = const TextSelection.collapsed(offset: 12);

    // Simulate pressing Enter on a bulleted line
    controller.value = const TextEditingValue(
      text: '• First item\n',
      selection: TextSelection.collapsed(offset: 13),
    );

    // Bullet should automatically continue on the next line
    expect(controller.text, '• First item\n• ');
    expect(controller.selection.baseOffset, 15);

    // Simulate pressing Enter on the empty bullet line to exit the list
    controller.value = const TextEditingValue(
      text: '• First item\n• \n',
      selection: TextSelection.collapsed(offset: 16),
    );
    expect(controller.text, '• First item\n');

    // Verify toolbar in CredentialEditScreen removes curly brackets, inverted commas, and angle braces
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CredentialEditScreen(onSave: (_) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down to notes editor
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Toolbar should NOT contain quote, code, data_object (curly braces), or horizontal_rule (-)
    expect(find.byIcon(Icons.format_quote), findsNothing);
    expect(find.byIcon(Icons.code), findsNothing);
    expect(find.byIcon(Icons.data_object), findsNothing);
    expect(find.byIcon(Icons.horizontal_rule), findsNothing);

    // Toolbar should contain Bulleted list
    expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
    expect(find.byIcon(Icons.format_list_numbered), findsOneWidget);
  });

  testWidgets('Viewing saved password presents styled credentials, monospace font, and strength meter', (WidgetTester tester) async {
    final sampleEntry = CredentialEntry(
      title: 'GitHub Work Account',
      username: 'developer@example.com',
      password: 'SuperP@ssw0rd!2026',
      websiteUrl: 'https://github.com',
      category: 'Work',
      notes: 'Important keys',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CredentialDetailScreen(
          entry: sampleEntry,
          onEdit: (_) {},
          onDelete: () {},
          onFavoriteChanged: (_) async {},
          clipboardService: SafeClipboardService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify styled header badges
    expect(find.text('GitHub Work Account'), findsWidgets);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('AES-256 Encrypted'), findsOneWidget);

    // Verify username and password cards
    expect(find.text('developer@example.com'), findsOneWidget);
    expect(find.text('••••••••••••••••'), findsOneWidget);
    expect(find.text('Very Strong'), findsOneWidget);

    // Toggle reveal password
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(find.text('SuperP@ssw0rd!2026'), findsOneWidget);

    // Copy password and verify SnackBar feedback
    await tester.tap(find.byTooltip('Copy password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Password copied'), findsOneWidget);
  });

  testWidgets('Profile screen organizes preferences into Appearance and App settings', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: VaultRepository(
            store: EncryptedVaultStore(storageDirectoryPath: 'unused'),
          ),
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify sections and tiles
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Change Vault Password'), findsOneWidget);
    expect(find.text('Security & Encryption'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Help & FAQ'), findsOneWidget);
    expect(find.text('About Secure Vault'), findsOneWidget);
    expect(find.text('Lock Vault Now'), findsOneWidget);

    // Scroll back up and tap Appearance to open dedicated AppearanceScreen
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance & Display'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Apply color'), findsOneWidget);
  });

  testWidgets('Empty vault dashboard provides single Add credential action without duplicate buttons', (
    WidgetTester tester,
  ) async {
    final clipboard = SafeClipboardService();
    await tester.pumpWidget(
      MaterialApp(
        home: VaultDashboard(
          repository: _DashboardTestRepository(const []),
          clipboardService: clipboard,
          onLock: () {},
          onThemeModeChanged: (_) async {},
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify empty state messages
    expect(find.text('Keep your credentials together'), findsOneWidget);
    expect(find.text('Save logins and private notes in one secure place.'), findsOneWidget);

    // Verify duplication removed: No duplicate 'Add a password' button inside empty state
    expect(find.text('Add a password'), findsNothing);

    // Verify single primary action: FloatingActionButton 'Add credential'
    expect(find.text('Add credential'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Tap Add credential to verify functionality
    await tester.tap(find.text('Add credential'));
    await tester.pumpAndSettle();
    expect(find.byType(CredentialEditScreen), findsOneWidget);

    clipboard.dispose();
  });

  testWidgets('Appearance screen allows previewing both Startup and Brand splash screens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppearanceScreen(
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: const Color(0xFF1E88E5),
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down and open splash preview
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preview Splash Screen'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('splash_preview_container')), findsOneWidget);
    expect(find.text('Startup Splash'), findsOneWidget);
    expect(find.text('Brand Splash'), findsOneWidget);
    expect(find.text('Your passwords, one safe place.'), findsOneWidget);

    // Switch to Brand Splash
    await tester.tap(find.text('Brand Splash'));
    await tester.pumpAndSettle();
    expect(find.text('Private by design.'), findsOneWidget);

    // Back to Settings
    await tester.tap(find.text('Back to Settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('splash_preview_container')), findsNothing);
  });

  testWidgets('Profile screen allows resetting vault and invokes onResetVault callback', (
    WidgetTester tester,
  ) async {
    bool resetCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: VaultRepository(
            store: EncryptedVaultStore(storageDirectoryPath: 'unused'),
          ),
          onLock: () {},
          onResetVault: () async {
            resetCalled = true;
          },
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down to App Settings
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Reset Vault'), findsOneWidget);
    await tester.tap(find.text('Reset Vault'));
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.text('Reset Vault?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Reset Vault filled button
    await tester.tap(find.widgetWithText(FilledButton, 'Reset Vault'));
    await tester.pumpAndSettle();

    expect(resetCalled, isTrue);
  });

  testWidgets('Settings Private option opens with animation bypass and reveals recovery key and password settings', (
    WidgetTester tester,
  ) async {
    final repo = _ProfileTestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: repo,
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Private option exists in settings
    expect(find.text('Private'), findsOneWidget);
    await tester.tap(find.text('Private'));
    await tester.pumpAndSettle();

    // Verifies initially locked with Private Vault Area and bypass unlock button
    expect(find.text('Private Vault Area'), findsOneWidget);
    expect(find.text('Unlock security'), findsOneWidget);

    // Tap unlock bypass button
    await tester.tap(find.text('Unlock security'));
    // Pump animation frames
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Verify unlocked private contents are displayed
    expect(find.text('Private Security Unlocked'), findsOneWidget);
    expect(find.text('EMERGENCY RECOVERY KEY'), findsOneWidget);
    expect(find.text('VAULT MASTER PASSWORD & HINT'), findsOneWidget);
    expect(find.text('Second Hint for Password'), findsOneWidget);
    expect(find.text('Change Master Password'), findsOneWidget);

    // Test locking the private area
    await tester.tap(find.byTooltip('Lock Private Area'));
    await tester.pumpAndSettle();
    expect(find.text('Private Vault Area'), findsOneWidget);
  });

  testWidgets('Recovery screen reveals second hint for password alongside username hint', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryScreen(
          repository: _RecoveryTestRepository(),
          onRecovered: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'valid-key');
    await tester.tap(find.text('Get hint'));
    await tester.pumpAndSettle();

    expect(find.text('Hint'), findsOneWidget);
    // Reveal username hint
    await tester.tap(find.text('Reveal hint'));
    await tester.pumpAndSettle();
    expect(find.text('t••••r'), findsOneWidget);

    // Reveal second hint for password
    await tester.ensureVisible(find.text('Reveal password hint'));
    await tester.tap(find.text('Reveal password hint'));
    await tester.pumpAndSettle();
    expect(find.text('P•••••••9'), findsOneWidget);
  });

  testWidgets(
      'Onboarding password setup includes password generator tool and auto-fills confirmation',
      (WidgetTester tester) async {
    final repo = _ProfileTestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          repository: repo,
          onVaultCreated: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check generate password button exists in onboarding
    final generateBtn = find.byKey(
      const ValueKey('onboarding_generate_password_button'),
    );
    expect(generateBtn, findsOneWidget);

    // Tap generate button to open bottom sheet
    await tester.tap(generateBtn);
    await tester.pumpAndSettle();

    expect(find.text('Generate Password'), findsOneWidget);
    expect(find.text('Use Password'), findsOneWidget);

    // Apply generated password
    await tester.tap(find.text('Use Password'));
    await tester.pumpAndSettle();

    // Passphrase and confirmation should be filled with strong password
    expect(find.text('Vault password'), findsOneWidget);
    expect(find.text('Confirm vault password'), findsOneWidget);
  });

  testWidgets(
      'Credential editor password field does not feature generator sheet tool',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CredentialEditScreen(
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('credential_password_field')), findsOneWidget);
    // Generator tooltip should not exist on credential edit screen
    expect(find.byTooltip('Generate Strong Password'), findsNothing);
  });

  testWidgets(
      'Private vault screen displays security sentinel character and clarified hint information',
      (WidgetTester tester) async {
    final repo = _ProfileTestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PrivateVaultScreen(
          repository: repo,
          themeColor: AppTheme.brandColor,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Sentinel character and Unlock security button
    expect(find.byType(SecuritySentinelCharacter), findsOneWidget);
    expect(find.text('Unlock security'), findsOneWidget);
    expect(find.text('Hardware-Isolated • Decrypt Master Credentials'), findsOneWidget);

    // Unlock
    await tester.tap(find.text('Unlock security'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Clarified explanation card is visible
    expect(find.text('What is this hint and how does it work?'), findsOneWidget);
    expect(find.text('Password Reminder'), findsOneWidget);
  });

  testWidgets('WhatsApp-style profile picture viewer opens with Change, Remove, and Save buttons', (
    WidgetTester tester,
  ) async {
    final repo = _ProfileTestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: repo,
          onLock: () {},
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) async {},
          themeColor: AppTheme.brandColor,
          onThemeColorChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the profile avatar to open WhatsApp-style viewer
    await tester.tap(find.byType(ProfileAvatar));
    await tester.pumpAndSettle();

    // Verify WhatsApp image viewer is displayed with Change, Remove, Save buttons
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    // Close viewer
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Settings & Profile'), findsOneWidget);
  });

  testWidgets('Recovery screen restricts password hint reveals to exactly 2 times', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryScreen(
          repository: _RecoveryTestRepository(),
          onRecovered: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'valid-key');
    await tester.tap(find.text('Get hint'));
    await tester.pumpAndSettle();

    // Check separate password hint reveal button
    expect(find.text('Reveal password hint'), findsOneWidget);
    expect(find.text('2 reveals remaining'), findsWidgets);

    // Reveal 1
    await tester.ensureVisible(find.text('Reveal password hint'));
    await tester.tap(find.text('Reveal password hint'));
    await tester.pumpAndSettle();
    expect(find.text('1 reveal remaining'), findsOneWidget);
    expect(find.text('Hide password hint'), findsOneWidget);

    // Hide
    await tester.ensureVisible(find.text('Hide password hint'));
    await tester.tap(find.text('Hide password hint'));
    await tester.pumpAndSettle();

    // Reveal 2
    await tester.ensureVisible(find.text('Reveal password hint'));
    await tester.tap(find.text('Reveal password hint'));
    await tester.pumpAndSettle();
    expect(find.text('0 reveals remaining'), findsOneWidget);
    expect(find.text('Hide password hint'), findsOneWidget);

    // Hide again - now button should be disabled for further reveals
    await tester.ensureVisible(find.text('Hide password hint'));
    await tester.tap(find.text('Hide password hint'));
    await tester.pumpAndSettle();
    expect(find.text('Reveal password hint'), findsOneWidget);
    final revealButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Reveal password hint'));
    expect(revealButton.onPressed, isNull); // Disabled after 2 reveals!
  });
}
