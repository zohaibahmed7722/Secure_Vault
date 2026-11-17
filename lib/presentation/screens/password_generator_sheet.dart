import 'package:flutter/material.dart';
import '../../domain/models/password_config.dart';

class PasswordGeneratorSheet extends StatefulWidget {
  final void Function(String password) onPasswordSelected;

  const PasswordGeneratorSheet({super.key, required this.onPasswordSelected});

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  double _length = 20;
  bool _includeUpper = true;
  bool _includeLower = true;
  bool _includeDigits = true;
  bool _includeSymbols = true;
  String _generated = '';
  double _entropy = 0;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    if (!_includeUpper &&
        !_includeLower &&
        !_includeDigits &&
        !_includeSymbols) {
      _includeLower = true;
    }
    final pass = PasswordGenerator.generate(
      length: _length.toInt(),
      includeUppercase: _includeUpper,
      includeLowercase: _includeLower,
      includeDigits: _includeDigits,
      includeSymbols: _includeSymbols,
    );
    setState(() {
      _generated = pass;
      _entropy = PasswordGenerator.calculateEntropy(pass);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Generate Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _regenerate,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _generated,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entropy: ${_entropy.toStringAsFixed(1)} bits (${_entropy > 100 ? "Very Strong" : "Moderate"})',
              style: TextStyle(
                fontSize: 12,
                color: _entropy > 100
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text('Length: ${_length.toInt()}'),
            Slider(
              value: _length,
              min: 12,
              max: 64,
              divisions: 52,
              onChanged: (value) {
                setState(() => _length = value);
                _regenerate();
              },
            ),
            SwitchListTile(
              title: const Text('Uppercase (A-Z)'),
              value: _includeUpper,
              dense: true,
              onChanged: (value) {
                setState(() => _includeUpper = value);
                _regenerate();
              },
            ),
            SwitchListTile(
              title: const Text('Lowercase (a-z)'),
              value: _includeLower,
              dense: true,
              onChanged: (value) {
                setState(() => _includeLower = value);
                _regenerate();
              },
            ),
            SwitchListTile(
              title: const Text('Numbers (0-9)'),
              value: _includeDigits,
              dense: true,
              onChanged: (value) {
                setState(() => _includeDigits = value);
                _regenerate();
              },
            ),
            SwitchListTile(
              title: const Text('Symbols (!@#\$...)'),
              value: _includeSymbols,
              dense: true,
              onChanged: (value) {
                setState(() => _includeSymbols = value);
                _regenerate();
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                widget.onPasswordSelected(_generated);
                Navigator.pop(context);
              },
              child: const Text('Use Password'),
            ),
          ],
        ),
      ),
    );
  }
}
