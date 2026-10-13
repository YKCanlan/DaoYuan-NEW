# 架构

道渊 NEW 从本提交起重置为：**Flutter 外壳 + 原生 SillyTavern 内核**。

不再使用 Rust 重写提示词、世界书、MVU、Regex 或推理后端。

```text
Flutter Desktop（道渊 UI 风格）
  ├─ 左栏 / 顶栏 / 右栏灵台铬
  ├─ 中央视口：WebView2 → SillyTavern
  │     注入 daoyuan-shell：藏顶栏图标，点击映射到 .drawer-toggle
  └─ 生命周期：发现端口、拉起 Node、退出回收
           │
           ▼
scripts/start-tavern.mjs
           │
           ▼
SillyTavern @ release
  Node server.js   文件 IO / 模型代理 / CSRF
  public JS        Generate / 世界书 / 宏 / EJS / 扩展 / MVU
  数据             runtime/data
```

## 铁律

1. **生成权威 = SillyTavern JS 运行时。** 禁止在 Dart 里复刻 `Generate()`。
2. **Flutter 只做窗口、视觉与进程。** 主聊天是酒馆页，不是自研气泡引擎。
3. **只读引用** `DaoYuan-Main` / `DaoYuan-Branch` / `DaoYuan-System`，不得修改。
4. 模型输出只解析为结构化数据，禁止 `eval` / `new Function`。
5. **不改 SillyTavern 源码。** 壳层能力只通过 WebView 注入脚本 / 会话变量完成。

## 壳层如何打开酒馆功能

左栏与顶栏的抽屉 id 对齐原生顶栏：

| 道渊 id | SillyTavern 点击目标 |
|---|---|
| `api_connect` | `#sys-settings-button > .drawer-toggle` |
| `api_params` | `#ai-config-button > .drawer-toggle` |
| `prompt` | `#advanced-formatting-button > .drawer-toggle` |
| `characters` | `#rightNavHolder > .drawer-toggle` |
| `worldbook` | `#WI-SP-button > .drawer-toggle` |
| `persona` | `#persona-management-button > .drawer-toggle` |
| `extensions` | `#extensions-settings-button > .drawer-toggle` |
| `system` | `#user-settings-button > .drawer-toggle` |

注入脚本把 `--topBarBlockSize` 置 0，隐藏 `#top-settings-holder` 里的图标，避免和道渊顶栏双铬。抽屉内容仍由酒馆 DOM 渲染在中央视口。

## 酒馆视口皮肤（菜单 / 铬与 Flutter 对齐）

**不改** `resources/sillytavern` 源码。视觉语言只通过 WebView `addScriptToExecuteOnDocumentCreated` 注入：

| 层 | 位置 | 作用 |
|---|---|---|
| 色盘锁 | `html.daoyuan-shell` 上 `--SmartTheme*` `!important` | 把酒馆 Smart Theme 锁到玄墨 / 发丝线 / 冷白，打赢 ST 内联主题的 inline 变量 |
| 铬 CSS | `apps/desktop/lib/core/tavern_skin.dart` | 抽屉、弹窗、表单、按钮、Select2、吐司、登录页、世界书 / 角色列表等菜单铬 |
| 字体 | `html.daoyuan-font-yahei` / `kaiti` / `fangsong` | 默认微软雅黑，跟 Flutter `uiFontFamily` |
| 欢迎气泡 | 注入脚本替换默认 Assistant | 头像、名字 YKCanlan、道渊微端介绍。只动仍显示酒馆默认问候的那条；用户另设的欢迎角色不动 |

聊天气泡仍是酒馆 DOM（不重写 `Generate()`）；只把背景色盘和输入栏铬拉到 NEW 语汇。ST 「用户设置 → 主题」调色板不再能改变壳层菜单色盘。

欢迎页在没有当前会话时，酒馆会插一条名字为 Assistant、头像为系统图标、正文为「如果您已连接到一个 API…」的气泡。壳层监听 `#chat`，只有 `type="assistant_message"` 且名字仍是 Assistant、正文仍是这句默认问候时，才换成 YKCanlan、`assets/branding/welcome-assistant.jpg` 的 data URL，以及道渊微端介绍。下方的 API 连接 / 角色管理 / 扩展程序按钮仍是酒馆的欢迎提示，不改。

