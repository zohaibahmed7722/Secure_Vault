import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/platform/clipboard_service.dart';
import '../../domain/models/credential_entry.dart';
import '../widgets/formatted_notes.dart';

class CredentialDetailScreen extends StatefulWidget {
  final CredentialEntry entry;
  final ValueChanged<BuildContext> onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(bool isFavorite) onFavoriteChanged;
  final SafeClipboardService clipboardService;

  const CredentialDetailScreen({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onFavoriteChanged,
    required this.clipboardService,
  });

  @override
  State<CredentialDetailScreen> createState() => _CredentialDetailScreenState();
}

class _CredentialDetailScreenState extends State<CredentialDetailScreen> {
  bool _isPasswordRevealed = false;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.entry.isFavorite;
  }

  void _copyToClipboard(String value, String label) {
    widget.clipboardService.copySensitive(value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied. It will clear from clipboard in 30 seconds.'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        actionsOverflowButtonSpacing: 8,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Flexible(child: Text('Delete credential?')),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${widget.entry.title}"? This item will be removed from your encrypted vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) widget.onDelete();
  }

  Future<void> _toggleFavorite() async {
    final updated = !_isFavorite;
    await widget.onFavoriteChanged(updated);
    if (mounted) {
      setState(() => _isFavorite = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated ? 'Added to favorites.' : 'Removed from favorites.'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openAttachment(CredentialAttachment attachment) async {
    final extension = attachment.name.split('.').last.toLowerCase();
    if (const {'png', 'jpg', 'jpeg', 'gif', 'webp'}.contains(extension)) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: InteractiveViewer(
              child: Image.memory(
                attachment.bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('This image could not be displayed.'),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    try {
      final savedUri = await FilePicker.saveFile(
        fileName: attachment.name,
        bytes: attachment.bytes,
        dialogTitle: 'Save a copy of ${attachment.name}',
      );
      if (savedUri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A copy was saved to your chosen location.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save attachment: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  IconData _categoryIcon(String category) => switch (category) {
        'Finance' => Icons.account_balance_outlined,
        'Work' => Icons.work_outline,
        'Personal' => Icons.person_outline,
        'Social' => Icons.people_outline,
        'Other' => Icons.folder_outlined,
        _ => Icons.key_outlined,
      };

  (String label, Color color, double percent) _passwordStrength(String pwd) {
    if (pwd.isEmpty) return ('Empty', Colors.grey, 0.0);
    var score = 0;
    if (pwd.length >= 8) score++;
    if (pwd.length >= 12) score++;
    if (pwd.length >= 16) score++;
    if (RegExp(r'[A-Z]').hasMatch(pwd) && RegExp(r'[a-z]').hasMatch(pwd)) score++;
    if (RegExp(r'[0-9]').hasMatch(pwd)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) score++;

    if (score <= 2) return ('Weak', Colors.redAccent, 0.25);
    if (score <= 4) return ('Moderate', Colors.orangeAccent, 0.55);
    if (score <= 5) return ('Strong', Colors.teal, 0.85);
    return ('Very Strong', Colors.green, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strength = _passwordStrength(entry.password);

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        actions: [
          IconButton(
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite ? Colors.amber : null,
              size: 26,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          // Styled Header Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.7),
                  scheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: entry.websiteIconUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            entry.websiteIconUrl,
                            width: 34,
                            height: 34,
                            errorBuilder: (_, __, ___) => Icon(
                              _categoryIcon(entry.category),
                              size: 28,
                              color: scheme.primary,
                            ),
                          ),
                        )
                      : Icon(
                          _categoryIcon(entry.category),
                          size: 28,
                          color: scheme.primary,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _categoryIcon(entry.category),
                                  size: 13,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  entry.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 12,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'AES-256 Encrypted',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Credentials Card (Username & Password)
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.035),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Username Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'USERNAME / EMAIL',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              entry.username.isEmpty
                                  ? 'No username'
                                  : entry.username,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: entry.username.isEmpty
                                    ? scheme.onSurfaceVariant
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (entry.username.isNotEmpty)
                        IconButton(
                          tooltip: 'Copy username',
                          icon: const Icon(Icons.content_copy_outlined, size: 20),
                          onPressed: () =>
                              _copyToClipboard(entry.username, 'Username'),
                        ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),

                // Password Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.key_rounded,
                              size: 20,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PASSWORD',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  _isPasswordRevealed
                                      ? entry.password
                                      : '••••••••••••••••',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    letterSpacing:
                                        _isPasswordRevealed ? 0.5 : 2.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: _isPasswordRevealed
                                ? 'Hide password'
                                : 'Show password',
                            icon: Icon(
                              _isPasswordRevealed
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _isPasswordRevealed = !_isPasswordRevealed,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy password',
                            icon: const Icon(Icons.content_copy_outlined, size: 20),
                            onPressed: () =>
                                _copyToClipboard(entry.password, 'Password'),
                          ),
                        ],
                      ),
                      if (entry.password.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 54, right: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.shield_rounded,
                                        size: 13,
                                        color: strength.$2,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        strength.$1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: strength.$2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${entry.password.length} characters',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: strength.$3,
                                  backgroundColor:
                                      scheme.outlineVariant.withValues(alpha: 0.5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    strength.$2,
                                  ),
                                  minHeight: 5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Website URL Card
          if (entry.websiteUrl.isNotEmpty) ...[
            _DetailCard(
              title: 'Website',
              value: entry.websiteUrl,
              leadingIcon: Icons.language_rounded,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.websiteIconUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          entry.websiteIconUrl,
                          width: 22,
                          height: 22,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.language, size: 20),
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Copy website',
                    icon: const Icon(Icons.content_copy_outlined, size: 20),
                    onPressed: () =>
                        _copyToClipboard(entry.websiteUrl, 'Website'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Notes Section Card
          if (entry.notes.isNotEmpty) ...[
            const _SectionHeading(
              title: 'Secure Notes',
              icon: Icons.note_alt_outlined,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FormattedNotes(notes: entry.notes),
            ),
            const SizedBox(height: 16),
          ],

          // Attachments Section Card
          if (entry.attachments.isNotEmpty) ...[
            _SectionHeading(
              title: 'Attachments (${entry.attachments.length})',
              icon: Icons.attach_file_rounded,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: entry.attachments.map((attachment) {
                  final isImg = const {'png', 'jpg', 'jpeg', 'gif', 'webp'}
                      .contains(attachment.name.split('.').last.toLowerCase());
                  return ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isImg
                            ? Icons.image_outlined
                            : Icons.insert_drive_file_outlined,
                        size: 20,
                        color: scheme.primary,
                      ),
                    ),
                    title: Text(
                      attachment.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${(attachment.bytes.length / 1024).toStringAsFixed(1)} KB · Encrypted',
                    ),
                    trailing: IconButton(
                      tooltip: 'View or save ${attachment.name}',
                      icon: const Icon(Icons.open_in_new, size: 20),
                      onPressed: () => _openAttachment(attachment),
                    ),
                    onTap: () => _openAttachment(attachment),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 12),
          // Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => widget.onEdit(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Edit Credential',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(110, 48),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? leadingIcon;
  final Widget? trailing;

  const _DetailCard({
    required this.title,
    required this.value,
    this.leadingIcon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                leadingIcon,
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _SectionHeading({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
