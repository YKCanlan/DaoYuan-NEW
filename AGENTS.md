# DaoYuan-New 工程约定

## 绝对边界

- **不得修改** `E:\DaoYuan\DaoYuan-Main`、`DaoYuan-Branch`、`DaoYuan-System` 中的任何文件。
  只允许读取与复制到本目录。
- 本目录内不得提交 API 密钥、Cookie、聊天记录、角色卡、世界书等用户数据。
- 模型输出永远只解析为结构化数据，禁止 `eval` / `new Function` / 动态代码执行。

## 架构约束

- **前端**：Flutter 桌面外壳，视觉语言沿用道渊 NEW 主题（玄墨 / 发丝线 / 毛玻璃 / 楷体）。
  中央主界面嵌入原生 SillyTavern（WebView2），不把 WebView 当「第二套酒馆边车」。
- **内核**：生成、世界书、宏、EJS、Regex、STScript、MVU、扩展的唯一权威是
  [SillyTavern release](https://github.com/SillyTavern/SillyTavern/tree/release)。
  **禁止**再用 Rust 或 Dart 重写 `Generate()`。
- **进程**：Flutter 通过 `scripts/start-tavern.mjs` 拉起 bundled/system Node。
  仅绑定 `127.0.0.1`。退出必须回收 Node 进程树。
- **数据**：只写 `runtime/`（见下方优先级）。不与旧 Rust `daoyuan-host` 格式混用。

## 代码规范

- Flutter：`flutter analyze` 必须通过。
- 新增能力先补 `docs/architecture.md`，再写实现。
- 道渊专属壳（灵台 / 小手机）只读写酒馆会话变量，不另立生成权威。道渊日记位于仓库外，不在 NEW 中维护。

## 提交

- 一次提交只做一件事；架构变更必须同步更新 `docs/architecture.md`。

## 已知坑位（改代码前先看）

- **运行时目录**：`DAOYUAN_RUNTIME_ROOT` → 便携 `exe/runtime/` → 项目根 `runtime/` →
  `%LOCALAPPDATA%\DaoYuan\runtime`。
- **Windows 作业对象**：不要用普通 `Process.start` 拉 Node，否则关窗口会把酒馆一起杀掉。
  走 WMI 孤儿进程，并由 `start-tavern.mjs` 监视父 PID。
- **非 ASCII 安装路径**：Node 的 `fs.cpSync` 在 Windows 上拷含中文等字符的目录会直接退出
  `0xC0000409`。`start-tavern.mjs` 必须带上 `scripts/windows-safe-cp.cjs`，不要删。
- **WebView2**：`FLUTTER_WEBVIEW_WINDOWS_USE_TEXTURE_FALLBACK` 必须保持 ON。
- **大文件写入**：单次工具调用有输出长度上限，大文件必须分块多次写。
- **内置扩展**：酒馆助手和提示词模板在 `resources/sillytavern/public/scripts/extensions/third-party/`，由 `scripts/ensure-builtin-extensions.mjs` 按上游 git 浅克隆。不要删 `.git`，不要改它们的 manifest，不要 `npm run build` 弄脏工作区。
