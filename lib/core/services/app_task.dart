import 'package:flutter/foundation.dart';

/// A background install or download, surfaced in the Steam-style bottom bar.
class AppTask extends ChangeNotifier {
  AppTask({required this.title});

  /// Human label, e.g. "安装 Minecraft 1.21.1".
  final String title;
  String stage = '准备';
  String detail = '';
  double fraction = 0;
  bool running = true;
  bool success = true;
  String? error;

  void update({String? stage, String? detail, double? fraction}) {
    if (stage != null) this.stage = stage;
    if (detail != null) this.detail = detail;
    if (fraction != null) this.fraction = fraction.clamp(0, 1);
    notifyListeners();
  }
}
