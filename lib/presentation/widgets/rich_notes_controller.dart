import 'package:flutter/material.dart';

class RichNotesController extends TextEditingController {
  static const int styleBold = 1;
  static const int styleItalic = 2;
  static const int styleUnderline = 4;
  static const int styleStrikethrough = 8;
  static const int styleCode = 16;

  List<int> _charStyles = [];
  final Map<int, int> _lineHeadings = {}; // lineIndex -> 0, 1, 2, 3
  int _activeStyle = 0;

  RichNotesController({String? text}) : super(text: text) {
    if (text != null && text.isNotEmpty) {
      _charStyles = List<int>.filled(text.length, 0);
    }
  }

  factory RichNotesController.fromFormattedString(String formatted) {
    final controller = RichNotesController();
    controller.loadFormattedString(formatted);
    return controller;
  }

  void _ensureStyleLength() {
    if (_charStyles.length < text.length) {
      final diff = text.length - _charStyles.length;
      _charStyles.addAll(List<int>.filled(diff, _activeStyle));
    } else if (_charStyles.length > text.length) {
      _charStyles = _charStyles.sublist(0, text.length);
    }
  }

  @override
  set value(TextEditingValue newTextEditingValue) {
    final oldText = text;
    var newText = newTextEditingValue.text;
    var newSelection = newTextEditingValue.selection;

    // Detect if Enter/newline was typed (single \n insertion) to handle list continuation/termination
    if (newText.length == oldText.length + 1 && newSelection.isCollapsed) {
      final insertPos = newSelection.baseOffset - 1;
      if (insertPos >= 0 && insertPos < newText.length && newText[insertPos] == '\n') {
        final prevLineStart = insertPos == 0
            ? 0
            : (newText.lastIndexOf('\n', insertPos - 1) + 1);
        final prevLine = newText.substring(prevLineStart, insertPos);

        final emptyBulletMatch =
            RegExp(r'^(\s*)(•\s*|[-*]\s*)$').firstMatch(prevLine);
        if (emptyBulletMatch != null) {
          // User pressed Enter on an empty bullet line -> exit list!
          final cleanedBefore = newText.substring(0, prevLineStart);
          final cleanedAfter = newText.substring(insertPos + 1);
          newText = cleanedBefore + cleanedAfter;
          newSelection = TextSelection.collapsed(offset: prevLineStart);
        } else {
          final emptyNumMatch =
              RegExp(r'^(\s*)(\d+)\.\s*$').firstMatch(prevLine);
          if (emptyNumMatch != null) {
            // User pressed Enter on an empty numbered item -> exit list!
            final cleanedBefore = newText.substring(0, prevLineStart);
            final cleanedAfter = newText.substring(insertPos + 1);
            newText = cleanedBefore + cleanedAfter;
            newSelection = TextSelection.collapsed(offset: prevLineStart);
          } else {
            final bulletMatch =
                RegExp(r'^(\s*)(•\s+|[-*]\s+)').firstMatch(prevLine);
            if (bulletMatch != null) {
              final indent = bulletMatch.group(1) ?? '';
              final bulletPrefix = '$indent• ';
              newText = newText.substring(0, insertPos + 1) +
                  bulletPrefix +
                  newText.substring(insertPos + 1);
              newSelection = TextSelection.collapsed(
                offset: insertPos + 1 + bulletPrefix.length,
              );
            } else {
              final numMatch =
                  RegExp(r'^(\s*)(\d+)\.\s+').firstMatch(prevLine);
              if (numMatch != null) {
                final indent = numMatch.group(1) ?? '';
                final currentNum = int.tryParse(numMatch.group(2) ?? '1') ?? 1;
                final nextNumPrefix = '$indent${currentNum + 1}. ';
                newText = newText.substring(0, insertPos + 1) +
                    nextNumPrefix +
                    newText.substring(insertPos + 1);
                newSelection = TextSelection.collapsed(
                  offset: insertPos + 1 + nextNumPrefix.length,
                );
              }
            }
          }
        }
      }
    }

    if (oldText != newText) {
      if (oldText.isEmpty) {
        _charStyles = List<int>.filled(newText.length, _activeStyle);
      } else if (newText.isEmpty) {
        _charStyles = [];
        _lineHeadings.clear();
      } else {
        // Find common prefix
        var prefixLen = 0;
        final minLen = oldText.length < newText.length ? oldText.length : newText.length;
        while (prefixLen < minLen && oldText[prefixLen] == newText[prefixLen]) {
          prefixLen++;
        }

        // Find common suffix
        var oldSuffix = oldText.length;
        var newSuffix = newText.length;
        while (oldSuffix > prefixLen &&
            newSuffix > prefixLen &&
            oldText[oldSuffix - 1] == newText[newSuffix - 1]) {
          oldSuffix--;
          newSuffix--;
        }

        final insertedCount = newSuffix - prefixLen;

        final newStyles = <int>[];
        if (prefixLen > 0 && prefixLen <= _charStyles.length) {
          newStyles.addAll(_charStyles.sublist(0, prefixLen));
        }

        final inherited = prefixLen > 0 && prefixLen - 1 < _charStyles.length
            ? _charStyles[prefixLen - 1]
            : _activeStyle;

        if (insertedCount > 0) {
          newStyles.addAll(List<int>.filled(insertedCount, inherited));
        }

        if (oldSuffix < _charStyles.length) {
          newStyles.addAll(_charStyles.sublist(oldSuffix));
        }

        _charStyles = newStyles;
        _ensureStyleLength();
      }
    }

    super.value = TextEditingValue(text: newText, selection: newSelection);
  }

