/// 调用 `scripts/sync-remote-tavern.mjs`，把网页端酒馆配置写入 runtime/data。
library;

import 'dart:convert';
import 'dart:io';

import 'host_process.dart';
import 'paths.dart';

const syncJsonMarker = 'DAOYUAN_SYNC_JSON ';

/// 一次测试连接或同步的结果。
class RemoteSyncReport {
  const RemoteSyncReport({
    required this.ok,
    this.remoteVersion = '',
    this.settings = false,
    this.presets = 0,
    this.worldInfo = 0,
    this.characters = 0,
    this.extensions = 0,
    this.extensionsSkipped = 0,
    this.errors = const [],
    this.backup = '',
    this.user = '',
    this.message = '',
  });

  final bool ok;
  final String remoteVersion;
  final bool settings;
  final int presets;
  final int worldInfo;
  final int characters;
  final int extensions;
  final int extensionsSkipped;
  final List<String> errors;
  final String backup;
  final String user;
  final String message;

  bool get wroteAnything =>
      settings || presets > 0 || worldInfo > 0 || characters > 0 || extensions > 0;

  String get summary {
    final skipped = extensionsSkipped > 0 ? '（另有 $extensionsSkipped 个插件本地已有，未覆盖）' : '';
    return '设置 ${settings ? 1 : 0} 份、预设 $presets 份、世界书 $worldInfo 份、角色卡 $characters 张、插件 $extensions 个$skipped';
  }

  factory RemoteSyncReport.failed(String message) {
    return RemoteSyncReport(ok: false, message: message, errors: [message]);
  }

  String describe(String mode) {
    final detail = errors.isNotEmpty ? errors.join('；') : message;
    if (wroteAnything && mode == 'sync') {
      final head = '已写入用户 ${user.isEmpty ? 'default-user' : user}：$summary。';
      if (errors.isEmpty) return head;
      return '$head部分失败：$detail';
    }
    if (!ok) return '同步失败：${detail.isEmpty ? '未知错误' : detail}';
    if (mode == 'check') {
      final version = remoteVersion.isEmpty ? '版本未知' : remoteVersion;
      return '连接成功：网页端 settings 可读取（$version）。';
    }
    return '同步完成：$summary。';
  }
}

/// 从脚本 stdout 取出最后一条结构化结果。
RemoteSyncReport parseRemoteSyncOutput(String stdout) {
  String? payload;
  for (final raw in stdout.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.startsWith(syncJsonMarker)) {
      payload = line.substring(syncJsonMarker.length);
    }
  }
  if (payload == null || payload.isEmpty) {
    return RemoteSyncReport.failed('同步脚本没有返回结果。');
  }
  try {
    final json = jsonDecode(payload);
    if (json is! Map) return RemoteSyncReport.failed('同步结果不是对象。');
    final synced = json['synced'];
    final rawErrors = json['errors'];
    final errors = rawErrors is List
        ? rawErrors.map((item) => '$item').where((item) => item.isNotEmpty).toList()
        : <String>[];
    final fallback = json['error'] as String? ?? '';
    return RemoteSyncReport(
      ok: json['ok'] == true,
      remoteVersion: json['remoteVersion'] as String? ?? '',
      settings: synced is Map && synced['settings'] == true,
      presets: synced is Map ? _count(synced['presets']) : 0,
      worldInfo: synced is Map ? _count(synced['worldInfo']) : 0,
      characters: synced is Map ? _count(synced['characters']) : 0,
      extensions: synced is Map ? _count(synced['extensions']) : 0,
      extensionsSkipped: synced is Map ? _count(synced['extensionsSkipped']) : 0,
      errors: errors.isEmpty && fallback.isNotEmpty ? [fallback] : errors,
      backup: json['backup'] as String? ?? '',
      user: json['user'] as String? ?? '',
      message: fallback,
    );
  } catch (error) {
    return RemoteSyncReport.failed('无法解析同步结果：$error');
  }
}

int _count(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

/// 网页端酒馆同步。聊天记录和密钥文件不在范围内。
class RemoteTavernSync {
  const RemoteTavernSync();

  Future<RemoteSyncReport> check({
    required String remoteUrl,
    required String token,
    required String username,
    required String password,
  }) {
    return _run(
      mode: 'check',
      remoteUrl: remoteUrl,
      token: token,
      username: username,
      password: password,
      timeout: const Duration(seconds: 40),
    );
  }

  Future<RemoteSyncReport> sync({
    required String remoteUrl,
    required String token,
    required String username,
    required String password,
  }) {
    return _run(
      mode: 'sync',
      remoteUrl: remoteUrl,
      token: token,
      username: username,
      password: password,
      timeout: const Duration(minutes: 12),
    );
  }

  Future<RemoteSyncReport> _run({
    required String mode,
    required String remoteUrl,
    required String token,
    required String username,
    required String password,
    required Duration timeout,
  }) async {
    final node = resolveNodeBinary();
    final script = resolveSyncScript();
    final runtime = resolveRuntimeDir();
    if (node == null) return RemoteSyncReport.failed('未找到 Node.js，无法同步网页端酒馆。');
    if (script == null) return RemoteSyncReport.failed('未找到 scripts/sync-remote-tavern.mjs。');
    final process = await Process.start(
      node.path,
      [script.path],
      workingDirectory: script.parent.path,
      environment: {
        ...Platform.environment,
        'DAOYUAN_RUNTIME_ROOT': runtime.path,
      },
    );
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write).asFuture<void>();
    final stderrDone = process.stderr.transform(utf8.decoder).listen(stderrBuffer.write).asFuture<void>();
    trackNode(process.pid);
    process.stdin.write(jsonEncode({
      'mode': mode,
      'runtime': runtime.path,
      'remoteUrl': remoteUrl,
      'token': token,
      'username': username,
      'password': password,
    }));
    await process.stdin.close();
    try {
      await process.exitCode.timeout(timeout);
      await stdoutDone;
      await stderrDone;
    } on Exception {
      killTreeSync(process.pid);
      return RemoteSyncReport.failed(mode == 'check' ? '测试连接超时。' : '同步超时。');
    } finally {
      untrackNode(process.pid);
    }
    final report = parseRemoteSyncOutput('${stdoutBuffer.toString()}\n${stderrBuffer.toString()}');
    if (!report.ok && report.message.isEmpty && report.errors.isEmpty) {
      return RemoteSyncReport.failed('同步脚本没有返回结果。');
    }
    return report;
  }
}
