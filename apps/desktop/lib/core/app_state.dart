/// 桌面外壳状态。不承载生成链，只管理窗口、酒馆进程与壳层折叠。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'paths.dart';
import 'remote_sync.dart';
import 'st_launcher.dart';
import 'tavern_address.dart';
import 'tavern_bridge.dart';
import 'tavern_update.dart';
import 'theme.dart';

/// 酒馆连接状态。
enum KernelStatus { idle, launching, online, error }

/// 启动前的内核更新门禁。
enum BootGate { idle, checking, awaitingChoice, updating, done }

/// 应用状态。
class AppState extends ChangeNotifier {
  AppState({StLauncher? launcher}) : _launcher = launcher ?? StLauncher();

  final StLauncher _launcher;
  final TavernUpdater _updater = const TavernUpdater();
  final RemoteTavernSync _remoteSync = const RemoteTavernSync();
  bool _hostReleaseStarted = false;
  bool _bootStarted = false;
  Completer<bool>? _updateDecision;

  KernelStatus connection = KernelStatus.idle;
  String connectionError = '';
  HostHandshake? handshake;
  bool navCollapsed = false;
  bool hudCollapsed = true;
  String uiFontFamily = DaoYuanTheme.defaultFontId;
  bool uiSmooth = false;
  String? activeDrawerId;
  bool shellSettingsOpen = false;
  bool autoUpdateTavern = false;
  int tavernPortPref = kDefaultTavernPort;
  String urlSuffix = '';
  bool addressBusy = false;
  String addressMessage = '';
  String addressTone = '';
  bool uiReady = false;
  String remoteSyncUrl = 'http://127.0.0.1:8000';
  String remoteSyncToken = '';
  String remoteSyncUsername = '';
  String remoteSyncPassword = '';
  bool remoteSyncBusy = false;
  String remoteSyncMessage = '';
  String remoteSyncTone = '';
  BootGate bootGate = BootGate.idle;
  bool updateBusy = false;
  bool pendingUpdateChoice = false;
  TavernUpdateReport? tavernUpdate;
  int kernelGeneration = 0;

  Future<dynamic> Function(String script)? _evalTavern;

  bool get online => connection == KernelStatus.online;
  String get tavernUrl => handshake?.url ?? '';
  int get tavernPort => handshake?.port ?? 0;

  /// 由 [TavernView] 绑定 WebView `executeScript`。
  void bindTavernEval(Future<dynamic> Function(String script)? eval) {
    _evalTavern = eval;
  }

  /// 左栏/顶栏点抽屉：真正打开的是中央视口里的原生酒馆面板。
  void selectDrawer(String? id) {
    shellSettingsOpen = false;
    if (id != null && id == activeDrawerId) {
      activeDrawerId = null;
    } else {
      activeDrawerId = (id == null || id.isEmpty) ? null : id;
    }
    notifyListeners();
    unawaited(pushDrawerToTavern());
  }

  void selectPlay() => selectDrawer(null);

  /// 微端自己的设置页，不打开酒馆抽屉。
  void selectShellSettings() {
    shellSettingsOpen = true;
    activeDrawerId = null;
    notifyListeners();
    unawaited(pushDrawerToTavern());
  }

