/// 回收本安装拉起的 Node。不碰命令行里没有这些路径的其它 Node。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'paths.dart';

final Set<int> _trackedNodePids = <int>{};

void trackNode(int pid) {
  if (pid > 0) _trackedNodePids.add(pid);
}

void untrackNode(int pid) {
  _trackedNodePids.remove(pid);
}

void killTreeSync(int pid) {
  if (pid <= 0) return;
  if (!Platform.isWindows) {
    try {
      Process.killPid(pid);
    } catch (_) {}
    return;
  }
  try {
    Process.runSync(
      'taskkill',
      ['/PID', '$pid', '/T', '/F'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } catch (_) {}
}

void killTrackedNodes() {
  final pids = _trackedNodePids.toList();
  _trackedNodePids.clear();
  for (final pid in pids) {
    killTreeSync(pid);
  }
}

List<String> installNodeMarkers() {
  final runtime = resolveRuntimeDir();
  final markers = <String>[
    p.join(runtime.path, 'config.yaml'),
    p.join(runtime.path, 'data'),
  ];
  for (final file in [
    resolveStartScript(),
    resolveUpdateScript(),
    resolveSyncScript(),
  ]) {
    if (file != null) markers.add(file.path);
  }
  final start = resolveStartScript();
  if (start != null) {
    markers.add(p.join(start.parent.path, 'windows-safe-cp.cjs'));
    markers.add(p.join(start.parent.path, 'url-suffix.cjs'));
  }
  return markers;
}

String _norm(String value) => value.replaceAll('/', '\\').toLowerCase();

bool commandMatchesInstall(String commandLine, List<String> markers) {
  final cmd = _norm(commandLine);
  if (cmd.isEmpty) return false;
  for (final marker in markers) {
    final needle = _norm(marker);
    if (needle.isNotEmpty && cmd.contains(needle)) return true;
  }
  return false;
}

/// 杀掉命令行指向本次安装的 node.exe。同步执行，关窗口时不能等异步。
void reapInstallNodesSync() {
  if (!Platform.isWindows) return;
  final markers = installNodeMarkers();
  if (markers.isEmpty) return;
  final out = File(
    p.join(
      Directory.systemTemp.path,
      'daoyuan_reap_${pid}_${DateTime.now().microsecondsSinceEpoch}.json',
    ),
  );
  final script = File('${out.path}.ps1');
  try {
    final scriptText = '''
\$ErrorActionPreference = 'SilentlyContinue'
\$rows = @()
Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" | ForEach-Object {
  \$rows += [PSCustomObject]@{ pid = [int]\$_.ProcessId; cmd = [string]\$_.CommandLine }
}
\$rows | ConvertTo-Json -Compress | Out-File -FilePath '${out.path.replaceAll("'", "''")}' -Encoding utf8
''';
    script.writeAsBytesSync(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(scriptText)]);
    Process.runSync(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script.path],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (!out.existsSync()) return;
    var text = out.readAsStringSync();
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.trim();
    if (text.isEmpty || text == 'null') return;
    final decoded = jsonDecode(text);
    final rows = decoded is List ? decoded : [decoded];
    for (final row in rows) {
      if (row is! Map) continue;
      final processId = (row['pid'] as num?)?.toInt() ?? 0;
      final cmd = row['cmd'] as String? ?? '';
      if (processId > 0 && commandMatchesInstall(cmd, markers)) {
        killTreeSync(processId);
      }
    }
  } catch (_) {
  } finally {
    try {
      if (out.existsSync()) out.deleteSync();
    } catch (_) {}
    try {
      if (script.existsSync()) script.deleteSync();
    } catch (_) {}
  }
}
