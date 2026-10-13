/// 拉起原生 SillyTavern（Node `server.js`），对应旧 PC 微端的宿主启动器。
///
/// Flutter 不实现提示词 / 世界书 / MVU。生成权威永远在酒馆运行时。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'host_process.dart';
import 'paths.dart';
import 'tavern_address.dart';

/// 握手文件内容。
class HostHandshake {
  const HostHandshake({
    required this.pid,
    required this.port,
    required this.url,
    this.wrapperPid = 0,
    this.urlSuffix = '',
    this.dataRoot = '',
  });

  final int pid;
  final int port;
  final String url;
  final int wrapperPid;
  final String urlSuffix;
  final String dataRoot;

  Uri get baseUri => Uri.parse(url);

  /// 健康检查走带后缀的地址，避免 `replace(path:)` 把后缀丢掉。
  Uri probeUri(String path) {
    final base = baseUri;
    final slashed = base.path.endsWith('/')
        ? base
        : base.replace(path: '${base.path}/');
    return slashed.resolve(path);
  }

  Map<String, dynamic> toJson() => {
        'pid': pid,
        'wrapperPid': wrapperPid,
        'port': port,
        'url': url,
        'urlSuffix': urlSuffix,
        'dataRoot': dataRoot,
      };

  static HostHandshake? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final port = (json['port'] as num?)?.toInt() ?? 0;
    final pid = (json['pid'] as num?)?.toInt() ?? 0;
    final wrapperPid = (json['wrapperPid'] as num?)?.toInt() ?? 0;
    var url = json['url'] as String? ?? '';
    if (url.isEmpty && port > 0) {
      url = 'http://127.0.0.1:$port/';
    }
    if (port <= 0 || url.isEmpty) return null;
    final stored = json['urlSuffix'] as String?;
    final suffix = stored == null
        ? _suffixFromUrl(url)
        : (normalizeTavernSuffix(stored) ?? '');
    final normalized = url.endsWith('/') ? url : '$url/';
    return HostHandshake(
      pid: pid,
      wrapperPid: wrapperPid,
      port: port,
      url: normalized,
      urlSuffix: suffix,
      dataRoot: json['dataRoot'] as String? ?? '',
    );
  }

  static String _suffixFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.length != 1) return '';
    return normalizeTavernSuffix(parts.single) ?? '';
  }
}

/// 启动结果。
class HostBootResult {
  const HostBootResult({required this.handshake, required this.process});

  final HostHandshake handshake;
  final Process? process;
}

/// 发现或拉起 SillyTavern。
class StLauncher {
  StLauncher({this.timeout = const Duration(seconds: 180)});

  final Duration timeout;

