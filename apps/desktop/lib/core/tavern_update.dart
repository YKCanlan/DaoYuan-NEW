/// 官方 SillyTavern release 的检查与更新。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'host_process.dart';
import 'paths.dart';

/// 更新脚本返回的阶段。
enum TavernUpdatePhase { upToDate, available, updated, unavailable, failed }

/// 一次检查或更新的结果。
class TavernUpdateReport {
  const TavernUpdateReport({
    required this.phase,
    this.version = '',
    this.branch = '',
    this.localSha = '',
    this.remoteSha = '',
    this.shallow = false,
    this.message = '',
  });

  final TavernUpdatePhase phase;
  final String version;
  final String branch;
  final String localSha;
  final String remoteSha;
  final bool shallow;
  final String message;

  String get localShort => _short(localSha);
  String get remoteShort => _short(remoteSha);

  bool get behind => phase == TavernUpdatePhase.available;

  static String _short(String sha) {
    if (sha.length <= 7) return sha;
    return sha.substring(0, 7);
  }

  factory TavernUpdateReport.unavailable(String message) {
    return TavernUpdateReport(
      phase: TavernUpdatePhase.unavailable,
      message: message,
    );
  }

  factory TavernUpdateReport.failed(String message) {
    return TavernUpdateReport(
      phase: TavernUpdatePhase.failed,
      message: message,
    );
  }
}

const _jsonMarker = 'DAOYUAN_UPDATE_JSON ';

/// 从脚本 stdout 取出最后一条结构化结果。
TavernUpdateReport parseTavernUpdateOutput(String stdout) {
  String? payload;
  for (final raw in stdout.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.startsWith(_jsonMarker)) {
      payload = line.substring(_jsonMarker.length);
    }
  }
  if (payload == null || payload.isEmpty) {
    return TavernUpdateReport.unavailable('更新脚本没有返回结果。');
  }
  try {
    final json = jsonDecode(payload);
    if (json is! Map) {
      return TavernUpdateReport.unavailable('更新结果不是对象。');
    }
    return TavernUpdateReport(
      phase: _phase(json['phase'] as String? ?? ''),
      version: json['version'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      localSha: json['localSha'] as String? ?? '',
      remoteSha: json['remoteSha'] as String? ?? '',
      shallow: json['shallow'] == true,
      message: json['message'] as String? ?? '',
    );
  } catch (error) {
    return TavernUpdateReport.unavailable('无法解析更新结果：$error');
  }
}

TavernUpdatePhase _phase(String raw) {
  switch (raw) {
    case 'up-to-date':
      return TavernUpdatePhase.upToDate;
    case 'available':
      return TavernUpdatePhase.available;
    case 'updated':
      return TavernUpdatePhase.updated;
    case 'failed':
      return TavernUpdatePhase.failed;
    default:
      return TavernUpdatePhase.unavailable;
  }
}

/// 调用 `scripts/update-tavern.mjs`。
class TavernUpdater {
  const TavernUpdater();

  Future<TavernUpdateReport> check() {
    return _run('check', const Duration(seconds: 90));
  }

  Future<TavernUpdateReport> apply() {
    return _run('apply', const Duration(minutes: 20));
  }

  Future<TavernUpdateReport> _run(String mode, Duration timeout) async {
    final node = resolveNodeBinary();
    final script = resolveUpdateScript();
    final tavern = resolveSillyTavernRoot();
    final runtime = resolveRuntimeDir();
    if (node == null) {
      return TavernUpdateReport.unavailable('未找到 Node.js，无法检查酒馆更新。');
    }
    if (script == null) {
      return TavernUpdateReport.unavailable('未找到 scripts/update-tavern.mjs。');
    }
    if (tavern == null) {
      return TavernUpdateReport.unavailable('未找到酒馆内核。');
    }
    final process = await Process.start(
      node.path,
      [
        script.path,
        '--mode',
        mode,
        '--tavern',
        tavern.path,
        '--runtime',
        runtime.path,
        '--node',
        node.path,
      ],
      environment: {
        ...Platform.environment,
        'DAOYUAN_RUNTIME_ROOT': runtime.path,
        'DAOYUAN_SILLYTAVERN_ROOT': tavern.path,
      },
    );
    trackNode(process.pid);
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone =
        process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write).asFuture<void>();
    final stderrDone =
        process.stderr.transform(utf8.decoder).listen(stderrBuffer.write).asFuture<void>();
    try {
      final code = await process.exitCode.timeout(timeout);
      await stdoutDone;
      await stderrDone;
      final report = parseTavernUpdateOutput(
        '${stdoutBuffer.toString()}\n${stderrBuffer.toString()}',
      );
      if (code != 0 &&
          report.phase != TavernUpdatePhase.failed &&
          report.message.isEmpty) {
        return TavernUpdateReport.failed('更新脚本退出码 $code');
      }
      return report;
    } on TimeoutException {
      killTreeSync(process.pid);
      final fallback = mode == 'apply'
          ? TavernUpdateReport.failed
          : TavernUpdateReport.unavailable;
      return fallback('更新脚本超时。');
    } on Exception catch (error) {
      killTreeSync(process.pid);
      final fallback = mode == 'apply'
          ? TavernUpdateReport.failed
          : TavernUpdateReport.unavailable;
      return fallback('$error');
    } finally {
      untrackNode(process.pid);
    }
  }
}
