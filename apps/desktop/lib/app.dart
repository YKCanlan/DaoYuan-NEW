import 'dart:ui';

import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'features/shell/app_shell.dart';

/// 桌面端手势与鼠标拖拽支持。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };
}

/// 应用根组件。
class DaoYuanApp extends StatefulWidget {
  const DaoYuanApp({super.key});

  @override
  State<DaoYuanApp> createState() => _DaoYuanAppState();
}

class _DaoYuanAppState extends State<DaoYuanApp> with WidgetsBindingObserver {
  final AppState _state = AppState();
  String _fontFamily = DaoYuanTheme.defaultFontId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state.addListener(_syncFontFamily);
    _state.markChecking();
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _state.releaseHostOnExitNow();
    }
  }

  void _syncFontFamily() {
    final next = _state.uiFontFamily;
    if (next == _fontFamily || !mounted) return;
    setState(() => _fontFamily = next);
  }

  Future<void> _bootstrap() async {
    await _state.loadUiState();
    await _state.boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.removeListener(_syncFontFamily);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: '道渊',
        debugShowCheckedModeBanner: false,
        theme: DaoYuanTheme.dark(fontFamily: _fontFamily),
        scrollBehavior: const AppScrollBehavior(),
        home: const AppShell(),
      ),
    );
  }
}
