/// 中央视口：嵌入原生 SillyTavern。生成链、扩展、角色卡均由酒馆内核执行。
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../core/app_state.dart';
import '../../core/tavern_bridge.dart';
import '../../core/theme.dart';

/// 酒馆 WebView。
class TavernView extends StatefulWidget {
  const TavernView({super.key});

  @override
  State<TavernView> createState() => _TavernViewState();
}

class _TavernViewState extends State<TavernView> {
  final WebviewController _controller = WebviewController();
  StreamSubscription<WebErrorStatus>? _errorSub;
  StreamSubscription<LoadingState>? _loadSub;
  AppState? _state;
  bool _ready = false;
  String? _loadedUrl;
  String? _error;
  int _seenGeneration = 0;
  bool? _smoothApplied;
  double _wheelX = 0;
  double _wheelY = 0;
  double _wheelDx = 0;
  double _wheelDy = 0;
  Timer? _wheelTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (_state != state) {
      _state?.bindTavernEval(null);
      _state = state;
      state.bindTavernEval(_eval);
    }
    if (_seenGeneration != state.kernelGeneration) {
      _seenGeneration = state.kernelGeneration;
      _loadedUrl = null;
    }
    unawaited(_syncUrl());
    unawaited(_syncSmooth(state.uiSmooth));
  }

  Future<dynamic> _eval(String script) => _controller.executeScript(script);

  /// 纹理模式里系统滚轮到不了光标下的节点。把 Flutter 的滚轮像素交给页面，
  /// 由注入脚本滚动命中的容器。同一帧里的多次滚动合成一次。
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _queueScroll(
      event.localPosition,
      event.scrollDelta.dx,
      event.scrollDelta.dy,
    );
  }

  void _onPanZoom(PointerPanZoomUpdateEvent event) {
    _queueScroll(event.localPosition, -event.panDelta.dx, -event.panDelta.dy);
  }

  void _queueScroll(Offset position, double dx, double dy) {
    final x = position.dx;
    final y = position.dy;
    if (!x.isFinite || !y.isFinite || !dx.isFinite || !dy.isFinite) return;
    if (dx == 0 && dy == 0) return;
    _wheelX = x;
    _wheelY = y;
    _wheelDx += dx;
    _wheelDy += dy;
    _wheelTimer ??= Timer(const Duration(milliseconds: 8), () {
      _wheelTimer = null;
      final dx = _wheelDx;
      final dy = _wheelDy;
      final x = _wheelX;
      final y = _wheelY;
      _wheelDx = 0;
      _wheelDy = 0;
      if (dx == 0 && dy == 0) return;
      unawaited(_scrollAt(x, y, dx, dy));
    });
  }

  Future<void> _scrollAt(double x, double y, double dx, double dy) async {
    try {
      await _controller.executeScript(
        'window.__daoyuan&&window.__daoyuan.scrollAt('
        '${x.toStringAsFixed(2)},${y.toStringAsFixed(2)},'
        '${dx.toStringAsFixed(2)},${dy.toStringAsFixed(2)})',
      );
    } catch (_) {}
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.setBackgroundColor(DaoYuanTheme.voidPitch);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
      try {
        await _controller.addScriptToExecuteOnDocumentCreated(kTavernBridgeScript);
      } catch (_) {}
      _errorSub = _controller.onLoadError.listen((error) {
        if (!mounted) return;
        setState(() => _error = '酒馆页面加载失败：$error');
      });
      _loadSub = _controller.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted) {
          unawaited(_onPageReady());
        }
      });
      if (mounted) {
        setState(() => _ready = true);
      }
      await _syncSmooth(_state?.uiSmooth ?? false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_syncUrl());
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            '初始化 WebView2 失败：$error\n请确认系统已安装 Microsoft Edge WebView2 Runtime。';
      });
    }
  }

  Future<void> _onPageReady() async {
    if (!_ready || !mounted) return;
    try {
      await _controller.executeScript(kTavernBridgeScript);
    } catch (_) {}
    final state = _state;
    if (state == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await state.onTavernPageReady();
  }

  /// 流畅模式把纹理抓帧压到 30；关闭后恢复不限帧。
  Future<void> _syncSmooth(bool on) async {
    if (!_ready || _smoothApplied == on) return;
    _smoothApplied = on;
    try {
      await _controller.setFpsLimit(on ? 30 : 0);
    } catch (_) {
      _smoothApplied = null;
    }
  }

  Future<void> _syncUrl() async {
    if (!_ready || !mounted) return;
    final state = AppScope.of(context);
    final url = state.tavernUrl;
    if (url.isEmpty || url == _loadedUrl) return;
    try {
      await _controller.loadUrl(url);
      if (mounted) {
        setState(() {
          _loadedUrl = url;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '无法打开酒馆：$error');
      }
    }
  }

  @override
  void dispose() {
    _wheelTimer?.cancel();
    _state?.bindTavernEval(null);
    unawaited(_errorSub?.cancel());
    unawaited(_loadSub?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    Widget? overlay;
    if (!state.online && state.bootGate == BootGate.checking) {
      overlay = const _StatusPane(
        title: '正在检查官方酒馆',
        hint: '对照 release · 不启动旧内核',
      );
    } else if (!state.online && state.bootGate == BootGate.awaitingChoice) {
      overlay = const _StatusPane(
        title: '官方酒馆有更新',
        hint: '选择更新并进入，或直接进入当前内核。',
      );
    } else if (!state.online && state.bootGate == BootGate.updating) {
      overlay = _StatusPane(
        title: '正在更新酒馆内核',
        hint: state.tavernUpdate?.message.isNotEmpty == true
            ? state.tavernUpdate!.message
            : '对齐官方 release，并安装依赖。',
      );
    } else if (state.connection == KernelStatus.launching) {
      overlay = const _StatusPane(
        title: '正在唤醒酒馆内核',
        hint: 'SillyTavern release · 127.0.0.1',
      );
    } else if (state.connection == KernelStatus.error) {
      overlay = _StatusPane(
        title: '酒馆内核未就绪',
        hint: state.connectionError,
        actionLabel: '重新拉起',
        onAction: state.connect,
      );
    } else if (!state.online || state.tavernUrl.isEmpty) {
      overlay = _StatusPane(
        title: '等待酒馆握手',
        hint: '请确认已运行 npm run setup，并安装 Node 20+。',
        actionLabel: '连接',
        onAction: state.connect,
      );
    } else if (_error != null) {
      overlay = _StatusPane(
        title: '视口异常',
        hint: _error!,
        actionLabel: '重试',
        onAction: () {
          setState(() {
            _loadedUrl = null;
            _error = null;
          });
          unawaited(_syncUrl());
        },
      );
    } else if (!_ready) {
      overlay = const _StatusPane(
        title: '正在打开视口',
        hint: 'WebView2 · 原生酒馆',
      );
    }

    return ColoredBox(
      color: DaoYuanTheme.voidPitch,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: _onPointerSignal,
              onPointerPanZoomUpdate: _onPanZoom,
              child: Webview(
                _controller,
                permissionRequested: (url, kind, userInitiated) async {
                  return WebviewPermissionDecision.allow;
                },
              ),
            ),
          if (overlay != null) overlay,
        ],
      ),
    );
  }
}

class _StatusPane extends StatelessWidget {
  const _StatusPane({
    required this.title,
    required this.hint,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DaoYuanTheme.voidPitch,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
            decoration: DaoYuanTheme.glassDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.blur_circular,
                    size: 28, color: DaoYuanTheme.blindingWhite),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: DaoYuanTheme.blindingWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: DaoYuanTheme.ashGhost,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
