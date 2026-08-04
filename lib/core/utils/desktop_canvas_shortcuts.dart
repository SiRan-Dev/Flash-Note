import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class DesktopCanvasShortcuts {
  const DesktopCanvasShortcuts._();

  static const fitView = SingleActivator(
    LogicalKeyboardKey.digit0,
    control: true,
  );
  static const zoomIn = SingleActivator(
    LogicalKeyboardKey.equal,
    control: true,
  );
  static const zoomOut = SingleActivator(
    LogicalKeyboardKey.minus,
    control: true,
  );
  static const reset = SingleActivator(LogicalKeyboardKey.keyR, control: true);
  static const delete = SingleActivator(LogicalKeyboardKey.delete);
  static const escape = SingleActivator(LogicalKeyboardKey.escape);
}