  bool _isWordChar(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 95;
  }

  TextSelection _resolveSelection() {
    var sel = selection;
    if (!sel.isValid) {
      return TextSelection.collapsed(offset: text.length);
    }
    if (sel.isCollapsed && text.isNotEmpty) {
      var start = sel.baseOffset.clamp(0, text.length);
      var end = start;
      while (start > 0 && _isWordChar(text[start - 1])) {
        start--;
      }
      while (end < text.length && _isWordChar(text[end])) {
        end++;
      }
      if (start < end) {
        return TextSelection(baseOffset: start, extentOffset: end);
      }
    } else if (!sel.isCollapsed && text.isNotEmpty) {
      var start = sel.start.clamp(0, text.length);
      var end = sel.end.clamp(start, text.length);
      while (end > start && (text[end - 1] == ' ' || text[end - 1] == '\t')) {
        end--;
      }
      return TextSelection(baseOffset: start, extentOffset: end);
    }
    return sel;
  }

  void toggleStyleBit(int bit) {
    _ensureStyleLength();
    final sel = _resolveSelection();
    if (sel.isCollapsed) {
      _activeStyle ^= bit;
      notifyListeners();
      return;
    }

    final start = sel.start.clamp(0, _charStyles.length);
    final end = sel.end.clamp(start, _charStyles.length);
    if (start >= end) return;

    // If all characters in selection already have this bit, remove it (toggle off)
    var allHaveBit = true;
    for (var i = start; i < end; i++) {
      if ((_charStyles[i] & bit) == 0) {
        allHaveBit = false;
        break;
      }
    }

    for (var i = start; i < end; i++) {
      if (allHaveBit) {
        _charStyles[i] &= ~bit;
      } else {
        _charStyles[i] |= bit;
      }
    }

    selection = sel;
    notifyListeners();
  }

  void toggleBold() => toggleStyleBit(styleBold);
  void toggleItalic() => toggleStyleBit(styleItalic);
  void toggleUnderline() => toggleStyleBit(styleUnderline);
  void toggleStrikethrough() => toggleStyleBit(styleStrikethrough);
  void toggleCode() => toggleStyleBit(styleCode);

  void clearFormatting() {
    _ensureStyleLength();
    final sel = _resolveSelection();
    final start = sel.start.clamp(0, _charStyles.length);
    final end = sel.end.clamp(start, _charStyles.length);
    for (var i = start; i < end; i++) {
      _charStyles[i] = 0;
    }
    final lineIdx = _getLineIndexForOffset(start);
    _lineHeadings.remove(lineIdx);
    notifyListeners();
  }

  int _getLineIndexForOffset(int offset) {
    final clamped = offset.clamp(0, text.length);
    final sub = text.substring(0, clamped);
    return '\n'.allMatches(sub).length;
  }

