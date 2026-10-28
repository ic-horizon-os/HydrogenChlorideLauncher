import 'dart:io';

import 'package:path/path.dart' as p;

/// A single crash rule: any of [needles] appearing in a log (case-insensitive)
/// reports [title] with [suggestion].
class CrashRule {
  const CrashRule({
    required this.id,
    required this.title,
    required this.suggestion,
    required this.needles,
    this.severity = CrashSeverity.error,
  });

  final String id;
  final String title;
  final String suggestion;
  final List<String> needles;
  final CrashSeverity severity;

  bool matches(String lowerLog) => needles.any(lowerLog.contains);
}

enum CrashSeverity { error, warning, info }

/// Structured rules for 崩溃分析. The built-in set covers what users hit most;
/// plugin rules can be appended later through [CrashAnalyzer.withExtraRules].
class CrashAnalyzer {
  CrashAnalyzer({List<CrashRule>? rules})
    : rules = <CrashRule>[...defaultRules, ...?rules];

  final List<CrashRule> rules;

  static const List<CrashRule> defaultRules = <CrashRule>[
    CrashRule(
      id: 'java-version',
      title: 'Java 版本过低',
      suggestion: '换用 Java 17 或 21，并在条目的 Java 设置中指定。',
      needles: <String>['unsupportedclassversionerror', 'requires java'],
    ),
    CrashRule(
      id: 'out-of-memory',
      title: '内存不足',
      suggestion: '提高最大内存，或减少模组数量。',
      needles: <String>['outofmemoryerror', 'java heap space'],
    ),
    CrashRule(
      id: 'duplicate-mod',
      title: '模组重复',
      suggestion: '检查 mods 目录中是否有同一模组的多个版本。',
      needles: <String>[
        'duplicate mod',
        'duplicate mods found',
        'found duplicate mods',
      ],
    ),
    CrashRule(
      id: 'missing-dependency',
      title: '缺少前置模组',
      suggestion: '根据日志补装对应的前置模组。',
      needles: <String>[
        'missing or unsupported mandatory dependencies',
        'requires any version of',
        'mod requires',
      ],
    ),
    CrashRule(
      id: 'mod-mismatch',
      title: '模组版本不匹配',
      suggestion: '确认模组支持当前游戏与加载器版本。',
      needles: <String>[
        'nosuchmethoderror',
        'incompatible mod set',
        'mixin apply failed',
        'mixin transformer error',
      ],
    ),
    CrashRule(
      id: 'main-class',
      title: '启动参数或版本文件异常',
      suggestion: '检查版本 JSON 与启动参数，必要时重新安装版本。',
      needles: <String>[
        'could not find or load main class',
        'noclassdeffounderror',
        'classnotfoundexception',
      ],
    ),
    CrashRule(
      id: 'graphics',
      title: '图形驱动问题',
      suggestion: '更新显卡驱动，或尝试切换 OpenGL 渲染。',
      needles: <String>[
        'glfw error',
        'opengl 3.2',
        'exception_in_thread "main" java.lang.illegalstateexception: glfw',
        'pixel format not accelerated',
      ],
    ),
    CrashRule(
      id: 'access-denied',
      title: '文件权限问题',
      suggestion: '检查游戏目录的读写权限，或换一个可写的 .minecraft 目录。',
      needles: <String>[
        'java.nio.file.accessdeniedexception',
        'permission denied',
      ],
    ),
    CrashRule(
      id: 'world-corrupt',
      title: '存档损坏',
      suggestion: '在世界页用「修复」检查存档，必要时从 backups 还原。',
      needles: <String>[
        'corrupted chunk',
        'unknown level version',
        'level.dat',
      ],
    ),
    CrashRule(
      id: 'loader-mismatch',
      title: '加载器版本不匹配',
      suggestion: 'Forge/NeoForge 安装不完整，重新安装对应加载器。',
      needles: <String>[
        'forge mod loader has failed to load',
        'loading errors encountered',
        'neoforge mod loading',
      ],
      severity: CrashSeverity.warning,
    ),
  ];

  /// Analyzes a merged log corpus. Each rule reports at most once.
  List<CrashFinding> analyze(String log) {
    final String lower = log.toLowerCase();
    final List<CrashFinding> findings = <CrashFinding>[];
    for (final CrashRule rule in rules) {
      if (rule.matches(lower)) {
        findings.add(
          CrashFinding(
            title: rule.title,
            suggestion: rule.suggestion,
            ruleId: rule.id,
            severity: rule.severity,
          ),
        );
      }
    }
    return findings;
  }

  /// Collects `logs/latest.log`, the newest `crash-reports/*.txt`, and the
  /// launcher's own `logs/hcl-launch-*.log` files.
  static Future<CrashSource> collect(String gameDirectory) async {
    final StringBuffer buffer = StringBuffer();
    String? primary;
    final File latest = File(p.join(gameDirectory, 'logs', 'latest.log'));
    if (await latest.exists()) {
      primary = latest.path;
      buffer.writeln(await _tail(latest));
    }
    final Directory crashes = Directory(p.join(gameDirectory, 'crash-reports'));
    if (await crashes.exists()) {
      final List<File> files =
          crashes
              .listSync()
              .whereType<File>()
              .where((File file) => file.path.endsWith('.txt'))
              .toList()
            ..sort((File a, File b) {
              return b.statSync().modified.compareTo(a.statSync().modified);
            });
      if (files.isNotEmpty) {
        primary ??= files.first.path;
        buffer.writeln(await _tail(files.first));
      }
    }
    final Directory logs = Directory(p.join(gameDirectory, 'logs'));
    if (await logs.exists()) {
      final List<File> launcherLogs =
          logs
              .listSync()
              .whereType<File>()
              .where(
                (File file) =>
                    p.basename(file.path).startsWith('hcl-launch-') &&
                    file.path.endsWith('.log'),
              )
              .toList()
            ..sort((File a, File b) {
              return b.statSync().modified.compareTo(a.statSync().modified);
            });
      if (launcherLogs.isNotEmpty) {
        primary ??= launcherLogs.first.path;
        buffer.writeln(await _tail(launcherLogs.first));
      }
    }
    return CrashSource(primaryPath: primary, content: buffer.toString());
  }

  static Future<String> _tail(File file) async {
    try {
      final String text = await file.readAsString();
      const int max = 24000;
      return text.length <= max ? text : text.substring(text.length - max);
    } on FileSystemException {
      return '';
    }
  }
}

class CrashFinding {
  const CrashFinding({
    required this.title,
    required this.suggestion,
    required this.ruleId,
    this.severity = CrashSeverity.error,
  });

  final String title;
  final String suggestion;
  final String ruleId;
  final CrashSeverity severity;
}

class CrashSource {
  const CrashSource({required this.primaryPath, required this.content});

  final String? primaryPath;
  final String content;

  bool get isEmpty => content.trim().isEmpty;
}
