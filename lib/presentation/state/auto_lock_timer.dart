import 'dart:async';
import 'package:flutter/widgets.dart';

class AutoLockManager with WidgetsBindingObserver {
  final VoidCallback onLockTriggered;
  final Duration timeoutDuration;
  Timer? _inactivityTimer;
  DateTime _lastInteraction = DateTime.now();

  AutoLockManager({
    required this.onLockTriggered,
    this.timeoutDuration = const Duration(minutes: 3),
  }) {
    WidgetsBinding.instance.addObserver(this);
    resetTimer();
  }

  void resetTimer() {
    _lastInteraction = DateTime.now();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(timeoutDuration, () {
      onLockTriggered();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final elapsed = DateTime.now().difference(_lastInteraction);
      if (elapsed >= timeoutDuration) {
        _inactivityTimer?.cancel();
        onLockTriggered();
      } else {
        _inactivityTimer?.cancel();
        _inactivityTimer = Timer(timeoutDuration - elapsed, onLockTriggered);
      }
    }
  }

  void dispose() {
    _inactivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}