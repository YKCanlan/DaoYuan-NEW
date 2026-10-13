# 构建与运行

## 前置

| 组件 | 说明 |
|---|---|
| Flutter | stable ≥ 3.24，Windows 桌面 |
| Node.js | ≥ 20（开发机 PATH，或日后便携 `resources/node/`） |
| Git | 用于拉取 SillyTavern release |
| WebView2 | Windows 已预装或安装 Runtime |

## 初始化酒馆内核

```powershell
cd E:\DaoYuan\DaoYuan-New
npm run setup
```

会把 [SillyTavern release](https://github.com/SillyTavern/SillyTavern/tree/release) 克隆到 `resources/sillytavern` 并 `npm install`，再把酒馆助手和提示词模板按上游仓库浅克隆到全局扩展目录。已有目录不覆盖，`origin` 仍是原仓库，扩展面板可以继续更新。

## 启动

```powershell
cd E:\DaoYuan\DaoYuan-New\apps\desktop
flutter pub get
flutter run -d windows
```

前端会自动拉起 `scripts/start-tavern.mjs`，并在 WebView2 中打开原生酒馆。
左栏 / 顶栏按钮会点击 SillyTavern 自己的抽屉（API、角色、世界书、扩展等），不再由 Flutter 重写设置页。

也可单独验证内核：

```powershell
npm run dev:host
```

默认地址 `http://127.0.0.1:8100/`。数据写在 `runtime/`，不进 Git。

调试时显示 Node 控制台：

```powershell
$env:DAOYUAN_HOST_CONSOLE = '1'
```

## 发布 Windows 1.0.0

在 Windows 上先运行 `npm run build:portable`，输出到 `E:\DaoYuan\交付\DaoYuan-NEW\本地客户端`（目标必须为空）。它会编译 Flutter Release、同步官方酒馆及内置扩展，排除酒馆 `data/`、`backups/` 和日记插件，再写入空的 `runtime/`。不要把已经启动过的便携目录作为安装包输入。

使用本机 Inno Setup 6 的 `ISCC.exe` 编译 `scripts/installer.iss`，传入 `/DPortableDir=E:\DaoYuan\交付\DaoYuan-NEW\本地客户端` 与 `/DOutputDir=E:\DaoYuan\交付\DaoYuan-NEW\安装程序`。安装包不包含 `runtime/`；便携客户端第一次运行后会在其自身目录生成个人数据，卸载安装版不会删用户数据。发布源码只上传本仓库受控的 Flutter 外壳、脚本与文档，酒馆在安装时由 `npm run setup` 获取，不上传 `resources/sillytavern/` 和 `runtime/`。
