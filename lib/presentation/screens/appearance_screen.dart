import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_app_icon.dart';

/// A dedicated screen for all display and appearance settings including
/// theme mode (light/dark), primary accent color selection, and splash screen preview.
class AppearanceScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode themeMode) onThemeModeChanged;
  final Color themeColor;
  final Future<void> Function(Color color) onThemeColorChanged;

  const AppearanceScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.themeColor,
    required this.onThemeColorChanged,
  });

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late TextEditingController _themeColorController;
  late Color _stagedColor;
  bool _isSavingColor = false;

  static const List<Color> _presetColors = [
    Color(0xFF5146E5), // Indigo
    Color(0xFF2563EB), // Blue
    Color(0xFF0D9488), // Teal
    Color(0xFF16A34A), // Green
    Color(0xFFD97706), // Amber
    Color(0xFFE11D48), // Crimson Rose
    Color(0xFF7C3AED), // Violet
    Color(0xFF475569), // Slate
  ];

  @override
  void initState() {
    super.initState();
    _stagedColor = widget.themeColor;
    _themeColorController = TextEditingController(
      text: AppTheme.hexColor(widget.themeColor),
    );
  }

  @override
  void didUpdateWidget(covariant AppearanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeColor != widget.themeColor) {
      _stagedColor = widget.themeColor;
      _themeColorController.text = AppTheme.hexColor(widget.themeColor);
    }
  }

  @override
  void dispose() {
    _themeColorController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveThemeColor() async {
    final color =
        AppTheme.parseHexColor(_themeColorController.text) ?? _stagedColor;
    try {
      setState(() => _isSavingColor = true);
      await widget.onThemeColorChanged(color);
      setState(() {
        _stagedColor = color;
        _themeColorController.text = AppTheme.hexColor(color);
      });
      if (mounted) _showMessage('Theme color updated.');
    } catch (error) {
      if (mounted) _showMessage('Could not update theme color: $error');
    } finally {
      if (mounted) setState(() => _isSavingColor = false);
    }
  }

  Future<void> _pickThemeColor() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => _ThemeColorPickerDialog(
        initialColor: _stagedColor,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _stagedColor = selected;
        _themeColorController.text = AppTheme.hexColor(selected);
      });
    }
  }

  void _previewSplash() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SplashPreviewScreen(primaryColor: _stagedColor),
      ),
    );
  }

  Widget _buildApplyColorButton(ColorScheme scheme) {
    final isStagedDifferent =
        _stagedColor.toARGB32() != widget.themeColor.toARGB32();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: isStagedDifferent ? _stagedColor : scheme.primary,
          foregroundColor: _stagedColor.computeLuminance() > 0.45
              ? Colors.black87
              : Colors.white,
          minimumSize: const Size.fromHeight(48),
          elevation: isStagedDifferent ? 3 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _saveThemeColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSavingColor)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                isStagedDifferent
                    ? Icons.check_circle_outline
                    : Icons.color_lens_outlined,
                size: 20,
              ),
            const SizedBox(width: 8),
            const Text(
              'Apply color',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance & Display'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'THEME MODE',
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
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: Icon(
                widget.themeMode == ThemeMode.dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                color: scheme.primary,
              ),
              title: const Text(
                'Dark mode',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                widget.themeMode == ThemeMode.dark
                    ? 'Dark background enabled'
                    : 'Light background enabled',
              ),
              value: widget.themeMode == ThemeMode.dark,
              onChanged: (enabled) async {
                try {
                  final newMode = enabled ? ThemeMode.dark : ThemeMode.light;
                  await widget.onThemeModeChanged(newMode);
                  if (mounted) {
                    _showMessage(
                      enabled ? 'Dark mode enabled.' : 'Light mode enabled.',
                    );
                  }
                } catch (error) {
                  if (mounted) {
                    _showMessage('Could not update appearance: $error');
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ACCENT & THEME COLOR',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('theme_color_field'),
            controller: _themeColorController,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Theme color hex',
              hintText: '#5146E5',
              prefixIcon: IconButton(
                key: const ValueKey('open_theme_color_picker'),
                tooltip: 'Choose theme color',
                onPressed: _pickThemeColor,
                icon: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _stagedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                ),
              ),
              suffixIcon: IconButton(
                tooltip: 'Choose from palette',
                onPressed: _pickThemeColor,
                icon: const Icon(Icons.colorize_rounded),
              ),
              helperText: 'Enter a 6-digit hex value or select a preset below.',
            ),
            onChanged: (value) {
              final parsed = AppTheme.parseHexColor(value);
              if (parsed != null && parsed != _stagedColor) {
                setState(() => _stagedColor = parsed);
              }
            },
            onSubmitted: (_) => _saveThemeColor(),
          ),
          const SizedBox(height: 12),
          _buildApplyColorButton(scheme),
          const SizedBox(height: 16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    VaultAppIcon(
                      size: 56,
                      primaryColor: _stagedColor,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'App Icon & Splash Screen',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _stagedColor.toARGB32() !=
                                    widget.themeColor.toARGB32()
                                ? 'Selected preview: ${AppTheme.hexColor(_stagedColor)} (Click Apply color above)'
                                : 'Active theme: ${AppTheme.hexColor(widget.themeColor)}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'PRESET PALETTES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _presetColors.map((color) {
                    final isSelected =
                        _stagedColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _stagedColor = color;
                          _themeColorController.text = AppTheme.hexColor(color);
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? (color.computeLuminance() > 0.45
                                    ? Colors.black87
                                    : Colors.white)
                                : Colors.transparent,
                            width: isSelected ? 3 : 0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 22,
                                color: color.computeLuminance() > 0.45
                                    ? Colors.black87
                                    : Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
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
                          Icon(Icons.info_outline, size: 16, color: scheme.primary),
                          const SizedBox(width: 6),
                          const Text(
                            'Why Two Splash Screens?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. Startup Splash: Runs during cold start while initializing storage and decrypting keys.\n2. Brand Splash: Seamless transition highlighting our offline, private design.',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _previewSplash,
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Preview Splash Screen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeColorPickerDialog extends StatefulWidget {
  const _ThemeColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_ThemeColorPickerDialog> createState() =>
      _ThemeColorPickerDialogState();
}

class _ThemeColorPickerDialogState extends State<_ThemeColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  Color get _currentColor =>
      HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _currentColor;

    return AlertDialog(
      title: const Text('Choose theme color'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              alignment: Alignment.center,
              child: Text(
                AppTheme.hexColor(color),
                key: const ValueKey('theme_color_picker_hex'),
                style: TextStyle(
                  color: color.computeLuminance() > 0.45
                      ? Colors.black87
                      : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Hue', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Slider(
              key: const ValueKey('theme_color_hue_picker'),
              value: _hue,
              min: 0,
              max: 360,
              onChanged: (val) => setState(() => _hue = val),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Saturation',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Slider(
              key: const ValueKey('theme_color_saturation_picker'),
              value: _saturation,
              min: 0.1,
              max: 1.0,
              onChanged: (val) => setState(() => _saturation = val),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Brightness',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Slider(
              key: const ValueKey('theme_color_value_picker'),
              value: _value,
              min: 0.2,
              max: 1.0,
              onChanged: (val) => setState(() => _value = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm_theme_color_picker'),
          onPressed: () => Navigator.pop(context, color),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _SplashPreviewScreen extends StatefulWidget {
  final Color primaryColor;

  const _SplashPreviewScreen({required this.primaryColor});

  @override
  State<_SplashPreviewScreen> createState() => _SplashPreviewScreenState();
}

class _SplashPreviewScreenState extends State<_SplashPreviewScreen> {
  int _activeSplashIndex = 0; // 0 = Startup Splash, 1 = Brand Splash

  @override
  Widget build(BuildContext context) {
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        widget.primaryColor.withValues(
          alpha: _activeSplashIndex == 0 ? 0.38 : 0.40,
        ),
        widget.primaryColor.withValues(
          alpha: _activeSplashIndex == 0 ? 0.12 : 0.14,
        ),
        Theme.of(context).scaffoldBackgroundColor,
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Startup Splash'),
              icon: Icon(Icons.shield_outlined, size: 16),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Brand Splash'),
              icon: Icon(Icons.verified_outlined, size: 16),
            ),
          ],
          selected: {_activeSplashIndex},
          onSelectionChanged: (set) =>
              setState(() => _activeSplashIndex = set.first),
        ),
        actions: [
          IconButton.filledTonal(
            icon: const Icon(Icons.close),
            tooltip: 'Close preview',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Container(
            key: const ValueKey('splash_preview_container'),
            decoration: BoxDecoration(gradient: bgGradient),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VaultAppIcon(
                    size: _activeSplashIndex == 0 ? 96 : 108,
                    primaryColor: widget.primaryColor,
                    secondaryColor: AppTheme.secondaryFor(
                      widget.primaryColor,
                      dark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Secure Vault',
                    style: TextStyle(
                      fontSize: _activeSplashIndex == 0 ? 30 : 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: _activeSplashIndex == 0 ? -0.6 : -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activeSplashIndex == 0
                        ? 'Your passwords, one safe place.'
                        : 'Private by design.',
                    style: TextStyle(
                      fontSize: _activeSplashIndex == 0 ? 14 : 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (_activeSplashIndex == 0) ...[
                    const SizedBox(height: 28),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.primaryColor.withValues(alpha: 0.18),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: widget.primaryColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Previewing ${_activeSplashIndex == 0 ? "Startup Splash" : "Brand Splash"} · ${AppTheme.hexColor(widget.primaryColor)}',
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _activeSplashIndex == 0
                              ? 'Phase 1: App launch & cryptographic initialization'
                              : 'Phase 2: Zero-telemetry & privacy assurance transition',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Settings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

