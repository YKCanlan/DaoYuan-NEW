import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

import 'app.dart';
import 'core/paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initWebViewEnvironment();
  runApp(const DaoYuanApp());
}

/// WebView2 用户数据写进 runtime/webview，便携包互不串 cookie。
Future<void> _initWebViewEnvironment() async {
  try {
    final dir = Directory(p.join(resolveRuntimeDir().path, 'webview'));
    dir.createSync(recursive: true);
    await WebviewController.initializeEnvironment(userDataPath: dir.path);
  } catch (_) {
    // 环境只能初始化一次；重复调用或缺少 WebView2 时走系统默认。
  }
}