  List<int> _getLineIndicesForSelection(TextSelection sel) {
    final startOffset = sel.start.clamp(0, text.length);
    final endOffset = sel.end.clamp(startOffset, text.length);
    final startLine = _getLineIndexForOffset(startOffset);
    final endLine = _getLineIndexForOffset(endOffset);
    return [for (var i = startLine; i <= endLine; i++) i];
  }

  void setHeadingLevel(int level) {
    final sel = _resolveSelection();
    final lineIndices = _getLineIndicesForSelection(sel);
    for (final lineIdx in lineIndices) {
      if (level <= 0) {
        _lineHeadings.remove(lineIdx);
      } else {
        _lineHeadings[lineIdx] = level;
      }
    }
    notifyListeners();
  }

  int getHeadingLevelForSelection() {
    final sel = _resolveSelection();
    final lineIdx = _getLineIndexForOffset(sel.start);
    return _lineHeadings[lineIdx] ?? 0;
  }

  void toggleBulletList() {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final lines = text.split('\n');
    final startLine = _getLineIndexForOffset(sel.start);
    final endLine = _getLineIndexForOffset(sel.end);

    var allBulleted = true;
    for (var i = startLine; i <= endLine && i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (!trimmed.startsWith('• ') && !trimmed.startsWith('- ') && !trimmed.startsWith('* ')) {
        allBulleted = false;
        break;
      }
    }

    final newLines = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (i >= startLine && i <= endLine) {
        var line = lines[i];
        if (allBulleted) {
          if (line.startsWith('• ')) {
            line = line.substring(2);
          } else if (line.startsWith('- ') || line.startsWith('* ')) {
            line = line.substring(2);
          }
        } else {
          if (line.startsWith('• ')) {
            // Already bulleted
          } else if (line.startsWith('- ') || line.startsWith('* ')) {
            line = '• ${line.substring(2)}';
          } else {
            final numMatch = RegExp(r'^\d+\.\s+').firstMatch(line);
            if (numMatch != null) {
              line = line.substring(numMatch.end);
            }
            line = '• $line';
          }
        }
        newLines.add(line);
      } else {
        newLines.add(lines[i]);
      }
    }

