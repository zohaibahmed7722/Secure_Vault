import 'package:flutter/material.dart';
import '../../core/platform/clipboard_service.dart';
import '../../domain/models/credential_entry.dart';
import '../../domain/repositories/vault_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/profile_avatar.dart';
import 'credential_detail_screen.dart';
import 'credential_edit_screen.dart';
import 'profile_screen.dart';

class VaultDashboard extends StatefulWidget {
  final VaultRepository repository;
  final VoidCallback onLock;
  final SafeClipboardService clipboardService;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode themeMode) onThemeModeChanged;
  final Color themeColor;
  final Future<void> Function(Color color) onThemeColorChanged;
  final VoidCallback? onResetVault;

  const VaultDashboard({
    super.key,
    required this.repository,
    required this.onLock,
    this.onResetVault,
    required this.clipboardService,
    this.themeMode = ThemeMode.light,
    required this.onThemeModeChanged,
    this.themeColor = AppTheme.brandColor,
    required this.onThemeColorChanged,
  });

  @override
  State<VaultDashboard> createState() => _VaultDashboardState();
}

class _VaultDashboardState extends State<VaultDashboard> {
  static const _entryCategories = {
    'General',
    'Work',
    'Finance',
    'Personal',
    'Social',
  };
  static const _categories = [
    'All',
    'Favorites',
    'General',
    'Work',
    'Finance',
    'Personal',
    'Social',
    'Other',
  ];

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<CredentialEntry> get _filteredEntries {
    final query = _searchQuery.trim().toLowerCase();
    final entries = widget.repository.entries.where((entry) {
      final matchesSearch = query.isEmpty ||
          entry.title.toLowerCase().contains(query) ||
          entry.username.toLowerCase().contains(query) ||
          entry.websiteUrl.toLowerCase().contains(query);
      final matchesCategory = switch (_selectedCategory) {
        'Favorites' => entry.isFavorite,
        'All' => true,
        'Other' => entry.category == 'Other' ||
            !_entryCategories.contains(entry.category),
        _ => entry.category == _selectedCategory,
      };
      return matchesSearch && matchesCategory;
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return entries;
  }

  Future<void> _saveEntry(CredentialEntry entry) async {
    final isNew = !widget.repository.entries.any((e) => e.id == entry.id);
    await widget.repository.saveCredential(entry);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNew
              ? 'Password saved successfully.'
              : 'Password updated successfully.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CredentialEditScreen(onSave: _saveEntry),
      ),
    );
  }



  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          repository: widget.repository,
          onLock: () {
            Navigator.pop(context);
            widget.onLock();
          },
          onResetVault: widget.onResetVault,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          themeColor: widget.themeColor,
          onThemeColorChanged: widget.onThemeColorChanged,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openEntry(CredentialEntry item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CredentialDetailScreen(
          entry: item,
          clipboardService: widget.clipboardService,
          onFavoriteChanged: (isFavorite) =>
              _saveEntry(item.copyWith(isFavorite: isFavorite)),
          onEdit: (detailContext) {
            Navigator.pushReplacement(
              detailContext,
              MaterialPageRoute(
                builder: (_) => CredentialEditScreen(
                  existing: item,
                  onSave: _saveEntry,
                ),
              ),
            );
          },
          onDelete: () async {
            await widget.repository.deleteCredential(item.id);
            if (mounted) {
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Credential "${item.title}" deleted.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category) {
        'Finance' => Icons.account_balance_outlined,
        'Work' => Icons.work_outline,
        'Personal' => Icons.person_outline,
        'Social' => Icons.people_outline,
        'Other' => Icons.folder_outlined,
        _ => Icons.key_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;
    final totalCount = widget.repository.entries.length;
    final profileImage = widget.repository.profileImage;
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isLandscapeKeyboard = isKeyboardVisible && MediaQuery.sizeOf(context).height < 500;
    final categoryCounts = <String, int>{
      for (final category in _categories) category: 0,
    };
    categoryCounts['All'] = totalCount;
    for (final entry in widget.repository.entries) {
      if (entry.isFavorite) {
        categoryCounts['Favorites'] = categoryCounts['Favorites']! + 1;
      }
      if (categoryCounts.containsKey(entry.category)) {
        categoryCounts[entry.category] = categoryCounts[entry.category]! + 1;
      } else {
        categoryCounts['Other'] = categoryCounts['Other']! + 1;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Credentials',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Profile',
              onPressed: _openProfile,
              icon: ProfileAvatar(
                radius: 17,
                image: profileImage,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.primary,
                iconSize: 20,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock vault',
            onPressed: widget.onLock,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isLandscapeKeyboard)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Color.lerp(Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary, 0.62)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.verified_user_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'Your vault is protected',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              totalCount == 1
                                  ? '1 saved item'
                                  : '$totalCount saved items',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Encrypted and stored on this device',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_moon_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
              child: TextField(
                key: const ValueKey('vault_search_field'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                scrollPadding: const EdgeInsets.all(24),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search your vault',
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onTap: () {
                  _searchFocusNode.requestFocus();
                },
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (!isLandscapeKeyboard) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final selected = _selectedCategory == category;
                    return ChoiceChip(
                      label: Text('$category ${categoryCounts[category]}'),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = category),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: entries.isEmpty
                  ? _EmptyState(
                      isSearching: _searchQuery.isNotEmpty,
                      hasAnyEntries: totalCount > 0,
                      onAdd: _openAdd,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: entries.length + 1,
                      separatorBuilder: (_, index) => index == 0
                          ? const SizedBox(height: 10)
                          : const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
                            child: Row(
                              children: [
                                Text(
                                  _selectedCategory == 'All'
                                      ? 'All credentials'
                                      : _selectedCategory,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${entries.length} ${entries.length == 1 ? 'item' : 'items'}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final entry = entries[index - 1];
                        return Material(
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                          elevation: 1,
                          clipBehavior: Clip.antiAlias,
                          child: _CredentialTile(
                            entry: entry,
                            icon: _categoryIcon(entry.category),
                            onTap: () => _openEntry(entry),
                            onFavorite: () => _saveEntry(
                              entry.copyWith(isFavorite: !entry.isFavorite),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: isKeyboardVisible
          ? null
          : AnimatedPressable(
              onTap: _openAdd,
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: _openAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add credential'),
              ),
            ),
    );
  }
}

class _CredentialTile extends StatelessWidget {
  final CredentialEntry entry;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _CredentialTile({
    required this.entry,
    required this.icon,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer,
              scheme.primaryContainer.withValues(alpha: 0.58),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: entry.websiteIconUrl.isNotEmpty
            ? Image.network(
                entry.websiteIconUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(icon, color: color, size: 22),
              )
            : Icon(icon, color: color, size: 22),
      ),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: -0.15,
        ),
      ),
      subtitle: Text(
        entry.username.isNotEmpty && entry.websiteUrl.isNotEmpty
            ? '${entry.username} • ${entry.websiteUrl}'
            : entry.username.isNotEmpty
                ? entry.username
                : entry.websiteUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip:
                entry.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: onFavorite,
            icon: Icon(
              entry.isFavorite ? Icons.star : Icons.star_border,
              color: entry.isFavorite ? Colors.amber.shade800 : null,
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isSearching;
  final bool hasAnyEntries;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.isSearching,
    required this.hasAnyEntries,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final title = isSearching
        ? 'No matches'
        : hasAnyEntries
            ? 'Nothing in this section'
            : 'Keep your credentials together';
    final message = isSearching
        ? 'Try a different name, email, or website.'
        : hasAnyEntries
            ? 'Save an item here by marking it as a favorite or choosing another section.'
            : 'Save logins and private notes in one secure place.';

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSearching ? Icons.search_off : Icons.lock_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
