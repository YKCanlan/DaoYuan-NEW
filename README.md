# 道渊微端 · DaoYuan-New

Flutter 桌面外壳 + [SillyTavern](https://github.com/SillyTavern/SillyTavern/tree/release) 原生内核。

本仓库已重置：删除 Rust 无头内核与旧功能实现，只保留 NEW 版 UI 风格，中央视口直接嵌入原生酒馆。
左栏 / 顶栏会打开 SillyTavern 自己的抽屉（API、角色、世界书、扩展），不在 Dart 里重写设置页。
酒馆助手与提示词模板随内核一起安装，仍从原仓库更新。道渊日记是仓库外的独立个人项目，不参与 NEW 的构建或交付。

```text
Flutter（道渊视觉）  →  WebView2  →  SillyTavern @ release
窗口 / 左栏 / 顶栏 / 灵台铬           Generate / 世界书 / 扩展 / MVU
```

## 快速开始

```powershell
cd E:\DaoYuan\DaoYuan-New
npm run setup
cd apps\desktop
flutter pub get
flutter run -d windows
```

用户数据在 `runtime/`，不进 Git。详见 `docs/build-and-run.md`。

## 许可证

SillyTavern 为 AGPL-3.0。分发本微端时须提供对应源码。
