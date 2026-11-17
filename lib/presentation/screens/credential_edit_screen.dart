import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../domain/models/credential_entry.dart';
import '../widgets/formatted_notes.dart';
import '../widgets/rich_notes_controller.dart';

class CredentialEditScreen extends StatefulWidget {
  final CredentialEntry? existing;
  final Future<void> Function(CredentialEntry entry) onSave;

  const CredentialEditScreen({super.key, this.existing, required this.onSave});

  @override
  State<CredentialEditScreen> createState() => _CredentialEditScreenState();
}

class _CredentialEditScreenState extends State<CredentialEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _urlCtrl;
  late RichNotesController _notesCtrl;
  late String _category;
  final Map<String, String> _customFields = {};
  late List<CredentialAttachment> _attachments;
  final FocusNode _notesFocus = FocusNode();
  bool _obscurePassword = true;
  bool _isSaving = false;
  bool _isPickingAttachments = false;
  bool _showNotesPreview = false;
  bool _showNotesFormatting = true;
  bool _isUrlValid = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _userCtrl = TextEditingController(text: e?.username ?? '');
    _passCtrl = TextEditingController(text: e?.password ?? '');
    _urlCtrl = TextEditingController(text: e?.websiteUrl ?? '');
    _notesCtrl = RichNotesController.fromFormattedString(e?.notes ?? '');
    _category = e?.category ?? 'General';
    _attachments = List.from(e?.attachments ?? const []);
    if (e != null) _customFields.addAll(e.customFields);
    _isUrlValid = _isValidUrl(_urlCtrl.text);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.contains('://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  String _extractHost(String value) {
    final normalized = _normalizeUrl(value);
    final uri = Uri.tryParse(normalized);
    final host = uri?.host.trim() ?? '';
    return host;
  }

  bool _isValidUrl(String value) {
    final host = _extractHost(value);
    return host.isNotEmpty && host.contains('.');
  }

  String _faviconUrl(String value) {
    final host = _extractHost(value);
    if (host.isEmpty || !host.contains('.')) return '';
    return 'https://www.google.com/s2/favicons?sz=128&domain=$host';
  }



  Future<void> _insertNoteLink() async {
    final selection = _notesCtrl.selection;
    final text = _notesCtrl.text;
    final start =
        selection.isValid ? selection.start.clamp(0, text.length) : text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, text.length)
        : text.length;
    final selectedText = text.substring(start, end);
    var enteredUrl = '';
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert link'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Web address',
            hintText: 'https://example.com',
          ),
          onChanged: (value) => enteredUrl = value,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredUrl.trim()),
            child: const Text('Insert'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;

    final normalizedUrl = url.trim().startsWith('http://') || url.trim().startsWith('https://')
        ? url.trim()
        : 'https://${url.trim()}';
    final label = selectedText.isNotEmpty ? selectedText : normalizedUrl;
    _notesCtrl.insertLink(normalizedUrl, label: label);
  }

  Future<void> _insertMention() async {
    var enteredName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a mention'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter a name',
          ),
          onChanged: (value) => enteredName = value,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredName.trim()),
            child: const Text('Insert'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    _insertAtSelection('@${name.trim()} ');
  }

  void _insertAtSelection(String insertion) {
    final text = _notesCtrl.text;
    final selection = _notesCtrl.selection;
    final start =
        selection.isValid ? selection.start.clamp(0, text.length) : text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, text.length)
        : text.length;
    final updated = text.replaceRange(start, end, insertion);
    _notesCtrl.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
  }

  void _toggleNotesPreview() {
    setState(() => _showNotesPreview = !_showNotesPreview);
    if (!_showNotesPreview) {
      _notesFocus.requestFocus();
    }
  }

  Future<void> _chooseNoteEmoji() async {
    const emojis = ['😀', '🙂', '😉', '😍', '👍', '❤️', '🔒', '✅'];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 12,
            runSpacing: 12,
            children: emojis
                .map(
                  (emoji) => IconButton(
                    tooltip: 'Insert $emoji',
                    onPressed: () => Navigator.pop(context, emoji),
                    icon: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (emoji != null && mounted) _insertAtSelection(emoji);
  }

  Widget _noteToolbarButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }

  Widget _buildNoteFormattingToolbar() {
    final divider = VerticalDivider(
      width: 8,
      thickness: 1,
      indent: 8,
      endIndent: 8,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _noteToolbarButton(
            tooltip: 'Bold',
            icon: Icons.format_bold,
            onPressed: () => _notesCtrl.toggleBold(),
          ),
          _noteToolbarButton(
            tooltip: 'Italic',
            icon: Icons.format_italic,
            onPressed: () => _notesCtrl.toggleItalic(),
          ),
          _noteToolbarButton(
            tooltip: 'Underline',
            icon: Icons.format_underline,
            onPressed: () => _notesCtrl.toggleUnderline(),
          ),
          _noteToolbarButton(
            tooltip: 'Strikethrough',
            icon: Icons.strikethrough_s,
            onPressed: () => _notesCtrl.toggleStrikethrough(),
          ),
          divider,
          PopupMenuButton<int>(
            tooltip: 'Paragraph style',
            icon: const Icon(Icons.text_fields, size: 20),
            onSelected: (level) => _notesCtrl.setHeadingLevel(level),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 0, child: Text('Normal text')),
              PopupMenuItem(value: 1, child: Text('Heading 1')),
              PopupMenuItem(value: 2, child: Text('Heading 2')),
              PopupMenuItem(value: 3, child: Text('Heading 3')),
            ],
          ),
          divider,
          _noteToolbarButton(
            tooltip: 'Insert link',
            icon: Icons.link,
            onPressed: _insertNoteLink,
          ),
          _noteToolbarButton(
            tooltip: 'Bulleted list',
            icon: Icons.format_list_bulleted,
            onPressed: () => _notesCtrl.toggleBulletList(),
          ),
          _noteToolbarButton(
            tooltip: 'Numbered list',
            icon: Icons.format_list_numbered,
            onPressed: () => _notesCtrl.toggleNumberedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteComposerActions() {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        _noteToolbarButton(
          tooltip: 'Attach files',
          icon: Icons.add_circle_outline,
          onPressed: _isPickingAttachments ? null : _addAttachments,
        ),
        _noteToolbarButton(
          tooltip: _showNotesFormatting ? 'Hide formatting' : 'Show formatting',
          icon: Icons.text_format,
          onPressed: () =>
              setState(() => _showNotesFormatting = !_showNotesFormatting),
        ),
        const Spacer(),
        _noteToolbarButton(
          tooltip: 'Insert emoji',
          icon: Icons.emoji_emotions_outlined,
          onPressed: _chooseNoteEmoji,
        ),
        _noteToolbarButton(
          tooltip: 'Mention someone',
          icon: Icons.alternate_email,
          onPressed: _insertMention,
        ),
        PopupMenuButton<String>(
          tooltip: 'More note actions',
          icon: Icon(Icons.more_horiz, color: color),
          onSelected: (action) {
            if (action == 'clear') {
              final cleaned = _notesCtrl.text
                  .replaceAll(
                    RegExp(
                      r'^#{1,6}\s+|^[-*]\s+|^\d+\.\s+|^>\s?|^```.*$',
                      multiLine: true,
                    ),
                    '',
                  )
                  .replaceAll(RegExp(r'\*\*|__|~~|`'), '');
              final plainText = cleaned.replaceAllMapped(
                RegExp(r'\[([^\]]+)\]\([^)]+\)'),
                (match) => match.group(1) ?? '',
              );
              _notesCtrl.value = TextEditingValue(
                text: plainText,
                selection: TextSelection.collapsed(offset: plainText.length),
              );
              _notesFocus.requestFocus();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'clear', child: Text('Clear formatting')),
          ],
        ),
      ],
    );
  }

  Future<void> _addAttachments() async {
    setState(() => _isPickingAttachments = true);
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select secure attachments',
      );
      if (files.isEmpty || !mounted) return;
      final picked = <CredentialAttachment>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        picked.add(CredentialAttachment(name: file.name, bytes: bytes));
      }
      setState(() => _attachments.addAll(picked));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(picked.length == 1
                ? 'Attachment "${picked.first.name}" added.'
                : '${picked.length} attachments added.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach file: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingAttachments = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final normalizedUrl = _urlCtrl.text.trim();
    final websiteIconUrl =
        _isValidUrl(normalizedUrl) ? _faviconUrl(normalizedUrl) : '';
    final entry = (widget.existing ??
            CredentialEntry(
              title: _titleCtrl.text.trim(),
              username: _userCtrl.text.trim(),
              password: _passCtrl.text,
              websiteUrl: normalizedUrl,
              websiteIconUrl: websiteIconUrl,
              notes: _notesCtrl.toFormattedString().trim(),
              category: _category,
              customFields: _customFields,
              attachments: _attachments,
            ))
        .copyWith(
      title: _titleCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      websiteUrl: normalizedUrl,
      websiteIconUrl: websiteIconUrl,
      notes: _notesCtrl.toFormattedString().trim(),
      category: _category,
      customFields: _customFields,
      attachments: _attachments,
    );
    setState(() => _isSaving = true);
    try {
      await widget.onSave(entry);
      if (mounted) {
        Navigator.pop(context, entry);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save password: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildUrlPreview() {
    final url = _urlCtrl.text.trim();
    final isValid = _isValidUrl(url);
    final host = _extractHost(url);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isValid
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isValid ? scheme.primary.withValues(alpha: 0.4) : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isValid ? Colors.white : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isValid
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: isValid
                ? Image.network(
                    _faviconUrl(url),
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.language_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  )
                : Icon(
                    Icons.language_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isValid ? host : 'Valid website URL will show a website icon',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
                    color: isValid ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
                if (isValid)
                  Text(
                    'Website icon active',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add password' : 'Edit password'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            TextFormField(
              controller: _titleCtrl,
              scrollPadding: const EdgeInsets.all(24),
              decoration: const InputDecoration(
                  labelText: 'Name *', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _userCtrl,
              scrollPadding: const EdgeInsets.all(24),
              decoration: const InputDecoration(
                  labelText: 'Username or email *',
                  border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter a username or email.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('credential_password_field'),
              controller: _passCtrl,
              obscureText: _obscurePassword,
              scrollPadding: const EdgeInsets.all(24),
              decoration: InputDecoration(
                labelText: 'Password *',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _urlCtrl,
              scrollPadding: const EdgeInsets.all(24),
              decoration: InputDecoration(
                labelText: 'Website URL',
                prefixIcon: _isUrlValid
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.network(
                          _faviconUrl(_urlCtrl.text),
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.language_rounded, size: 20),
                        ),
                      )
                    : const Icon(Icons.language_rounded, size: 20),
                suffixIcon: _urlCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _urlCtrl.clear();
                          setState(() {
                            _isUrlValid = false;
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) => setState(() {
                _isUrlValid = _isValidUrl(value);
              }),
            ),
            _buildUrlPreview(),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                  labelText: 'Category', border: OutlineInputBorder()),
              items: [
                'General',
                'Work',
                'Finance',
                'Personal',
                'Social',
                'Other'
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'General'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _toggleNotesPreview,
                  icon: Icon(
                    _showNotesPreview ? Icons.edit_outlined : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(_showNotesPreview ? 'Edit' : 'Preview'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            IndexedStack(
              index: _showNotesPreview ? 1 : 0,
              children: [
                KeyedSubtree(
                  key: const ValueKey('editor'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showNotesFormatting) ...[
                          _buildNoteFormattingToolbar(),
                          Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ],
                        TextFormField(
                          key: const ValueKey('notes_field'),
                          controller: _notesCtrl,
                          focusNode: _notesFocus,
                          scrollPadding: const EdgeInsets.all(24),
                          decoration: const InputDecoration(
                            hintText: 'Write a note...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.all(16),
                            alignLabelWithHint: true,
                          ),
                          minLines: 5,
                          maxLines: 10,
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        _buildNoteComposerActions(),
                      ],
                    ),
                  ),
                ),
                KeyedSubtree(
                  key: const ValueKey('preview'),
                  child: Container(
                    key: const ValueKey('preview_container'),
                    constraints: const BoxConstraints(minHeight: 190),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: _notesCtrl.text.trim().isEmpty
                        ? Text(
                            'Your formatted notes will appear here.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          )
                        : FormattedNotes(notes: _notesCtrl.toFormattedString()),
                  ),
                ),
              ],
            ),
            if (_attachments.isNotEmpty)
              ..._attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final attachment = entry.value;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(attachment.name),
                    subtitle: Text(_formatFileSize(attachment.bytes.length)),
                    trailing: IconButton(
                      tooltip: 'Remove ${attachment.name}',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        final removedName = attachment.name;
                        setState(() => _attachments.removeAt(index));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Attachment "$removedName" removed.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: MediaQuery.of(context).viewInsets.bottom == 0,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
          ),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ),
      ),
    );
  }
}
