import 'package:flutter/material.dart';

class FormattedNotes extends StatelessWidget {
  final String notes;

  const FormattedNotes({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = notes.split('\n');
    final children = <Widget>[];
    var insideCodeBlock = false;

    for (final line in lines) {
      if (line.trim().startsWith('```')) {
        insideCodeBlock = !insideCodeBlock;
        continue;
      }

      if (line.trim() == '---') {
        children.add(const Divider(height: 18));
        continue;
      }

      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      if (insideCodeBlock) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final heading = RegExp(r'^\s*(#{1,6})\s+(.*)$').firstMatch(line);
      var content = heading?.group(2) ?? line;
      final headingDepth = heading?.group(1)?.length ?? 0;
      final style = switch (headingDepth) {
        1 => theme.textTheme.headlineSmall,
        2 => theme.textTheme.titleLarge,
        3 => theme.textTheme.titleMedium,
        _ => theme.textTheme.bodyLarge,
      };

      var prefix = '';
      var isQuote = false;
      final quote = RegExp(r'^>\s?').firstMatch(content);
      if (quote != null) {
        isQuote = true;
        content = content.substring(quote.end);
      } else {
        final numbered = RegExp(r'^(\d+)\.\s+').firstMatch(content);
        final bullet = RegExp(r'^[-*•]\s+').firstMatch(content);
        if (numbered != null) {
          prefix = '${numbered.group(1)}. ';
          content = content.substring(numbered.end);
        } else if (bullet != null) {
          prefix = '• ';
          content = content.substring(bullet.end);
        }
      }

      final spans = _inlineSpans(content, theme);
      if (prefix.isNotEmpty) {
        spans.insert(0, TextSpan(text: prefix, style: style));
      }
      final richText = Text.rich(
        TextSpan(style: style, children: spans),
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: isQuote
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    ),
                  ),
                  child: richText,
                )
              : richText,
        ),
      );
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  List<InlineSpan> _inlineSpans(
    String content,
    ThemeData theme,
  ) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*\*.+?\*\*\*|\*\*.+?\*\*|__.+?__|~~.+?__|`[^`]+`|\*[^*]+\*|\[[^\]]+\]\([^)]+\)|\[[^\]]+\]|https?:\/\/[^\s]+)',
    );
    var offset = 0;

    for (final match in pattern.allMatches(content)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: content.substring(offset, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('***')) {
        spans.add(
          TextSpan(
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
            children: _inlineSpans(token.substring(3, token.length - 3), theme),
          ),
        );
      } else if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            style: const TextStyle(fontWeight: FontWeight.bold),
            children: _inlineSpans(token.substring(2, token.length - 2), theme),
          ),
        );
      } else if (token.startsWith('__')) {
        spans.add(
          TextSpan(
            style: const TextStyle(decoration: TextDecoration.underline),
            children: _inlineSpans(token.substring(2, token.length - 2), theme),
          ),
        );
      } else if (token.startsWith('~~')) {
        spans.add(
          TextSpan(
            style: const TextStyle(decoration: TextDecoration.lineThrough),
            children: _inlineSpans(token.substring(2, token.length - 2), theme),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(140),
            ),
          ),
        );
      } else if (token.startsWith('[')) {
        final linkWithUrl = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$').firstMatch(token);
        final bracketOnly = RegExp(r'^\[([^\]]+)\]$').firstMatch(token);
        final linkLabel = linkWithUrl?.group(1) ?? bracketOnly?.group(1) ?? token;
        spans.add(
          TextSpan(
            text: '🔗 $linkLabel',
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (token.startsWith('http://') || token.startsWith('https://')) {
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            style: const TextStyle(fontStyle: FontStyle.italic),
            children: _inlineSpans(token.substring(1, token.length - 1), theme),
          ),
        );
      }
      offset = match.end;
    }

    if (offset < content.length) {
      spans.add(TextSpan(text: content.substring(offset)));
    }
    return spans;
  }
}
