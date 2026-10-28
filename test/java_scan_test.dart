import 'package:flutter_test/flutter_test.dart';
import 'package:hydrogen_chloride_launcher/core/models/java_runtime.dart';
import 'package:hydrogen_chloride_launcher/core/services/java_scanner.dart';

void main() {
  test('parses Java 8 output', () {
    final JavaRuntime? runtime = JavaScanner.parseVersionOutput(
      'java version "1.8.0_391"\nJava(TM) SE Runtime Environment',
      path: '/opt/java8/bin/java',
    );
    expect(runtime, isNotNull);
    expect(runtime!.version, '1.8.0_391');
    expect(runtime.major, 8);
    expect(runtime.vendor, 'Oracle');
    expect(runtime.arch, 'x64');
  });

  test('parses Temurin Java 17 output', () {
    final JavaRuntime? runtime = JavaScanner.parseVersionOutput(
      'openjdk version "17.0.11" 2024-04-16\n'
      'OpenJDK Runtime Environment Temurin-17.0.11+9 (build 17.0.11+9)',
      path: '/usr/lib/jvm/temurin-17/bin/java',
    );
    expect(runtime, isNotNull);
    expect(runtime!.version, '17.0.11');
    expect(runtime.major, 17);
    expect(runtime.vendor, 'Eclipse Temurin');
  });

  test('parses Java 21 output and 32-bit arch', () {
    final JavaRuntime? runtime = JavaScanner.parseVersionOutput(
      'openjdk version "21.0.3" 2024-04-16\nOpenJDK 32-Bit Server VM',
      path: 'C:\\Java\\bin\\java.exe',
    );
    expect(runtime, isNotNull);
    expect(runtime!.major, 21);
    expect(runtime.arch, 'x86');
    expect(runtime.vendor, 'OpenJDK');
  });

  test('rejects output without a version', () {
    expect(
      JavaScanner.parseVersionOutput('not a java runtime', path: '/tmp/java'),
      isNull,
    );
  });

  test('JavaRuntime JSON infers major version', () {
    final JavaRuntime runtime = JavaRuntime.fromJson(<String, dynamic>{
      'path': '/usr/bin/java',
      'version': '1.8.0_402',
      'vendor': 'OpenJDK',
      'arch': 'x64',
      'source': 'PATH',
    });
    expect(runtime.major, 8);
    expect(runtime.home, '/usr');
    expect(runtime.label, 'Java 8 · OpenJDK');
  });
}
