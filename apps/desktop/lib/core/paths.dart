/// 运行时与酒馆资源路径解析。
///
/// 对应旧 PC 微端：每个客户端目录旁有独立 `runtime/`，
/// 不把用户数据写进源码树，也不跨版本混用。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// 仓库根：含 `package.json` 与 `apps/desktop`。
Directory? findProjectRoot([Directory? start]) {
  var dir = start ?? Directory.current;
  for (var i = 0; i < 10; i++) {
    final marker = File(p.join(dir.path, 'package.json'));
    final desktop = Directory(p.join(dir.path, 'apps', 'desktop'));
    if (marker.existsSync() && desktop.existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

/// 当前可执行文件所在目录。
Directory exeDir() => File(Platform.resolvedExecutable).parent;

/// 便携布局：exe 旁同时有 `resources/sillytavern/server.js` 或 `scripts/start-tavern.mjs`。
bool isPortableBundle([Directory? dir]) {
  final root = dir ?? exeDir();
  return File(p.join(root.path, 'resources', 'sillytavern', 'server.js'))
          .existsSync() ||
      File(p.join(root.path, 'scripts', 'start-tavern.mjs')).existsSync();
}

/// 运行时目录优先级：
/// `DAOYUAN_RUNTIME_ROOT` → 便携 `exe/runtime/` → 项目根 `runtime/` → `%LOCALAPPDATA%\DaoYuan\runtime`。
Directory resolveRuntimeDir() {
  final env = Platform.environment['DAOYUAN_RUNTIME_ROOT'];
  if (env != null && env.trim().isNotEmpty) {
    return Directory(env.trim());
  }
  final exe = exeDir();
  if (isPortableBundle(exe)) {
    return Directory(p.join(exe.path, 'runtime'));
  }
  final project = findProjectRoot();
  if (project != null) {
    return Directory(p.join(project.path, 'runtime'));
  }
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null && local.isNotEmpty) {
    return Directory(p.join(local, 'DaoYuan', 'runtime'));
  }
  return Directory(p.join(exe.path, 'runtime'));
}

/// SillyTavern 源码根（含 `server.js`）。
Directory? resolveSillyTavernRoot() {
  final env = Platform.environment['DAOYUAN_SILLYTAVERN_ROOT'];
  if (env != null && env.trim().isNotEmpty) {
    final dir = Directory(env.trim());
    if (File(p.join(dir.path, 'server.js')).existsSync()) return dir;
  }
  final exe = exeDir();
  final portable = Directory(p.join(exe.path, 'resources', 'sillytavern'));
  if (File(p.join(portable.path, 'server.js')).existsSync()) return portable;
  final project = findProjectRoot();
  if (project != null) {
    final bundled =
        Directory(p.join(project.path, 'resources', 'sillytavern'));
    if (File(p.join(bundled.path, 'server.js')).existsSync()) return bundled;
  }
  return null;
}

/// 启动脚本 `scripts/start-tavern.mjs`。
File? resolveStartScript() {
  final exe = exeDir();
  final portable = File(p.join(exe.path, 'scripts', 'start-tavern.mjs'));
  if (portable.existsSync()) return portable;
  final project = findProjectRoot();
  if (project != null) {
    final file = File(p.join(project.path, 'scripts', 'start-tavern.mjs'));
    if (file.existsSync()) return file;
  }
  return null;
}

/// 网页端酒馆同步脚本 `scripts/sync-remote-tavern.mjs`。
File? resolveSyncScript() {
  final exe = exeDir();
  final portable = File(p.join(exe.path, 'scripts', 'sync-remote-tavern.mjs'));
  if (portable.existsSync()) return portable;
  final project = findProjectRoot();
  if (project != null) {
    final file = File(p.join(project.path, 'scripts', 'sync-remote-tavern.mjs'));
    if (file.existsSync()) return file;
  }
  return null;
}

/// 内核更新脚本 `scripts/update-tavern.mjs`。
File? resolveUpdateScript() {
  final exe = exeDir();
  final portable = File(p.join(exe.path, 'scripts', 'update-tavern.mjs'));
  if (portable.existsSync()) return portable;
  final project = findProjectRoot();
  if (project != null) {
    final file = File(p.join(project.path, 'scripts', 'update-tavern.mjs'));
    if (file.existsSync()) return file;
  }
  return null;
}

/// Node 可执行文件。
File? resolveNodeBinary() {
  final env = Platform.environment['DAOYUAN_NODE_BIN'] ??
      Platform.environment['NODE_BINARY'];
  if (env != null && env.trim().isNotEmpty) {
    final file = File(env.trim());
    if (file.existsSync()) return file;
  }
  final exe = exeDir();
  final bundled = File(p.join(exe.path, 'resources', 'node', 'node.exe'));
  if (bundled.existsSync()) return bundled;
  final project = findProjectRoot();
  if (project != null) {
    final file =
        File(p.join(project.path, 'resources', 'node', 'node.exe'));
    if (file.existsSync()) return file;
  }
  final fromPath = _which('node') ?? _which('node.exe');
  if (fromPath != null) return fromPath;
  return null;
}

File? _which(String name) {
  final pathEnv = Platform.environment['PATH'] ?? '';
  final sep = Platform.isWindows ? ';' : ':';
  for (final dir in pathEnv.split(sep)) {
    if (dir.trim().isEmpty) continue;
    final file = File(p.join(dir, name));
    if (file.existsSync()) return file;
  }
  return null;
}

/// 握手文件 `runtime/host.json`。
File hostHandshakeFile([Directory? runtime]) {
  return File(p.join((runtime ?? resolveRuntimeDir()).path, 'host.json'));
}
