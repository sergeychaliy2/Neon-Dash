import 'package:flutter/services.dart';

class KeyboardSteering {
  const KeyboardSteering();

  double axis() {
    final keyboard = HardwareKeyboard.instance;

    var axis = 0.0;
    if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowLeft) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyA)) {
      axis -= 1.0;
    }
    if (keyboard.isLogicalKeyPressed(LogicalKeyboardKey.arrowRight) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.keyD)) {
      axis += 1.0;
    }
    return axis;
  }

  static const List<List<LogicalKeyboardKey>> _slotKeys =
      <List<LogicalKeyboardKey>>[
    <LogicalKeyboardKey>[LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
    <LogicalKeyboardKey>[LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
    <LogicalKeyboardKey>[LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
  ];

  static int get slotKeyCount => _slotKeys.length;

  bool slotPressed(int index) {
    if (index < 0 || index >= _slotKeys.length) return false;

    final keyboard = HardwareKeyboard.instance;
    for (final key in _slotKeys[index]) {
      if (keyboard.isLogicalKeyPressed(key)) return true;
    }
    return false;
  }

  bool get confirmPressed {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isLogicalKeyPressed(LogicalKeyboardKey.space) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.enter) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.numpadEnter);
  }
}