    final updated = newLines.join('\n');
    final newStartOffset = newLines.take(startLine).fold(0, (sum, l) => sum + l.length + 1);
    final newEndOffset = newLines.take(endLine + 1).fold(0, (sum, l) => sum + l.length + 1) - 1;
    final isCollapsed = sel.isCollapsed;
    value = TextEditingValue(
      text: updated,
      selection: isCollapsed
          ? TextSelection.collapsed(offset: newEndOffset.clamp(0, updated.length))
          : TextSelection(
              baseOffset: newStartOffset.clamp(0, updated.length),
              extentOffset: newEndOffset.clamp(0, updated.length),
            ),
    );
  }

  void toggleNumberedList() {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final lines = text.split('\n');
    final startLine = _getLineIndexForOffset(sel.start);
    final endLine = _getLineIndexForOffset(sel.end);

    var allNumbered = true;
    for (var i = startLine; i <= endLine && i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (!RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        allNumbered = false;
        break;
      }
    }

    final newLines = <String>[];
    var itemNumber = 1;
    for (var i = 0; i < lines.length; i++) {
      if (i >= startLine && i <= endLine) {
        var line = lines[i];
        if (allNumbered) {
          final numMatch = RegExp(r'^\d+\.\s+').firstMatch(line);
          if (numMatch != null) {
            line = line.substring(numMatch.end);
          }
        } else {
          if (line.startsWith('• ')) {
            line = line.substring(2);
          } else if (line.startsWith('- ') || line.startsWith('* ')) {
            line = line.substring(2);
          }
          final numMatch = RegExp(r'^\d+\.\s+').firstMatch(line);
          if (numMatch != null) {
            line = line.substring(numMatch.end);
          }
          line = '$itemNumber. $line';
          itemNumber++;
        }
        newLines.add(line);
      } else {
        newLines.add(lines[i]);
      }
    }

    final updated = newLines.join('\n');
    final newStartOffset = newLines.take(startLine).fold(0, (sum, l) => sum + l.length + 1);
    final newEndOffset = newLines.take(endLine + 1).fold(0, (sum, l) => sum + l.length + 1) - 1;
    final isCollapsed = sel.isCollapsed;
    value = TextEditingValue(
      text: updated,
      selection: isCollapsed
          ? TextSelection.collapsed(offset: newEndOffset.clamp(0, updated.length))
          : TextSelection(
              baseOffset: newStartOffset.clamp(0, updated.length),
              extentOffset: newEndOffset.clamp(0, updated.length),
            ),
    );
  }

  void toggleQuote() {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final lines = text.split('\n');
    final startLine = _getLineIndexForOffset(sel.start);
    final endLine = _getLineIndexForOffset(sel.end);

    var allQuoted = true;
    for (var i = startLine; i <= endLine && i < lines.length; i++) {
      if (!lines[i].startsWith('> ')) {
        allQuoted = false;
        break;
      }
    }

    final newLines = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (i >= startLine && i <= endLine) {
        var line = lines[i];
        if (allQuoted) {
          line = line.substring(2);
        } else {
          line = '> $line';
        }
        newLines.add(line);
      } else {
        newLines.add(lines[i]);
      }
    }

    final updated = newLines.join('\n');
    final newStartOffset = newLines.take(startLine).fold(0, (sum, l) => sum + l.length + 1);
    final newEndOffset = newLines.take(endLine + 1).fold(0, (sum, l) => sum + l.length + 1) - 1;
    value = TextEditingValue(
      text: updated,
      selection: TextSelection(
        baseOffset: newStartOffset.clamp(0, updated.length),
        extentOffset: newEndOffset.clamp(0, updated.length),
      ),
    );
  }

  void insertDivider() {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final curText = text;
    const insertText = '\n---\n';
    final updated = curText.replaceRange(sel.start, sel.end, insertText);
    value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: sel.start + insertText.length),
    );
  }

  void insertLink(String url, {String? label}) {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final selectedText = sel.isCollapsed ? (label ?? url) : text.substring(sel.start, sel.end);
    final cleanUrl = url.trim();
    final insertText = (selectedText.isEmpty || selectedText == cleanUrl || selectedText == 'link text')
        ? cleanUrl
        : '[$selectedText]($cleanUrl)';
    final updated = text.replaceRange(sel.start, sel.end, insertText);
    value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: sel.start + insertText.length),
    );
  }

  void loadFormattedString(String formatted) {
    if (formatted.isEmpty) {
      super.value = const TextEditingValue(text: '');
      _charStyles = [];
      _lineHeadings.clear();
      return;
    }

    final rawLines = formatted.split('\n');
    final plainLines = <String>[];
    final lineStylesList = <List<int>>[];
    _lineHeadings.clear();

    for (var lineIdx = 0; lineIdx < rawLines.length; lineIdx++) {
      var line = rawLines[lineIdx];

      // Check heading
      final headingMatch = RegExp(r'^\s*(#{1,3})\s+(.*)$').firstMatch(line);
      if (headingMatch != null) {
        _lineHeadings[lineIdx] = headingMatch.group(1)!.length;
        line = headingMatch.group(2)!;
      }

      // Check bullet list
      final bulletMatch = RegExp(r'^\s*[-*•]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        line = '• ${bulletMatch.group(1)}';
      }

      // Parse inline markdown tokens
      final linePlainText = StringBuffer();
      final lineStyles = <int>[];

      var i = 0;
      while (i < line.length) {
        // Triple bold-italic ***text***
        if (line.startsWith('***', i)) {
          final endIdx = line.indexOf('***', i + 3);
          if (endIdx != -1) {
            final inner = line.substring(i + 3, endIdx);
            linePlainText.write(inner);
            lineStyles.addAll(List<int>.filled(inner.length, styleBold | styleItalic));
            i = endIdx + 3;
            continue;
          }
        }
        // Bold **text**
        if (line.startsWith('**', i)) {
          final endIdx = line.indexOf('**', i + 2);
          if (endIdx != -1) {
            final inner = line.substring(i + 2, endIdx);
            linePlainText.write(inner);
            lineStyles.addAll(List<int>.filled(inner.length, styleBold));
            i = endIdx + 2;
            continue;
          }
        }
        // Underline __text__
        if (line.startsWith('__', i)) {
          final endIdx = line.indexOf('__', i + 2);
          if (endIdx != -1) {
            final inner = line.substring(i + 2, endIdx);
            linePlainText.write(inner);
            lineStyles.addAll(List<int>.filled(inner.length, styleUnderline));
            i = endIdx + 2;
            continue;
          }
        }
        // Strikethrough ~~text~~
        if (line.startsWith('~~', i)) {
          final endIdx = line.indexOf('~~', i + 2);
          if (endIdx != -1) {
            final inner = line.substring(i + 2, endIdx);
            linePlainText.write(inner);
            lineStyles.addAll(List<int>.filled(inner.length, styleStrikethrough));
            i = endIdx + 2;
            continue;
          }
        }
        // Code `text`
        if (line.startsWith('`', i) && !line.startsWith('```', i)) {
          final endIdx = line.indexOf('`', i + 1);
          if (endIdx != -1) {
            final inner = line.substring(i + 1, endIdx);
            linePlainText.write(inner);
            lineStyles.addAll(List<int>.filled(inner.length, styleCode));
            i = endIdx + 1;
            continue;
          }
        }
        // Italic *text*
        if (line.startsWith('*', i) && (i + 1 < line.length) && line[i + 1] != ' ') {
          final endIdx = line.indexOf('*', i + 1);
          if (endIdx != -1) {
            final inner = line.substring(i + 1, endIdx);
            linePlainText.write(inner);
            lineStyles.addAll(List<int>.filled(inner.length, styleItalic));
            i = endIdx + 1;
            continue;
          }
        }

        linePlainText.write(line[i]);
        lineStyles.add(0);
        i++;
      }

      plainLines.add(linePlainText.toString());
      lineStylesList.add(lineStyles);
    }

    final combinedText = plainLines.join('\n');
    final combinedStyles = <int>[];
    for (var l = 0; l < lineStylesList.length; l++) {
      combinedStyles.addAll(lineStylesList[l]);
      if (l < lineStylesList.length - 1) {
        combinedStyles.add(0); // for '\n'
      }
    }

    super.value = TextEditingValue(
      text: combinedText,
      selection: TextSelection.collapsed(offset: combinedText.length),
    );
    _charStyles = combinedStyles;
  }

  String toFormattedString() {
    _ensureStyleLength();
    if (text.isEmpty) return '';

    final lines = text.split('\n');
    final formattedLines = <String>[];
    var globalCharIndex = 0;

    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      final headingLevel = _lineHeadings[lineIdx] ?? 0;

      var linePrefix = '';
      if (headingLevel == 1) {
        linePrefix = '# ';
      } else if (headingLevel == 2) {
        linePrefix = '## ';
      } else if (headingLevel == 3) {
        linePrefix = '### ';
      }

      var content = line;
      var lineOffset = globalCharIndex;
      if (content.startsWith('• ')) {
        linePrefix += '- ';
        content = content.substring(2);
        lineOffset += 2;
      }

      final lineBuffer = StringBuffer();
      var segStart = 0;

      while (segStart < content.length) {
        final currentStyle = (lineOffset + segStart < _charStyles.length)
            ? _charStyles[lineOffset + segStart]
            : 0;
        var segEnd = segStart + 1;
        while (segEnd < content.length &&
            (lineOffset + segEnd < _charStyles.length) &&
            _charStyles[lineOffset + segEnd] == currentStyle) {
          segEnd++;
        }

        final segText = content.substring(segStart, segEnd);
        var formattedSeg = segText;

        if ((currentStyle & styleCode) != 0) {
          formattedSeg = '`$formattedSeg`';
        }
        if ((currentStyle & styleStrikethrough) != 0) {
          formattedSeg = '~~$formattedSeg~~';
        }
        if ((currentStyle & styleUnderline) != 0) {
          formattedSeg = '__${formattedSeg}__';
        }
        if ((currentStyle & styleBold) != 0 && (currentStyle & styleItalic) != 0) {
          formattedSeg = '***$formattedSeg***';
        } else if ((currentStyle & styleBold) != 0) {
          formattedSeg = '**$formattedSeg**';
        } else if ((currentStyle & styleItalic) != 0) {
          formattedSeg = '*$formattedSeg*';
        }

        lineBuffer.write(formattedSeg);
        segStart = segEnd;
      }

      formattedLines.add('$linePrefix${lineBuffer.toString()}');
      globalCharIndex += line.length + 1; // +1 for '\n'
    }

    return formattedLines.join('\n');
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    if (text.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    _ensureStyleLength();

    final lines = text.split('\n');
    final children = <InlineSpan>[];
    var globalCharIndex = 0;

    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      final headingLevel = _lineHeadings[lineIdx] ?? 0;

      TextStyle lineStyle = baseStyle;
      if (headingLevel == 1) {
        lineStyle = lineStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) * 1.5,
          fontWeight: FontWeight.bold,
          height: 1.35,
        );
      } else if (headingLevel == 2) {
        lineStyle = lineStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) * 1.25,
          fontWeight: FontWeight.bold,
          height: 1.35,
        );
      } else if (headingLevel == 3) {
        lineStyle = lineStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) * 1.1,
          fontWeight: FontWeight.bold,
          height: 1.35,
        );
      }

      if (line.isEmpty) {
        if (lineIdx < lines.length - 1) {
          children.add(TextSpan(text: '\n', style: lineStyle));
          globalCharIndex++;
        }
        continue;
      }

      var segStart = 0;
      while (segStart < line.length) {
        final currentStyleFlags = (globalCharIndex + segStart < _charStyles.length)
            ? _charStyles[globalCharIndex + segStart]
            : 0;
        var segEnd = segStart + 1;
        while (segEnd < line.length &&
            (globalCharIndex + segEnd < _charStyles.length) &&
            _charStyles[globalCharIndex + segEnd] == currentStyleFlags) {
          segEnd++;
        }

        final segText = line.substring(segStart, segEnd);
        var spanStyle = lineStyle;
        if ((currentStyleFlags & styleBold) != 0) {
          spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
        }
        if ((currentStyleFlags & styleItalic) != 0) {
          spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
        }
        if ((currentStyleFlags & styleUnderline) != 0 &&
            (currentStyleFlags & styleStrikethrough) != 0) {
          spanStyle = spanStyle.copyWith(
            decoration: TextDecoration.combine([
              TextDecoration.underline,
              TextDecoration.lineThrough,
            ]),
          );
        } else if ((currentStyleFlags & styleUnderline) != 0) {
          spanStyle = spanStyle.copyWith(decoration: TextDecoration.underline);
        } else if ((currentStyleFlags & styleStrikethrough) != 0) {
          spanStyle = spanStyle.copyWith(decoration: TextDecoration.lineThrough);
        }
        if ((currentStyleFlags & styleCode) != 0) {
          spanStyle = spanStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
          );
        }

        final linkRegex = RegExp(r'(\[[^\]]+\]\([^)]+\)|https?:\/\/[^\s]+)');
        final matches = linkRegex.allMatches(segText);
        if (matches.isEmpty) {
          children.add(TextSpan(text: segText, style: spanStyle));
        } else {
          var subOffset = 0;
          for (final m in matches) {
            if (m.start > subOffset) {
              children.add(TextSpan(
                text: segText.substring(subOffset, m.start),
                style: spanStyle,
              ));
            }
            final rawMatch = m.group(0)!;
            if (rawMatch.startsWith('[')) {
              final parsed =
                  RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$').firstMatch(rawMatch);
              final linkLabel = parsed?.group(1) ?? rawMatch;
              children.add(TextSpan(
                text: '🔗 $linkLabel',
                style: spanStyle.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ));
            } else {
              children.add(TextSpan(
                text: rawMatch,
                style: spanStyle.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ));
            }
            subOffset = m.end;
          }
          if (subOffset < segText.length) {
            children.add(TextSpan(
              text: segText.substring(subOffset),
              style: spanStyle,
            ));
          }
        }
        segStart = segEnd;
      }

      globalCharIndex += line.length;
      if (lineIdx < lines.length - 1) {
        children.add(TextSpan(text: '\n', style: lineStyle));
        globalCharIndex++;
      }
    }

    return TextSpan(style: baseStyle, children: children);
  }
}
