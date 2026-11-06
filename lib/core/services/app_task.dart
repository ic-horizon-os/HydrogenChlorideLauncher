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
    final String nextStage = stage ?? this.stage;
    final String nextDetail = detail ?? this.detail;
    final double raw = (fraction ?? this.fraction).clamp(0.0, 1.0);
    // A task's stages are monotonic; a coarse stage report following
    // fine-grained ones must never drag the bar backwards.
    final double monotonic = raw > this.fraction ? raw : this.fraction;
    // Quantize to 0.5% steps: chunk-sized deltas would rebuild the shell
    // several times per second for an invisible change.
    final double stepped = (monotonic * 200).floorToDouble() / 200;
    if (stepped == this.fraction &&
        nextStage == this.stage &&
        nextDetail == this.detail) {
      return;
    }
    this.stage = nextStage;
    this.detail = nextDetail;
    this.fraction = stepped;
    notifyListeners();
  }
}
