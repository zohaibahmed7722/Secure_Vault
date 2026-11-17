import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:secure_vault/presentation/widgets/rich_notes_controller.dart';

void main() {
  group('RichNotesController tests', () {
    test('loads formatted string and strips raw markdown markers from editor text', () {
      final ctrl = RichNotesController.fromFormattedString('## **Private note**');
      expect(ctrl.text, 'Private note');
      expect(ctrl.getHeadingLevelForSelection(), 2);
      expect(ctrl.toFormattedString(), '## **Private note**');
    });

    test('applies bold formatting to selected text without inserting asterisks', () {
      final ctrl = RichNotesController(text: 'Remember this');
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
      ctrl.toggleBold();

      // Editor text must NOT have asterisks
      expect(ctrl.text, 'Remember this');

      // Serialized formatted text retains markdown for persistence
      expect(ctrl.toFormattedString(), '**Remember** this');

      // Toggling off removes bold without losing text
      ctrl.toggleBold();
      expect(ctrl.text, 'Remember this');
      expect(ctrl.toFormattedString(), 'Remember this');
    });

    test('heading formatting changes heading level without inserting hash into editor text', () {
      final ctrl = RichNotesController(text: 'Important title');
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 15);
      ctrl.setHeadingLevel(1);

      expect(ctrl.text, 'Important title');
      expect(ctrl.getHeadingLevelForSelection(), 1);
      expect(ctrl.toFormattedString(), '# Important title');

      ctrl.setHeadingLevel(0);
      expect(ctrl.getHeadingLevelForSelection(), 0);
      expect(ctrl.toFormattedString(), 'Important title');
    });

    test('bullet list converts lines with bullet points', () {
      final ctrl = RichNotesController(text: 'Alpha\nBeta');
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 10);
      ctrl.toggleBulletList();

      expect(ctrl.text, '• Alpha\n• Beta');

      // Toggle off
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 14);
      ctrl.toggleBulletList();
      expect(ctrl.text, 'Alpha\nBeta');
    });

    test('numbered list formats lines with numbers', () {
      final ctrl = RichNotesController(text: 'Alpha\nBeta');
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 10);
      ctrl.toggleNumberedList();

      expect(ctrl.text, '1. Alpha\n2. Beta');
    });

    test('inline formatting options work without inserting markdown symbols into editor text', () {
      final ctrl = RichNotesController(text: 'Formatting test');

      // Italic
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 10);
      ctrl.toggleItalic();
      expect(ctrl.text, 'Formatting test');
      expect(ctrl.toFormattedString(), '*Formatting* test');

      // Underline
      ctrl.toggleUnderline();
      expect(ctrl.text, 'Formatting test');
      expect(ctrl.toFormattedString(), '*__Formatting__* test');

      // Strikethrough
      ctrl.toggleStrikethrough();
      expect(ctrl.text, 'Formatting test');
      expect(ctrl.toFormattedString(), '*__~~Formatting~~__* test');
    });

    test('reopening preserves saved note formatting accurately', () {
      const original = '# Title\n**Bold text** and *italic*\n- Item 1\n- Item 2';
      final ctrl1 = RichNotesController.fromFormattedString(original);
      final saved = ctrl1.toFormattedString();

      final ctrl2 = RichNotesController.fromFormattedString(saved);
      expect(ctrl2.text, 'Title\nBold text and italic\n• Item 1\n• Item 2');
      expect(ctrl2.toFormattedString(), original);
    });
  });
}
