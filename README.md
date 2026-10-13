# 道渊微端 · DaoYuan-New

道渊微端（NEW 版）是基于 Flutter 桌面外壳与官方原生 [SillyTavern](https://github.com/SillyTavern/SillyTavern) 内核构建的酒馆桌面客户端。

---

## NEW 版与旧版 DaoYuan-mini 的区别

相比旧版 `DaoYuan-mini`，NEW 版进行了底层架构的全面重构：

1. **前端架构独立解耦**  
   采用全新前端架构，前端与酒馆核心互相独立。宿主仅负责桌面窗口与道渊视觉，后端 100% 由原版 SillyTavern 驱动，彻底杜绝逻辑阉割与二次劣质复刻。主界面与抽屉完全直通原生酒馆，保证宏、世界书、EJS、MVU、STScript 与插件生态的原生完整性。
2. **酒馆核心智能自动更新**  
   新增酒馆核心自动更新机制。直接追踪官方 `release` 分支，启动时智能检测并支持无损快进更新，彻底解决后续上游更新导致的不适配问题。
3. **新增网页端设置同步功能**  
   微端设置中内置「网页端酒馆同步」功能。支持填写已有网页端酒馆地址（以及可选的认证凭据），一键拉取远程端的通用配置、模型预设（OpenAI / NovelAI / Kobold 等）、上下文/提示词模板、世界书与角色卡到本地，并在同步前自动创建本地备份，方便多端无缝迁移。
4. **用户数据与内核物理隔离**  
   所有个人数据（角色卡、聊天记录、API 密钥、世界书等）统一保存在本地 `runtime/data` 目录。无论是更新酒馆内核、升级微端版本还是日常备份，都不会触碰或覆盖用户个人数据。
5. **完整保留扩展官方更新通道**  
   内置扩展以官方 Git 浅克隆方式引入并保留上游 Remote。用户可在酒馆扩展设置面板中直接跟随原作者进行一键更新与分支管理。
6. **严密的后台进程守护**  
   解决旧版关窗后残留后台 Node 孤儿进程的问题，采用系统级进程树管理，窗口关闭时自动清理整个后端进程树；同时包含针对 Windows 非 ASCII 安装路径的安全兼容补丁。

---

## 纯净与合规声明

- **不含任何非授权资产**：  
  NEW 版为纯净内核与外壳，**不含任何非授权的角色卡、世界书、私有定制插件或聊天记录等数据**。
- **用户按需自主添加**：  
  安装后为标准的纯净酒馆环境。如需使用特定的角色卡、世界书或第三方扩展，请用户根据自身需求自行添加与导入。
- **本地隐私安全**：  
  客户端不收集任何用户隐私数据，所有 API 密钥与聊天数据均严格保存在本地 `runtime/` 目录中。

---

## 内置精选扩展

初始化时会自动从官方仓库拉取以下主流开源扩展：

- **酒馆助手 (JS-Slash-Runner)**：提供快捷指令与自动化增强脚本能力。
- **提示词模板 (ST-Prompt-Template)**：提供提示词模板与格式化管理能力。

---

## 快速开始

### 环境要求

- Node.js ≥ 20
- Flutter stable ≥ 3.24
- Git 命令行工具
- Windows 10 / 11

### 本地运行

```powershell
# 1. 克隆仓库并进入目录
git clone https://github.com/YKCanlan/DaoYuan-NEW.git
cd DaoYuan-NEW

# 2. 初始化酒馆内核与内置扩展
npm run setup

# 3. 启动桌面端
npm run dev:ui
```

若只需单独启动后端内核：
```powershell
npm run dev:host
```

### 构建打包

```powershell
# 构建本地便携版客户端
npm run build:portable
```

---

## 致谢与开源项目 (Acknowledgements)

道渊微端使用了以下优秀开源项目，感谢原作者们的无私奉献与杰出贡献：

1. **[SillyTavern](https://github.com/SillyTavern/SillyTavern)**  
   - 项目地址：https://github.com/SillyTavern/SillyTavern  
   - 感谢 SillyTavern 团队开源的优秀 LLM 前端与运行时框架，道渊微端的核心内核完全基于官方版本运行。

2. **酒馆助手 · [JS-Slash-Runner](https://github.com/N0VI028/JS-Slash-Runner)**  
   - 作者：[@N0VI028](https://github.com/N0VI028)  
   - 项目地址：https://github.com/N0VI028/JS-Slash-Runner  
   - 感谢作者开发的高效酒馆助手与自动化指令运行扩展。

3. **提示词模板 · [ST-Prompt-Template](https://github.com/zonde306/ST-Prompt-Template)**  
   - 作者：[@zonde306](https://github.com/zonde306)  
   - 项目地址：https://github.com/zonde306/ST-Prompt-Template  
   - 感谢作者开发的提示词模板与格式化扩展。

---

## 许可证

SillyTavern 内核遵循 [AGPL-3.0 License](https://github.com/SillyTavern/SillyTavern/blob/release/LICENSE)。
