import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Thin, failure-tolerant wrapper used by the custom caption buttons.
class WindowControls {
  WindowControls._();

  static bool get supported =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  static Future<void> startDragging() async {
    if (!supported) return;
    try {
      await windowManager.startDragging();
    } on Object {
      // Ignore: the widget test host has no window manager plugin.
    }
  }

  static Future<void> minimize() async {
    if (!supported) return;
    try {
      await windowManager.minimize();
    } on Object {
      // Ignore.
    }
  }

  static Future<void> toggleMaximize() async {
    if (!supported) return;
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } on Object {
      // Ignore.
    }
  }

  static Future<void> close() async {
    if (!supported) return;
    try {
      await windowManager.close();
    } on Object {
      // Ignore.
    }
  }
}
