import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/vault_repository.dart';
import '../widgets/profile_avatar.dart';
import 'appearance_screen.dart';
import 'private_vault_screen.dart';
import 'whatsapp_profile_viewer.dart';
import '../widgets/animated_pressable.dart';

class ProfileScreen extends StatefulWidget {
  final VaultRepository repository;
  final VoidCallback onLock;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode themeMode) onThemeModeChanged;
  final Color themeColor;
  final Future<void> Function(Color color) onThemeColorChanged;
  final VoidCallback? onResetVault;

  const ProfileScreen({
    super.key,
    required this.repository,
    required this.onLock,
    this.onResetVault,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.themeColor,
    required this.onThemeColorChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSaving = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openWhatsAppImageViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WhatsAppProfileViewer(
          initialImage: widget.repository.profileImage,
          username: widget.repository.vaultUsername,
          repository: widget.repository,
          onPhotoChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final result = await showDialog<_EditProfileResult>(
      context: context,
      builder: (context) => _EditProfileDialog(
        currentUsername: widget.repository.vaultUsername,
        initialCurrentPassword: widget.repository.activeMasterPassword ?? '',
      ),
    );
    if (result == null || !mounted) return;

    try {
      var updatedAny = false;
      if (result.username != widget.repository.vaultUsername) {
        await widget.repository.updateVaultUsername(result.username);
        try {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('saved_vault_username', result.username);
          }).catchError((_) {});
        } catch (_) {}
        updatedAny = true;
      }

      if (result.newPassword != null && result.currentPassword != null) {
        final newRecoveryKey = await widget.repository.changeMasterPassword(
          currentPassword: result.currentPassword!,
          newPassword: result.newPassword!,
        );
        updatedAny = true;
        if (mounted) {
          _showNewRecoveryKeyDialog(newRecoveryKey);
          _showMessage('Vault password updated successfully.');
        }
      } else if (updatedAny) {
        if (mounted) _showMessage('Profile updated successfully.');
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showMessage('Could not update profile: $error');
    }
  }

  void _showNewRecoveryKeyDialog(String recoveryKey) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        actionsOverflowButtonSpacing: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 10),
            Flexible(child: Text('Password Updated')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your vault master password was updated successfully. Because your master key changed, your new emergency recovery key is:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  recoveryKey,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Keep this key somewhere secure. It is the only way to recover your vault if you forget your new password.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I saved it'),
          ),
        ],
      ),
    );
  }

  Future<void> _choosePhoto() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: 'Choose a profile photo',
      );
      if (files.isEmpty || !mounted) return;
      final image = await files.first.readAsBytes();
      if (image.length > 5 * 1024 * 1024) {
        _showMessage('Choose an image smaller than 5 MB.');
        return;
      }
      await _savePhoto(image);
    } catch (error) {
      if (mounted) _showMessage('Could not add the photo: $error');
    }
  }

  Future<void> _savePhoto(Uint8List? image) async {
    setState(() => _isSaving = true);
    try {
      await widget.repository.saveProfileImage(image);
      if (mounted) {
        setState(() {});
        _showMessage(
          image != null
              ? 'Profile photo saved successfully.'
              : 'Profile photo removed.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage('Could not save profile photo: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmRemovePhoto() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text('This photo will be removed from your vault.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove == true) await _savePhoto(null);
  }

  Future<void> _confirmResetVault() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Reset Vault?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all saved credentials, attachments, and settings from this device. You will be able to create a brand new vault user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Vault'),
          ),
        ],
      ),
    );

    if (shouldReset == true && mounted) {
      if (widget.onResetVault != null) {
        widget.onResetVault!();
      } else {
        await widget.repository.resetVault();
        if (mounted) {
          Navigator.pop(context); // close profile screen
          widget.onLock();
        }
      }
    }
  }

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _openAppearance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppearanceScreen(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          themeColor: widget.themeColor,
          onThemeColorChanged: widget.onThemeColorChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.repository.profileImage;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Profile Avatar & Identity Card
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomRight,
              children: [
                AnimatedPressable(
                  onTap: _isSaving ? null : _openWhatsAppImageViewer,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          scheme.secondary,
                          scheme.primary.withValues(alpha: 0.4),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      child: ProfileAvatar(
                        radius: 54,
                        image: image,
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.primary,
                        placeholderIcon: Icons.person_outline,
                        iconSize: 54,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: AnimatedPressable(
                    onTap: _isSaving ? null : _openWhatsAppImageViewer,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.primary,
                            scheme.secondary,
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              widget.repository.vaultUsername.isEmpty
                  ? 'Vault Owner'
                  : widget.repository.vaultUsername,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 13,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'ENCRYPTED VAULT OWNER',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _editProfile,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit profile'),
              ),
              if (image != null)
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _confirmRemovePhoto,
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: const Text('Remove photo'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _choosePhoto,
                  icon: const Icon(Icons.photo_library_outlined, size: 17),
                  label: const Text('Add photo'),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // PREFERENCES SECTION
          Text(
            'PREFERENCES',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
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
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.palette_outlined, size: 20, color: scheme.primary),
              ),
              title: const Text(
                'Appearance',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Theme mode (${widget.themeMode == ThemeMode.dark ? "Dark" : "Light"}), accent colors & splash preview',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _openAppearance,
            ),
          ),
          const SizedBox(height: 20),

          // ACCOUNT & SECURITY SECTION
          Text(
            'ACCOUNT & SECURITY',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
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
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('profile_private_settings_tile'),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.shield_moon_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Private',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Recovery key, vault password & hint',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrivateVaultScreen(
                          repository: widget.repository,
                          themeColor: widget.themeColor,
                          onLock: widget.onLock,
                        ),
                      ),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Change Vault Password',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Update master password & re-encrypt recovery key',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _editProfile,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: Colors.green,
                    ),
                  ),
                  title: const Text(
                    'Security & Encryption',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'AES-256-GCM local storage · auto-locks after 3 min',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showInfo(
                    'Security & Encryption',
                    '• Local Encrypted Storage: All passwords, usernames, URLs, notes, and photos are encrypted on-device with AES-256-GCM.\n• Zero Knowledge: Your master key is never stored in plain text or transmitted off this device.\n• Auto-lock: The vault locks automatically after 3 minutes of inactivity or when switching apps.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // APP SETTINGS SECTION
          Text(
            'APP SETTINGS',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
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
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Help & FAQ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Vault recovery, organization, and search tips',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showInfo(
                    'Help & FAQ',
                    '1. How do I recover my vault if I forget my password?\nUse the emergency recovery key generated during setup or password changes on the unlock screen.\n\n2. How do I filter credentials?\nUse the category pills (All, Favorites, Finance, Work, Personal) or the search bar on the dashboard.\n\n3. Are my attachments safe?\nYes! All attachments and rich notes are encrypted with your vault key.',
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  title: const Text(
                    'About Secure Vault',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Version 1.0.0 · Offline & private'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showInfo(
                    'About Secure Vault',
                    'Secure Vault Version 1.0.0\n\nA private, offline-first password and credential manager built with Flutter and advanced agentic security standards.',
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                  ),
                  title: const Text(
                    'Lock Vault Now',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                    ),
                  ),
                  subtitle: const Text('Require password to access entries'),
                  onTap: widget.onLock,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      size: 20,
                      color: Colors.red,
                    ),
                  ),
                  title: const Text(
                    'Reset Vault',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: const Text('Delete all data and create a new vault user'),
                  onTap: _confirmResetVault,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EditProfileResult {
  final String username;
  final String? currentPassword;
  final String? newPassword;

  _EditProfileResult({
    required this.username,
    this.currentPassword,
    this.newPassword,
  });
}

class _EditProfileDialog extends StatefulWidget {
  final String currentUsername;
  final String initialCurrentPassword;

  const _EditProfileDialog({
    required this.currentUsername,
    this.initialCurrentPassword = '',
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _currentPasswordController;
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentUsername);
    _currentPasswordController =
        TextEditingController(text: widget.initialCurrentPassword);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final username = _usernameController.text.trim();
    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Username cannot be empty.');
      return;
    }

    final isChangingPassword =
        newPass.isNotEmpty || confirmPass.isNotEmpty;

    if (isChangingPassword) {
      if (currentPass.isEmpty) {
        setState(() => _errorMessage = 'Enter your current password to change it.');
        return;
      }
      if (newPass.isEmpty) {
        setState(() => _errorMessage = 'Enter your new password.');
        return;
      }
      if (newPass.length < 6) {
        setState(() => _errorMessage = 'New password must be at least 6 characters.');
        return;
      }
      if (newPass != confirmPass) {
        setState(() => _errorMessage = 'New password and confirm password do not match.');
        return;
      }
    }

    Navigator.pop(
      context,
      _EditProfileResult(
        username: username,
        currentPassword: isChangingPassword ? currentPass : null,
        newPassword: isChangingPassword ? newPass : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      actionsOverflowButtonSpacing: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      title: const Row(
        children: [
          Icon(Icons.manage_accounts_rounded, size: 24),
          SizedBox(width: 10),
          Flexible(child: Text('Edit Profile')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('edit_username_field'),
              controller: _usernameController,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'CHANGE VAULT PASSWORD',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Leave password fields blank if you only want to update username.',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('current_password_field'),
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Current password',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscureCurrent ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('new_password_field'),
              controller: _newPasswordController,
              obscureText: _obscureNew,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'New password',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  tooltip: _obscureNew ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureNew ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('confirm_password_field'),
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: const Icon(Icons.lock_clock_outlined),
                suffixIcon: IconButton(
                  tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _handleSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