## 壳层面板几何（居中同框）

色盘之外，抽屉 / 编辑层 / 问对的**位置与尺寸**也只由注入 CSS 接管，不改 SillyTavern 源码，也不改 `#sheld` 聊天列宽度。

酒馆原生有三套坐标：居中抽屉（宽跟 `--sheldWidth`、高度随内容）、`fillLeft` / `fillRight`（吃剩余半宽、贴视口两缘）、对话框（500 / 750 / 90vw）。壳层又把 `--topBarBlockSize` 置 0，左栏与灵台再切走 WebView 宽度，所以各窗口会错位、变瘦或贴顶。

统一为三档，锚点都在中央视口内，四边留 `--dy-inset`（16px）：

| 档 | 对象 | 框 |
|---|---|---|
| A 工作卷 | 顶栏八个功能抽屉（含 `fillLeft` / `fillRight` / `#WorldInfo`），以及其他打开的 `.drawer-content` | 宽 `min(720px, 100dvw - 32px)`，高 `100dvh - 32px`，水平居中 |
| B 编辑卷 | `#character_popup` | 同锚点，宽 `min(860px, 100dvw - 32px)`，高度与 A 相同 |
| C 问对 | `dialog.popup`、`#dialogue_popup` | 宽 520（不超视口），高度随内容、上限约 70dvh，水平垂直居中。`large` 与 A 同框，`wide` / `wider` 与 A 同宽 |

`#world_popup` 是世界书抽屉内部的词条区，不另拉一层浮窗，跟着工作卷一起滚动。`#cfgConfig` 与 `#logprobsViewer` 保持酒馆原生小检视窗。拖拽把手隐藏。`movingUI` 不作为壳层布局依据。

打开前就用内联 `!important` 写好同框几何，并关掉抽屉的高度过渡，避免先闪出酒馆原生位置再跳到同框。酒馆若要等上一个抽屉的关闭动画，壳层会先收起其它抽屉，省掉这段等待。工作卷不用 `transform` 居中（窄视口下酒馆会给 `body` 加上 `touch-action: none`，再叠加位移后滚轮进不了抽屉）。内层高度限制全部放开，滚轮滚的是抽屉本身。指针在抽屉上时不把滚轮交给背后的聊天列。

层叠：工作卷 4010，编辑卷 4050，问对遮罩 / 对话框 4100，吐司与 Select2 更高。聊天主列、欢迎页、面板内 accordion 不进这套框。

WebView2 开了纹理回退之后，系统下拉弹层不会画进视口。这不限 API 连接页：预设、采样、世界书、用户设置里的原生 `<select>`，以及 `<input list>` 的建议列表，都是同一类系统弹层。壳层不改酒馆源码：可见的原生下拉（含多选）和 datalist 改走页内 `.daoyuan-select-menu`，Select2 在打开后按触发框重新定位。菜单用实底、贴住触发框，不用浏览器 Popover 的居中规则；切换抽屉时收起，避免残留在别的页面上。

酒馆 `style.css` 给 `html` 写了 `-webkit-transform: translateZ(0)` 和 `-webkit-perspective`，把整页的 fixed/absolute 包含块从视口改成 `html`。Select2 仍把视口坐标写进 `position: absolute`，搜索框加复选项（世界书名、角色名）就会漂在世界书和用户设定中间。壳层在 `html.daoyuan-shell` 上清掉这层位移。浮层 Select2 再去掉 `backdrop-filter`：纹理模式下毛玻璃会单独合成一层，位置仍会偏。打开后把下拉挂到 `body`，内层改成相对定位贴住触发框，结果列表回来后再补几帧；换抽屉时调 `select2('close')`，不只拿掉定位类名。

滚轮在纹理模式下仍然到不了光标下的节点：插件即使改用最近一次指针位置，`SendMouseInput(WHEEL)` 也不会让页面滚动。`scripts/patch-webview-wheel.mjs` 关掉插件的滚轮转发，并让按下落在这次事件的坐标上。壳层直接收 Flutter 的滚轮与触控板平移，按指针位置调用 `__daoyuan.scrollAt`，从命中元素往上找第一个还能滚的容器（聊天、抽屉、下拉列表、编辑器、文本框）。页面里的系统 `wheel` 一律取消，避免滚到左上角或滚两次。聚焦的数字输入仍按步长改值，不滚容器。

