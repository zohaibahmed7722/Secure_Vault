import 'dart:async';
import 'package:flutter/services.dart';

class SafeClipboardService {
  Timer? _clearTimer;

  Future<void> copySensitive(String text, {Duration ttl = const Duration(seconds: 30)}) async {
    _clearTimer?.cancel();
    await Clipboard.setData(ClipboardData(text: text));
    _clearTimer = Timer(ttl, () async {
      await clear();
    });
  }

  Future<void> clear() async {
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  void dispose() {
    _clearTimer?.cancel();
  }
}