  /// 读握手文件。
  static HostHandshake? discover({Directory? runtimeDir}) {
    final file = hostHandshakeFile(runtimeDir ?? resolveRuntimeDir());
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is Map<String, dynamic>) {
        return HostHandshake.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  /// 若已在听且端口、后缀一致则复用，否则拉起 `scripts/start-tavern.mjs`。
  Future<HostBootResult> ensureRunning({
    int port = kDefaultTavernPort,
    String urlSuffix = '',
  }) async {
    final suffix = normalizeTavernSuffix(urlSuffix) ?? '';
    final runtime = resolveRuntimeDir();
    runtime.createSync(recursive: true);

    final existing = discover(runtimeDir: runtime);
    if (existing != null &&
        existing.urlSuffix == suffix &&
        existing.port == port &&
        await isHealthy(existing)) {
      _log(runtime, 'reuse pid=${existing.pid} port=${existing.port}');
      return HostBootResult(handshake: existing, process: null);
    }

    final lockPid = _readLock(runtime);
    final starterAlive = lockPid > 0 && await _isLiveNode(lockPid);
    if (starterAlive &&
        (existing == null || existing.urlSuffix == suffix)) {
      _log(runtime, 'starter pid=$lockPid alive; wait');
      final handshake = await _waitHealthy(runtime);
      if (handshake.urlSuffix == suffix && handshake.port == port) {
        return HostBootResult(handshake: handshake, process: null);
      }
    }

    if (existing != null &&
        existing.urlSuffix == suffix &&
        existing.port == port &&
        existing.pid > 0 &&
        await _isLiveNode(existing.pid)) {
      _log(runtime, 'pid=${existing.pid} still alive; wait for health');
      final handshake = await _waitHealthy(runtime);
      return HostBootResult(handshake: handshake, process: null);
    }

    stopSync(existing);
    if (starterAlive) killTreeSync(lockPid);
    _deleteLock(runtime);

    final node = resolveNodeBinary();
    final script = resolveStartScript();
    final tavern = resolveSillyTavernRoot();
    if (node == null) {
      throw StateError(
        '未找到 Node.js。请安装 Node 20+，或把便携 node.exe 放到 resources/node/。',
      );
    }
    if (script == null) {
      throw StateError('未找到 scripts/start-tavern.mjs。');
    }
    if (tavern == null) {
      throw StateError(
        '未找到 SillyTavern（resources/sillytavern/server.js）。请先运行 npm run setup。',
      );
    }

    final args = <String>[
      script.path,
      '--port',
      '$port',
      '--runtime',
      runtime.path,
      '--tavern',
      tavern.path,
      '--parentPid',
      '${pidOfCurrentProcess()}',
      if (suffix.isNotEmpty) ...['--urlSuffix', suffix],
    ];
    _log(runtime, 'spawn ${node.path} ${args.join(' ')}');

    if (Platform.isWindows) {
      await _spawnWindowsOrphan(
        binary: node,
        args: args,
        workingDirectory: findProjectRoot()?.path ?? tavern.path,
        environment: _hostEnvironment({
          'DAOYUAN_RUNTIME_ROOT': runtime.path,
          'DAOYUAN_SILLYTAVERN_ROOT': tavern.path,
          if (suffix.isNotEmpty) 'DAOYUAN_URL_SUFFIX': suffix,
        }),
      );
    } else {
      await Process.start(
        node.path,
        args,
        mode: ProcessStartMode.detached,
        workingDirectory: findProjectRoot()?.path ?? tavern.path,
        environment: _hostEnvironment({
          'DAOYUAN_RUNTIME_ROOT': runtime.path,
          'DAOYUAN_SILLYTAVERN_ROOT': tavern.path,
          if (suffix.isNotEmpty) 'DAOYUAN_URL_SUFFIX': suffix,
        }),
      );
    }

    final handshake = await _waitHealthy(runtime);
    return HostBootResult(handshake: handshake, process: null);
  }

  Future<HostHandshake> _waitHealthy(Directory runtime) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final handshake = discover(runtimeDir: runtime);
      if (handshake != null && await isHealthy(handshake)) {
        _log(runtime, 'ready pid=${handshake.pid} port=${handshake.port}');
        return handshake;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw TimeoutException(
      'SillyTavern 在 ${timeout.inSeconds} 秒内未就绪。请查看 runtime/logs/tavern.log。',
      timeout,
    );
  }

  static Future<bool> isHealthy(HostHandshake handshake) async {
    try {
      final response = await http
          .get(handshake.probeUri('csrf-token'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      try {
        final response = await http
            .get(handshake.probeUri('version'))
            .timeout(const Duration(seconds: 2));
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  /// 退出时回收本次安装的 Node 进程树。没有握手文件也要扫更新/同步脚本。
  static void stopSync(HostHandshake? handshake) {
    if (handshake != null) {
      killTreeSync(handshake.wrapperPid);
      if (handshake.pid != handshake.wrapperPid) {
        killTreeSync(handshake.pid);
      }
    }
    killTrackedNodes();
    reapInstallNodesSync();
  }
}

int pidOfCurrentProcess() {
  try {
    return pid;
  } catch (_) {
    return 0;
  }
}

int _readLock(Directory runtime) {
  final file = File(p.join(runtime.path, 'host.lock'));
  if (!file.existsSync()) return 0;
  return int.tryParse(file.readAsStringSync().trim()) ?? 0;
}

void _deleteLock(Directory runtime) {
  final file = File(p.join(runtime.path, 'host.lock'));
  try {
    if (file.existsSync()) file.deleteSync();
  } catch (_) {}
}

const _hostEnvKeep = {
  'PATH',
  'PATHEXT',
  'SYSTEMROOT',
  'WINDIR',
  'TEMP',
  'TMP',
  'USERPROFILE',
  'APPDATA',
  'LOCALAPPDATA',
  'HOMEDRIVE',
  'HOMEPATH',
  'COMSPEC',
  'SYSTEMDRIVE',
  'NUMBER_OF_PROCESSORS',
  'PROCESSOR_ARCHITECTURE',
  'PROCESSOR_IDENTIFIER',
  'PROGRAMFILES',
  'PROGRAMFILES(X86)',
  'PROGRAMDATA',
  'PUBLIC',
  'DRIVERDATA',
  'OS',
  'USERNAME',
  'USERDOMAIN',
  'COMPUTERNAME',
  'LANG',
  'LC_ALL',
  'HTTP_PROXY',
  'HTTPS_PROXY',
  'NO_PROXY',
  'ALL_PROXY',
};

/// 不把 NODE_OPTIONS 等整份环境塞进孤儿进程，避免一个酒馆拉起一串额外 Node。
Map<String, String> _hostEnvironment(Map<String, String> extra) {
  final out = <String, String>{};
  for (final entry in Platform.environment.entries) {
    if (_hostEnvKeep.contains(entry.key.toUpperCase())) {
      out[entry.key] = entry.value;
    }
  }
  out.addAll(extra);
  out.remove('NODE_OPTIONS');
  out.remove('NODE_INSPECT');
  out.remove('NODE_DEBUG');
  return out;
}

Future<bool> _isLiveNode(int processId) async {
  if (processId <= 0 || !Platform.isWindows) return false;
  try {
    final result = Process.runSync(
      'tasklist',
      ['/FI', 'PID eq $processId', '/FO', 'CSV', '/NH'],
    );
    final out = result.stdout.toString().toLowerCase();
    return out.contains('node') || out.contains('sillytavern');
  } catch (_) {
    return false;
  }
}

void _log(Directory runtime, String message) {
  try {
    runtime.createSync(recursive: true);
    final file = File(p.join(runtime.path, 'logs', 'launcher.log'));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${DateTime.now().toIso8601String()} $message\n',
      mode: FileMode.append,
    );
  } catch (_) {}
}

String _vbsQuote(String value) => value.replaceAll('"', '""');

Future<File> _writeUtf16Lines(
  Directory dir,
  String name,
  Iterable<String> lines,
) async {
  final file = File(p.join(dir.path, name));
  final text =
      lines.map((line) => line.replaceAll(RegExp(r'[\r\n]'), '')).join('\r\n');
  final bytes = <int>[0xFF, 0xFE];
  for (final unit in text.codeUnits) {
    bytes.add(unit & 0xFF);
    bytes.add((unit >> 8) & 0xFF);
  }
  await file.writeAsBytes(bytes);
  return file;
}

/// WMI 孤儿进程：避免 Flutter 作业对象把 Node 一起杀掉。
Future<void> _spawnWindowsOrphan({
  required File binary,
  required List<String> args,
  required String workingDirectory,
  required Map<String, String> environment,
}) async {
  final cmdParts = [binary.path, ...args];
  final cmdLine =
      cmdParts.map((part) => part.contains(' ') ? '"$part"' : part).join(' ');
  final escapedCmdLine = _vbsQuote(cmdLine);
  final escapedCwd = _vbsQuote(workingDirectory);
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final tempDir = Directory.systemTemp;
  final envFile = await _writeUtf16Lines(
    tempDir,
    'daoyuan_env_$stamp.txt',
    environment.entries.map((entry) => '${entry.key}=${entry.value}'),
  );
  final escapedEnv = _vbsQuote(envFile.path);

  final vbsContent = '''
Set fso = CreateObject("Scripting.FileSystemObject")
Set startup = GetObject("winmgmts:\\\\.\\root\\cimv2:Win32_ProcessStartup").SpawnInstance_
startup.ShowWindow = 0
Set envStream = fso.OpenTextFile("$escapedEnv", 1, False, -1)
Dim env()
n = -1
Do Until envStream.AtEndOfStream
  line = envStream.ReadLine
  If Len(line) > 0 Then
    n = n + 1
    ReDim Preserve env(n)
    env(n) = line
  End If
Loop
envStream.Close
If n >= 0 Then
  startup.EnvironmentVariables = env
End If
Set proc = GetObject("winmgmts:\\\\.\\root\\cimv2:Win32_Process")
res = proc.Create("$escapedCmdLine", "$escapedCwd", startup, pid)
WScript.Quit res
''';

  final vbsFile = File(p.join(tempDir.path, 'daoyuan_spawn_$stamp.vbs'));
  try {
    final bytes = <int>[0xFF, 0xFE];
    for (final codeUnit in vbsContent.codeUnits) {
      bytes.add(codeUnit & 0xFF);
      bytes.add((codeUnit >> 8) & 0xFF);
    }
    await vbsFile.writeAsBytes(bytes);
    final result = await Process.run(
      'wscript.exe',
      ['//B', '//Nologo', vbsFile.path],
      workingDirectory: workingDirectory,
    );
    if (result.exitCode == 0) {
      try {
        if (envFile.existsSync()) envFile.deleteSync();
      } catch (_) {}
      return;
    }
  } catch (_) {
  } finally {
    try {
      if (vbsFile.existsSync()) vbsFile.deleteSync();
    } catch (_) {}
  }

  final d = String.fromCharCode(36);
  final ps =
      '${d}si = [wmiclass]"Win32_ProcessStartup"; '
      '${d}cfg = ${d}si.CreateInstance(); '
      '${d}cfg.ShowWindow = 0; '
      '${d}r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create '
      '-Arguments @{ CommandLine = ${_psQuote(cmdLine)}; CurrentDirectory = ${_psQuote(workingDirectory)}; ProcessStartupInformation = ${d}cfg; }; '
      'if (${d}r.ReturnValue -ne 0) { throw "Win32_Process.Create $d(${d}r.ReturnValue)" }';
  try {
    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-Command',
        ps,
      ],
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) {
      final err = '${result.stderr}'.trim();
      throw StateError(
        '拉起酒馆失败（${result.exitCode}）${err.isEmpty ? '' : '：$err'}',
      );
    }
  } finally {
    try {
      if (envFile.existsSync()) envFile.deleteSync();
    } catch (_) {}
  }
}

String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";