下拉列表（上下文模板这类页内菜单，以及 Select2）不再进浏览器 Popover 顶层。顶层里的滚动条点击会穿透到下面的聊天页，酒馆把这次按下当成抽屉外点击，于是直接关回主界面。菜单改挂在 `body` 上，用实底和固定定位；菜单内部的按下（含滚动条）不再冒泡到酒馆的外部点击处理。点在菜单矩形里、却没打中菜单节点的穿透点击也会被吃掉。

## 运行时目录

`DAOYUAN_RUNTIME_ROOT` → 便携 `exe/runtime/` → 项目根 `runtime/` → `%LOCALAPPDATA%\DaoYuan\runtime`。

| 路径 | 用途 |
|---|---|
| `runtime/host.json` | 握手：`wrapperPid` / `pid` / `port` / `url` / `urlSuffix` |
| `runtime/data` | SillyTavern `dataRoot` |
| `runtime/config.yaml` | 酒馆配置（强制 `listen: false`） |
| `runtime/logs/tavern.log` | Node 日志 |
| `runtime/webview` | WebView2 用户数据（cookie / 本地存储） |
| `runtime/ui-state.json` | 壳层偏好：栏位折叠、字体、`autoUpdateTavern`、本机端口与地址后缀、网页端同步表单（只在本机） |
| `runtime/host.lock` | 正在拉起的包裹脚本 PID，避免同一次启动再开一份 Node |
| `runtime/data/<user>/backups/daoyuan-sync-*` | 同步前自动备份被覆盖的设置、预设、世界书、角色卡 |
| `runtime/logs/update.log` | 官方酒馆内核检查与更新日志 |

Windows 上若安装目录含非 ASCII 字符（例如 `交付`），Node 的 `fs.cpSync` 拷目录会把进程打崩（`0xC0000409`）。酒馆播种立绘目录时会走到这里。`start-tavern.mjs` 在 `server.js` 之前加载 `scripts/windows-safe-cp.cjs`，只替换这一处拷贝，不改 SillyTavern 源码。

## 进程回收

酒馆仍然用 WMI 脱离 Flutter 的作业对象，避免窗口还在时被一起杀掉。关窗后必须自己收干净，不能只 `child.kill()`：Windows 上那只结束直接子进程，孙子进程和超时后仍在跑的更新 / 同步脚本都会留下。

1. `start-tavern.mjs` 监视父 PID。父进程消失后 `taskkill /T /F` 杀掉酒馆进程树，再退出包裹脚本。`EPERM` 视为父进程仍在，避免误判后又拉起一份。
2. 拉起前写 `runtime/host.lock`。已有活的包裹脚本就等它，不再开第二个 Node。
3. 退出、更新超时、同步超时都按进程树杀。另外扫一遍命令行：只杀本次安装的 `start-tavern.mjs` / `update-tavern.mjs` / `sync-remote-tavern.mjs` / `windows-safe-cp.cjs` / 本机 `config.yaml` 与 `dataRoot`。不碰 Pi、CodeGraph 或别的酒馆。
4. 窗口销毁时，runner 再按 exe 旁 `runtime/host.json` 的 `wrapperPid` 与 `pid` 杀一次，防止 Dart 还没跑到回收进程就没了。

## 本机地址后缀

微端设置里可以改本机端口（默认 8100，对齐旧版启动页的端口）和地址后缀。后缀留空时地址仍是 `http://127.0.0.1:8100/`。填 `daoyuan` 后，视口打开 `http://127.0.0.1:8100/daoyuan/`。

不改 SillyTavern 源码。`server.js` 之前加载 `scripts/url-suffix.cjs`，只把 `/daoyuan` 这一层从请求路径上剥掉，酒馆仍然看到原来的 `/`。相对资源（`style.css`）会落在后缀下面，一并被剥掉。直接打开根路径的页面会跳到带后缀的地址。

后缀只允许字母、数字、下划线和连字符，且不能占用 `api`、`css`、`characters` 这类酒馆自己的第一段路径。保存后若与当前内核不同，重启本机 Node，不动 `runtime/data`。