  Future<void> pushDrawerToTavern() async {
    final eval = _evalTavern;
    if (eval == null) return;
    final id = activeDrawerId ?? '';
    for (var i = 0; i < 30; i++) {
      try {
        final result = await eval(tavernOpenDrawerScript(id));
        if (result == 'not-ready' || result == 'missing-bridge') {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          continue;
        }
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  /// 页面加载完成后：等酒馆主界面就绪，再同步皮肤字体与抽屉。
  Future<void> onTavernPageReady() async {
    final eval = _evalTavern;
    if (eval == null) return;
    for (var i = 0; i < 40; i++) {
      try {
        final ready = await eval(kTavernPageReadyScript);
        if (ready == true) break;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    await pushFontToTavern();
    await pushSmoothToTavern();
    if (activeDrawerId != null) {
      await pushDrawerToTavern();
      return;
    }
    try {
      final current = await eval(kTavernCurrentDrawerScript);
      if (current is String && current.isNotEmpty) {
        activeDrawerId = current;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// 把壳层字体推到酒馆视口（默认微软雅黑）。
  Future<void> pushFontToTavern() async {
    final eval = _evalTavern;
    if (eval == null) return;
    try {
      await eval(tavernSetFontScript(uiFontFamily));
    } catch (_) {}
  }

  /// 把流畅模式推到酒馆视口。默认关，玻璃外观不变。
  Future<void> pushSmoothToTavern() async {
    final eval = _evalTavern;
    if (eval == null) return;
    try {
      await eval(tavernSetSmoothScript(uiSmooth));
    } catch (_) {}
  }

  Directory get _runtime => resolveRuntimeDir();

  File get _uiStateFile => File(p.join(_runtime.path, 'ui-state.json'));

  Future<void> loadUiState() async {
    try {
      if (_uiStateFile.existsSync()) {
        final json = jsonDecode(_uiStateFile.readAsStringSync());
        if (json is Map) {
          navCollapsed = json['navCollapsed'] == true;
          if (json.containsKey('hudCollapsed')) {
            hudCollapsed = json['hudCollapsed'] == true;
          }
          autoUpdateTavern = json['autoUpdateTavern'] == true;
          uiFontFamily = DaoYuanTheme.resolveFontId(json['fontFamily'] as String?);
          uiSmooth = json['smoothUi'] == true;
          final savedPort = json['tavernPort'];
          if (savedPort is num && savedPort >= 1 && savedPort <= 65535) {
            tavernPortPref = savedPort.toInt();
          }
          urlSuffix = normalizeTavernSuffix(json['urlSuffix'] as String? ?? '') ?? '';
          final remote = json['remoteSync'];
          if (remote is Map) {
            final url = (remote['url'] as String?)?.trim() ?? '';
            if (url.isNotEmpty) remoteSyncUrl = url;
            remoteSyncToken = remote['token'] as String? ?? '';
            remoteSyncUsername = remote['username'] as String? ?? '';
            remoteSyncPassword = remote['password'] as String? ?? '';
          }
        }
      }
    } catch (_) {}
    uiReady = true;
    notifyListeners();
  }

  void _persistUiState() {
    try {
      _runtime.createSync(recursive: true);
      _uiStateFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'navCollapsed': navCollapsed,
          'hudCollapsed': hudCollapsed,
          'fontFamily': uiFontFamily,
          'smoothUi': uiSmooth,
          'autoUpdateTavern': autoUpdateTavern,
          'tavernPort': tavernPortPref,
          'urlSuffix': urlSuffix,
          'remoteSync': {
            'url': remoteSyncUrl,
            'token': remoteSyncToken,
            'username': remoteSyncUsername,
            'password': remoteSyncPassword,
          },
        }),
      );
    } catch (_) {}
  }

  void setNavCollapsed(bool value) {
    if (navCollapsed == value) return;
    navCollapsed = value;
    _persistUiState();
    notifyListeners();
  }

  void setHudCollapsed(bool value) {
    if (hudCollapsed == value) return;
    hudCollapsed = value;
    _persistUiState();
    notifyListeners();
  }

  void setAutoUpdateTavern(bool value) {
    if (autoUpdateTavern == value) return;
    autoUpdateTavern = value;
    _persistUiState();
    notifyListeners();
  }

  /// 测试或同步网页端酒馆。覆盖同名设置、预设、世界书和角色卡；插件只补本地还没有的目录。
  Future<void> runRemoteSync({
    required String mode,
    required String url,
    required String token,
    required String username,
    required String password,
  }) async {
    if (remoteSyncBusy) return;
    final remoteUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!remoteUrl.startsWith('http://') && !remoteUrl.startsWith('https://')) {
      remoteSyncTone = 'error';
      remoteSyncMessage = '请先输入 http:// 或 https:// 网页端酒馆地址。';
      notifyListeners();
      return;
    }
    if (_pointsAtThisTavern(remoteUrl)) {
      remoteSyncTone = 'error';
      remoteSyncMessage = '这是本机微端正在使用的酒馆，不是网页端。请填写网页端地址，通常是 8000 端口。';
      notifyListeners();
      return;
    }
    remoteSyncUrl = remoteUrl;
    remoteSyncToken = token.trim();
    remoteSyncUsername = username.trim();
    remoteSyncPassword = password;
    _persistUiState();
    remoteSyncBusy = true;
    remoteSyncTone = 'busy';
    remoteSyncMessage = mode == 'check' ? '正在测试连接…' : '正在备份并同步设置、预设、世界书、角色卡和插件…';
    notifyListeners();
    try {
      final report = mode == 'check'
          ? await _remoteSync.check(
              remoteUrl: remoteSyncUrl,
              token: remoteSyncToken,
              username: remoteSyncUsername,
              password: remoteSyncPassword,
            )
          : await _remoteSync.sync(
              remoteUrl: remoteSyncUrl,
              token: remoteSyncToken,
              username: remoteSyncUsername,
              password: remoteSyncPassword,
            );
      var message = report.describe(mode);
      if (mode == 'sync' && report.wroteAnything) {
        final reloaded = await _reloadTavern();
        message = reloaded
            ? '$message\n酒馆已刷新。'
            : '$message\n请回到聊天页后刷新一次，设置才会生效。';
      }
      remoteSyncTone = report.ok && report.errors.isEmpty ? 'ready' : 'error';
      if (report.ok && mode == 'check') remoteSyncTone = 'ready';
      remoteSyncMessage = message;
    } catch (error) {
      remoteSyncTone = 'error';
      remoteSyncMessage = '同步失败：$error';
    } finally {
      remoteSyncBusy = false;
      notifyListeners();
    }
  }

  bool _pointsAtThisTavern(String remoteUrl) {
    final localPort = tavernPort;
    if (localPort <= 0) return false;
    final uri = Uri.tryParse(remoteUrl);
    if (uri == null || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    const loopback = {'127.0.0.1', 'localhost', '::1'};
    if (!loopback.contains(host)) return false;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    return port == localPort;
  }

  Future<bool> _reloadTavern() async {
    final eval = _evalTavern;
    if (eval == null) return false;
    try {
      await eval('location.reload()');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 打开窗口后先对照官方 release，再拉起酒馆。
  Future<void> boot() async {
    if (_bootStarted) return;
    _bootStarted = true;
    await _gateUpdate(allowPrompt: true);
    await connect();
  }

  void markChecking() {
    if (bootGate != BootGate.idle) return;
    bootGate = BootGate.checking;
    notifyListeners();
  }

  /// 启动门禁里的选择：更新并进入，或直接进入。
  void decideUpdate(bool apply) {
    if (!pendingUpdateChoice) return;
    pendingUpdateChoice = false;
    notifyListeners();
    final decision = _updateDecision;
    _updateDecision = null;
    if (decision != null && !decision.isCompleted) {
      decision.complete(apply);
    }
  }

  Future<void> refreshTavernUpdate() async {
    if (updateBusy) return;
    updateBusy = true;
    notifyListeners();
    tavernUpdate = await _updater.check();
    updateBusy = false;
    notifyListeners();
  }

  /// 停掉正在跑的内核，更新后再拉起。
  Future<void> updateAndRestart() async {
    if (updateBusy || connection == KernelStatus.launching) return;
    updateBusy = true;
    bootGate = BootGate.updating;
    notifyListeners();
    StLauncher.stopSync(handshake ?? StLauncher.discover());
    handshake = null;
    connection = KernelStatus.idle;
    tavernUpdate = await _updater.apply();
    if (tavernUpdate?.phase == TavernUpdatePhase.updated) {
      kernelGeneration += 1;
    }
    updateBusy = false;
    bootGate = BootGate.done;
    await connect();
  }

  Future<void> _gateUpdate({required bool allowPrompt}) async {
    bootGate = BootGate.checking;
    notifyListeners();
    tavernUpdate = await _updater.check();
    final running = await _kernelRunning();
    if (tavernUpdate?.phase == TavernUpdatePhase.available) {
      var apply = autoUpdateTavern;
      if (!apply && allowPrompt) {
        bootGate = BootGate.awaitingChoice;
        pendingUpdateChoice = true;
        _updateDecision = Completer<bool>();
        notifyListeners();
        apply = await _updateDecision!.future;
      }
      if (apply) {
        bootGate = BootGate.updating;
        pendingUpdateChoice = false;
        notifyListeners();
        if (running) {
          StLauncher.stopSync(handshake ?? StLauncher.discover());
          handshake = null;
        }
        tavernUpdate = await _updater.apply();
        if (tavernUpdate?.phase == TavernUpdatePhase.updated) {
          kernelGeneration += 1;
        }
      }
    }
    bootGate = BootGate.done;
    notifyListeners();
  }

  Future<bool> _kernelRunning() async {
    final existing = handshake ?? StLauncher.discover();
    if (existing == null) return false;
    return StLauncher.isHealthy(existing);
  }

  void setFontFamily(String id) {
    final next = DaoYuanTheme.resolveFontId(id);
    if (next == uiFontFamily) return;
    uiFontFamily = next;
    _persistUiState();
    notifyListeners();
    unawaited(pushFontToTavern());
  }

  void setUiSmooth(bool value) {
    if (uiSmooth == value) return;
    uiSmooth = value;
    _persistUiState();
    notifyListeners();
    unawaited(pushSmoothToTavern());
  }

  Future<void> connect() async {
    if (connection == KernelStatus.launching) return;
    connection = KernelStatus.launching;
    connectionError = '';
    notifyListeners();
    try {
      final boot = await _launcher.ensureRunning(
        port: tavernPortPref,
        urlSuffix: urlSuffix,
      );
      handshake = boot.handshake;
      connection = KernelStatus.online;
      notifyListeners();
    } catch (error) {
      connection = KernelStatus.error;
      connectionError = error.toString();
      notifyListeners();
    }
  }

  /// 保存本机端口和地址后缀。与当前内核不一致时重启 Node，不碰用户数据。
  Future<void> applyTavernAddress({
    required String portText,
    required String suffixText,
  }) async {
    if (addressBusy || connection == KernelStatus.launching) return;
    final port = normalizeTavernPort(portText);
    final suffix = normalizeTavernSuffix(suffixText);
    if (port == null || suffix == null) {
      addressTone = 'error';
      addressMessage = port == null
          ? '端口必须是 1–65535 之间的整数。'
          : '后缀只能使用字母、数字、下划线和连字符，且不能占用酒馆自己的路径（例如 api、css）。';
      notifyListeners();
      return;
    }
    tavernPortPref = port;
    urlSuffix = suffix;
    _persistUiState();
    final running = handshake;
    if (running != null &&
        connection == KernelStatus.online &&
        running.port == port &&
        running.urlSuffix == suffix) {
      addressTone = 'ready';
      addressMessage = '当前已是 ${running.url}，无需重启。';
      notifyListeners();
      return;
    }
    addressBusy = true;
    addressTone = 'busy';
    addressMessage = '正在按 ${tavernEntryUrl(port: port, suffix: suffix)} 重启酒馆…';
    notifyListeners();
    StLauncher.stopSync(handshake ?? StLauncher.discover());
    handshake = null;
    connection = KernelStatus.idle;
    kernelGeneration += 1;
    await connect();
    addressBusy = false;
    if (connection == KernelStatus.online) {
      addressTone = 'ready';
      addressMessage = '已切换到 $tavernUrl';
    } else {
      addressTone = 'error';
      addressMessage = connectionError.isEmpty ? '重启失败。' : connectionError;
    }
    notifyListeners();
  }

  /// 窗口真正拆掉时同步停酒馆。异步 future 会跟着 Flutter 进程被掐掉。
  void releaseHostOnExitNow() {
    if (_hostReleaseStarted) return;
    _hostReleaseStarted = true;
    StLauncher.stopSync(handshake ?? StLauncher.discover());
  }

  @override
  void dispose() {
    releaseHostOnExitNow();
    super.dispose();
  }
}

/// 把状态注入组件树。
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未挂载');
    return scope!.notifier!;
  }
}
