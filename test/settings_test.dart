import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/models/app_settings.dart';

void main() {
  test('settings round-trip through JSON', () {
    final AppSettings settings = AppSettings.defaults(minecraftDir: '/tmp/mc')
      ..themeMode = AppThemeMode.dark
      ..accentColorValue = 0xFF112233
      ..backgroundImagePath = '/tmp/bg.png'
      ..backgroundOpacity = 0.42
      ..backgroundBlur = false
      ..backgroundBlurMode = BackgroundBlurMode.gaussian
      ..backgroundBlurSigma = 12
      ..demoData = false
      ..microsoftClientId = 'client-id'
      ..defaultJavaPath = '/usr/bin/java'
      ..defaultMemoryMb = 8192
      ..defaultJvmArgs = '-Xmx8G'
      ..minecraftDirs = <String>['/tmp/mc'];

    final AppSettings decoded = AppSettings.fromJson(settings.toJson());

    expect(decoded.themeMode, AppThemeMode.dark);
    expect(decoded.accentColorValue, 0xFF112233);
    expect(decoded.backgroundImagePath, '/tmp/bg.png');
    expect(decoded.backgroundOpacity, 0.42);
    expect(decoded.backgroundBlur, isFalse);
    expect(decoded.backgroundBlurMode, BackgroundBlurMode.gaussian);
    expect(decoded.backgroundBlurSigma, 12);
    expect(decoded.demoData, isFalse);
    expect(decoded.microsoftClientId, 'client-id');
    expect(decoded.defaultJavaPath, '/usr/bin/java');
    expect(decoded.defaultMemoryMb, 8192);
    expect(decoded.defaultJvmArgs, '-Xmx8G');
    expect(decoded.minecraftDirs, <String>['/tmp/mc']);
  });

  test('invalid numbers are clamped', () {
    final AppSettings decoded = AppSettings.fromJson(<String, dynamic>{
      'backgroundOpacity': 4.2,
      'backgroundBlurSigma': 999,
      'defaultMemoryMb': 1,
    });

    expect(decoded.backgroundOpacity, 1);
    expect(decoded.backgroundBlurSigma, 80);
    expect(decoded.defaultMemoryMb, 1024);
  });

  test('copyWith can clear nullable values', () {
    final AppSettings settings = AppSettings.defaults()
      ..backgroundImagePath = '/tmp/a.png'
      ..defaultJavaPath = '/usr/bin/java';

    final AppSettings cleared = settings.copyWith(
      backgroundImagePath: null,
      defaultJavaPath: null,
    );

    expect(cleared.backgroundImagePath, isNull);
    expect(cleared.defaultJavaPath, isNull);
    expect(settings.backgroundImagePath, '/tmp/a.png');
  });
}