## 微端设置与官方酒馆更新

左栏下方「道渊微端 / 微端设置」是 Flutter 页，不是酒馆「用户设置」抽屉。打开时中央视口换这一页，WebView 保持挂载。页内每个模块默认收起，点标题栏展开或收起；展开状态只留在当前页面，不写进 `runtime/ui-state.json`。

字体上面一块是「流畅模式」，默认关闭。开关写入 `runtime/ui-state.json` 的 `smoothUi`，并立刻给视口 `html` 加或去 `daoyuan-smooth`：关掉聊天区毛玻璃和正文淡入，屏幕外的 `.mes` 用 `content-visibility` 先不画，抓帧上限 30。纹理回退仍保持开着，不改酒馆源码。未记录时为关。

最后一块是「界面字体」。内置微软雅黑、楷体、仿宋，缺省微软雅黑。选择写入 `runtime/ui-state.json` 的 `fontFamily`，并立刻推到外壳主题和酒馆视口（`html.daoyuan-font-*`）。未记录或无法识别的值回落微软雅黑。

内核更新对齐本机 SillyTavern-Launcher 的「更新并启动 / 直接启动」，只跟踪官方 `release`（https://github.com/SillyTavern/SillyTavern/tree/release）：

1. 拉起 Node 之前在 `resources/sillytavern` 执行 `git fetch origin release`，比较 `HEAD` 与 `origin/release`。版本号只供展示。Git 不读 Windows 系统代理；若环境变量没有代理，这次 git/npm 使用当前用户已启用的系统代理，不改全局 Git 配置。
2. 没有 Git、没有 `.git` 或网络失败：不拦启动，设置页标明无法检查。
3. 有新提交且未开自动更新：先问「更新并进入 / 直接进入」，再启动。
4. 开了自动更新：直接 `git pull --ff-only origin release`（最多 3 次），再按启动器的参数装依赖，然后启动。失败仍进当前内核。
5. 浅克隆先 `git fetch --unshallow`。不自动 `git reset --hard`。除 `package-lock.json` 外工作区有改动则拒绝更新。
6. 酒馆已在跑时不原地覆盖；设置页的「更新并重启」会先停 Node。

用户数据在 `runtime/data`，不在内核仓库里。更新不触聊天、角色卡和密钥。便携包必须带上 `resources/sillytavern/.git`，否则安装包无法检查更新。

## 内置扩展

酒馆助手（JS-Slash-Runner）和提示词模板（ST-Prompt-Template）随客户端安装。**不改** SillyTavern 源码，也不写进 `runtime/data`。

它们落在全局扩展目录 `resources/sillytavern/public/scripts/extensions/third-party/`。这个目录被酒馆自己的 `.gitignore` 忽略，所以官方内核 `git status` 看不到它们，内核更新不会因为这两个目录拒绝快进，`git pull` 也不会删掉被忽略的文件。

安装方式与酒馆扩展面板的「安装」相同，由 `scripts/ensure-builtin-extensions.mjs` 执行：

| 扩展 | 上游 | 目录 |
|---|---|---|
| 酒馆助手 | https://github.com/N0VI028/JS-Slash-Runner | `third-party/JS-Slash-Runner` |
| 提示词模板 | https://github.com/zonde306/ST-Prompt-Template | `third-party/ST-Prompt-Template` |

1. 目录里已经有 `manifest.json`：不覆盖、不改 remote、不改分支。用户在扩展面板里的更新、换分支和停用保持原样。
2. 没有目录，或目录不完整（没有 manifest）：`git clone --depth 1` 上游默认分支。`origin` 就是上表的仓库。浅克隆与酒馆自己的安装一致，扩展面板的更新走 `git pull` / `git fetch`。
3. 不执行扩展自己的 `npm run build`。上游仓库已经带可加载的 `dist/`。本地构建会弄脏工作区，扩展自动更新就会失败。
4. 不改 `settings.json`。扩展默认启用；用户在扩展面板里停用后，下次启动不会重新打开。
5. 没有 Git 或连不上 GitHub：不拦酒馆启动。`npm run setup` 和便携打包会要求克隆成功，并且 `origin` 必须仍是上游仓库。
6. Git 不读 Windows 系统代理；与内核更新一样，环境变量没有代理时使用当前用户已启用的系统代理，不改全局 Git 配置。
7. 同名扩展若已经装在用户目录 `runtime/data/<user>/extensions/`，酒馆优先加载用户那份，那份自己的 Git remote 仍是它的更新渠道。网页端同步发现内置全局目录已有同名 manifest 时，不再往用户目录克隆第二份。

