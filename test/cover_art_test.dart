import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/config/app_paths.dart';
import 'package:hydrogen_chloride_launcher/core/services/cover_art_service.dart';

void main() {
  test('cover art caches the official key art', () async {
    final Directory root = Directory.systemTemp.createTempSync('hcl-cover-');
    addTearDown(() => root.deleteSync(recursive: true));
    final AppPaths paths = AppPaths.forTesting(root);
    await paths.ensure();
    final CoverArtService service = CoverArtService(paths: paths);
    expect(service.cachedPath, isNull);
    final String path = await service.ensure();
    expect(File(path).existsSync(), isTrue);
    expect(File(path).lengthSync(), greaterThan(10000));
    expect(service.cachedPath, path);
  }, skip: Platform.environment['HCL_LIVE'] != '1');
}
