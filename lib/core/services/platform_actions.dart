import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class PlatformActions {
  PlatformActions._();

  static Future<bool> openExternal(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  static Future<bool> openDirectory(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer', <String>[path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', <String>[path]);
      } else {
        await Process.start('xdg-open', <String>[path]);
      }
      return true;
    } on ProcessException {
      return false;
    }
  }
}