上游 manifest 里的 `auto_update` 保持原样。酒馆会按它自己的规则检查并拉取这两个仓库。

便携包必须带上这两个目录里的 `.git`，否则扩展面板无法对照上游更新。

## 外部扩展边界

道渊日记源码迁至仓库外的 `E:\DaoYuan\DaoYuan-Diary\`，作为个人项目独立构建和测试；它不属于道渊 NEW 的 Git、构建流程或便携包。NEW 的 Flutter 外壳和启动脚本只负责原生 SillyTavern 与通用扩展能力，不自动安装、更新或删除任何日记插件或用户数据。已有聊天、密钥及插件设置继续留在 `runtime/`；用户以后可以自行在酒馆扩展面板安装个人日记项目。

## 1.0.0 发布边界

交付目录为 `E:\DaoYuan\交付\DaoYuan-NEW\本地客户端`（便携版）和 `E:\DaoYuan\交付\DaoYuan-NEW\安装程序`（Inno Setup 单文件安装包）。两个版本使用同一 Flutter Release 产物、同一应用图标和版本号。安装版采用用户目录安装，不要求管理员权限；升级时保留安装目录内的 `runtime/`，卸载时也不清除用户数据。

打包仅携带 Flutter 发布文件、启动脚本、便携 Node、官方 SillyTavern release 的源代码与运行依赖，以及酒馆助手、提示词模板的上游仓库。必须保留内核与两个内置扩展的 `.git` 以支持原版更新；必须排除酒馆工作区的 `data/`、`backups/` 和日记扩展，安装程序不收录 `runtime/`。本机角色卡、聊天、密钥、Cookie、日志与调试任务不属于源码仓库或交付包。图标来源 PNG 放在 Flutter Windows runner 的 resources 下，并由其生成 Windows ICO；安装包也使用相同 ICO。

## 网页端酒馆同步

微端设置里的「网页端酒馆同步」对应旧版壳层的同名能力。**不改** SillyTavern 源码，也不再把端点打进 `server-main.js`。

Flutter 把网址、可选 Bearer、可选 Basic Auth 从 stdin 交给 `scripts/sync-remote-tavern.mjs`。脚本自己访问网页端 `/csrf-token`、`/api/settings/get`、`/api/worldinfo/list`、`/api/worldinfo/get`、`/api/characters/all`、`/characters/<卡>.png`、`/api/extensions/discover` 与 `/api/extensions/version`，再写入本机用户目录：

| 写入 | 不写入 |
|---|---|
| `settings.json` | 聊天 `chats/` |
| OpenAI / NovelAI / TextGen / Kobold 预设 | `secrets.json` |
| instruct、context、sysprompt、reasoning | 网页端没有 git 地址的插件（只报错，不猜文件树） |
| 同名世界书 `worlds/*.json` | 本地已经存在的插件目录 |
| 同名角色卡 `characters/*.png` | 内置全局扩展里已有同名 manifest 的插件 |
| 第三方插件：按网页端 git 地址浅克隆到 `extensions/<目录>` | |

世界书名单同时接受当前接口的 `{file_id,name}` 和旧接口的字符串。角色卡只收 PNG，卡内嵌的世界书会跟着卡走。插件只补本地还没有的目录，用本机 `git clone --depth 1`，不改 `resources/sillytavern`，也不把带账号的 git 地址传给 git。内置全局扩展已经占住同名目录时不再克隆一份到用户目录，避免盖住原上游更新渠道。写入前把将被覆盖的文件复制到该用户的 `backups/daoyuan-sync-<时间>/`。只覆盖同名文件，不删除网页端没有的本地文件。同步成功后刷新中央酒馆视口。表单记在 `runtime/ui-state.json`，不进仓库。目标如果是本机微端自己的回环端口，直接拒绝。
