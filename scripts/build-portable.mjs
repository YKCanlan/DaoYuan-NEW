/**
 * 把 Flutter 发行包 + 原生 SillyTavern + 便携 Node 同步到交付目录。
 * 默认目标：E:\DaoYuan\交付\DaoYuan-NEW\本地客户端
 */
import {
  chmodSync,
  copyFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  renameSync,
  rmdirSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs';
import { spawn } from 'node:child_process';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { patchWebviewWheel } from './patch-webview-wheel.mjs';
import { ensureBuiltinExtensions } from './ensure-builtin-extensions.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const destArg = process.argv.find((a, i, all) => all[i - 1] === '--dest');
const dest = resolve(destArg || 'E:/DaoYuan/交付/DaoYuan-NEW/本地客户端');
const skipBuild = process.argv.includes('--skip-build');
const skipTavern = process.argv.includes('--skip-tavern');

function run(command, args, cwd) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, { cwd, stdio: 'inherit', shell: true });
    child.on('exit', (code) => {
      if (code === 0) resolvePromise();
      else reject(new Error(`${command} 退出码 ${code}`));
    });
  });
}

function copyDir(from, to, filter) {
  mkdirSync(to, { recursive: true });
  for (const name of readdirSync(from)) {
    const src = join(from, name);
    if (filter && !filter(src)) continue;
    const st = lstatSync(src);
    const dst = join(to, name);
    if (st.isDirectory()) {
      copyDir(src, dst, filter);
    } else if (st.isFile()) {
      copyFile(src, dst);
    }
  }
}

function robocopyDir(from, to, excludeDirs = []) {
  mkdirSync(to, { recursive: true });
  const xd = excludeDirs.flatMap((name) => ['/XD', name]);
  return new Promise((resolvePromise, reject) => {
    const child = spawn(
      'robocopy',
      [from, to, '/E', '/R:2', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NC', '/NS', ...xd],
      { stdio: 'inherit', windowsHide: true },
    );
    child.on('exit', (code) => {
      const value = code ?? 1;
      if (value >= 8) reject(new Error(`robocopy 退出码 ${value}`));
      else resolvePromise(value);
    });
  });
}

function copyFile(from, to) {
  mkdirSync(dirname(to), { recursive: true });
  const tmp = `${to}.${process.pid}.tmp`;
  copyFileSync(from, tmp);
  try {
    if (existsSync(to)) unlinkSync(to);
  } catch {
    /* 目标可能被占用，下面用覆盖拷贝 */
  }
  try {
    renameSync(tmp, to);
  } catch {
    copyFileSync(tmp, to);
    try {
      unlinkSync(tmp);
    } catch {
      /* ignore */
    }
  }
}

function rimraf(target) {
  if (!existsSync(target)) return;
  const st = lstatSync(target);
  if (st.isDirectory()) {
    for (const name of readdirSync(target)) rimraf(join(target, name));
    rmdirSync(target);
  } else {
    try {
      chmodSync(target, 0o666);
    } catch {
      /* ignore */
    }
    unlinkSync(target);
  }
}

function wipe(rel) {
  const p = join(dest, rel);
  if (!existsSync(p)) return;
  rimraf(p);
  if (existsSync(p)) throw new Error(`未能删除 ${rel}`);
  console.log('removed', rel);
}

const flutterReleaseCandidates = [
  join(root, 'apps/desktop/build/windows/x64/runner/Release'),
  join(root, 'apps/desktop/build/windows/runner/Release'),
];

if (!skipBuild) {
  patchWebviewWheel();
  const flutter = existsSync('E:/Android/flutter/bin/flutter.bat')
    ? 'E:/Android/flutter/bin/flutter.bat'
    : 'flutter';
  console.log('flutter build windows --release');
  await run(flutter, ['build', 'windows', '--release'], join(root, 'apps/desktop'));
}

const release = flutterReleaseCandidates.find((p) => existsSync(p));
if (!release) {
  throw new Error('找不到 Flutter Release 产物。先 flutter build windows --release。');
}

const tavernSrc = join(root, 'resources/sillytavern');
if (!existsSync(join(tavernSrc, 'server.js'))) {
  throw new Error('找不到 resources/sillytavern/server.js。先 npm run setup。');
}

if (!skipTavern) {
  console.log('ensure builtin extensions…');
  const extensions = await ensureBuiltinExtensions({
    tavernRoot: tavernSrc,
    timeoutMs: 600000,
    strict: true,
    log: (message) => console.log(message),
  });
  if (!extensions.ok) {
    const detail = extensions.results
      .filter((row) => row.action !== 'cloned' && row.action !== 'kept')
      .map((row) => `${row.name}: ${row.message}`)
      .join('\n');
    throw new Error(detail || '内置扩展没有从上游就绪。');
  }
}

const nodeSrcCandidates = [
  'E:/DaoYuan/DaoYuan-Main/Main/resources/node/node.exe',
  'E:/DaoYuan/交付/PC/v0.2.0-fixed/resources/node/node.exe',
  'C:/Program Files/nodejs/node.exe',
];
const nodeSrc = nodeSrcCandidates.find((p) => existsSync(p));
if (!nodeSrc) {
  throw new Error('找不到便携 node.exe。');
}

if (existsSync(dest) && readdirSync(dest).length > 0) {
  throw new Error(`交付目录非空，请使用新的空目录打包，避免带入已有 runtime 数据：${dest}`);
}
mkdirSync(dest, { recursive: true });

const junk = [
  'daoyuan-host.exe',
  'daoyuan_desktop.exe',
  '验收说明.txt',
];
for (const rel of junk) wipe(rel);

console.log('copy flutter release →', dest);
wipe('data');
for (const name of [
  'flutter_windows.dll',
  'native_assets.json',
  'WebView2Loader.dll',
  'webview_windows_plugin.dll',
]) {
  const src = join(release, name);
  if (existsSync(src)) copyFile(src, join(dest, name));
}
copyDir(join(release, 'data'), join(dest, 'data'));
copyFile(join(release, 'daoyuan_desktop.exe'), join(dest, '道渊微端.exe'));

mkdirSync(join(dest, 'scripts'), { recursive: true });
copyFile(join(root, 'scripts/start-tavern.mjs'), join(dest, 'scripts/start-tavern.mjs'));
copyFile(join(root, 'scripts/windows-safe-cp.cjs'), join(dest, 'scripts/windows-safe-cp.cjs'));
copyFile(join(root, 'scripts/url-suffix.cjs'), join(dest, 'scripts/url-suffix.cjs'));
copyFile(join(root, 'scripts/update-tavern.mjs'), join(dest, 'scripts/update-tavern.mjs'));
copyFile(join(root, 'scripts/sync-remote-tavern.mjs'), join(dest, 'scripts/sync-remote-tavern.mjs'));
copyFile(join(root, 'scripts/ensure-builtin-extensions.mjs'), join(dest, 'scripts/ensure-builtin-extensions.mjs'));

// 保留 .git，安装包才能对照官方 release 做 git fetch / pull。
// 内置扩展的 .git 也要带走，扩展面板才能对照上游更新。
const diaryExtensionDirs = ['daoyuan-database', 'daoyuan-diary', 'shujuku'];
const skipNames = ['.github', '.vscode', 'colab', 'docker', 'tests', 'backups'];
const destTavernDir = join(dest, 'resources/sillytavern');
if (skipTavern && existsSync(join(destTavernDir, 'server.js'))) {
  console.log('SillyTavern skipped (--skip-tavern)');
} else if (process.platform === 'win32') {
  console.log('sync SillyTavern via robocopy…');
  await robocopyDir(tavernSrc, destTavernDir, [
    ...skipNames,
    ...['data', 'backups', '.gemini'].map((name) => join(tavernSrc, name)),
    ...diaryExtensionDirs.map((name) => join(tavernSrc, 'public', 'scripts', 'extensions', 'third-party', name)),
  ]);
} else {
  console.log('copy SillyTavern (keep upstream .git)…');
  const skip = new Set(skipNames);
  copyDir(tavernSrc, destTavernDir, (source) => {
    const rel = relative(tavernSrc, source).replaceAll('\\', '/');
    const name = source.split(/[/\\]/).pop();
    if (['data', 'backups', '.gemini'].includes(rel)) return false;
    if (rel.startsWith('public/scripts/extensions/third-party/') && diaryExtensionDirs.includes(name)) return false;
    return !skip.has(name);
  });
}

mkdirSync(join(dest, 'resources/node'), { recursive: true });
copyFile(nodeSrc, join(dest, 'resources/node/node.exe'));
const nodeLicense = join(dirname(nodeSrc), 'LICENSE');
if (existsSync(nodeLicense)) {
  copyFile(nodeLicense, join(dest, 'resources/node/LICENSE'));
}

mkdirSync(join(dest, 'runtime'), { recursive: true });

const builtAt = new Date().toISOString();
writeFileSync(
  join(dest, 'version.json'),
  `${JSON.stringify(
    {
      version: '1.0.0',
      name: '道渊微端',
      entry: '道渊微端.exe',
      kernel: 'SillyTavern release',
      builtAt,
      note: 'Flutter 外壳 + 原生酒馆内核。内置酒馆助手与提示词模板，仍从原仓库更新。微端设置可检查并更新官方 release。字体上方可开流畅模式。日记是独立个人项目，不随 NEW 客户端交付。',
    },
    null,
    2,
  )}\n`,
);

writeFileSync(
  join(dest, '使用说明.txt'),
  `道渊 NEW 微端 · 便携版
====================

双击「道渊微端.exe」启动，无需安装。

本包是 Flutter 桌面外壳 + 原生 SillyTavern 内核。
已不再使用 daoyuan-host.exe / Rust 生成链。

首次启动后，数据写在本目录的 runtime\\ 下，例如：
  runtime\\data\\          酒馆用户数据（角色卡、世界书、聊天、密钥）
  runtime\\host.json       本机回环端口握手
  runtime\\logs\\tavern.log 酒馆日志

说明：
- 请勿删除 data\\ 目录和 dll，它们是 Flutter 界面运行所需。
- 请勿删除 resources\\sillytavern 与 resources\\node，它们是酒馆内核。
- 内核由前端自动拉起（仅监听 127.0.0.1）。关闭微端会回收本次拉起的 Node；请不要手动关无关的 Node 进程。
- 微端设置里可以改本机端口和地址后缀。后缀留空是根路径，填写后从 http://127.0.0.1:端口/后缀/ 进入。
- 左栏 / 顶栏会打开酒馆自己的抽屉（API、角色、世界书、扩展）。
- 左栏下方「微端设置」管理外壳，也可以把网页端酒馆的设置、预设、世界书、角色卡和第三方插件同步进来。不覆盖聊天记录和密钥文件。本地已有的插件目录不覆盖。
- 打开微端时会检查官方 SillyTavern release；可选择更新后再进入，或打开自动更新。
- 请保留 resources\\sillytavern\\.git，否则无法检查内核更新。
- 已内置酒馆助手（JS-Slash-Runner）和提示词模板（ST-Prompt-Template）。它们在 resources\\sillytavern\\public\\scripts\\extensions\\third-party\\，仍是上游 Git 仓库。扩展面板里可以检查更新、拉取上游或停用。请保留这两个目录里的 .git，否则失去原版更新渠道。内核更新不会清掉它们。
- 道渊日记是独立个人项目，不随 NEW 客户端安装或更新；需要时请自行在酒馆扩展面板安装，不要同时启用多个数据库版本。
- 中央视口的菜单（抽屉、弹窗、表单、按钮）已套道渊玄墨 / 发丝线 / 毛玻璃，与外壳一致。
- 微端设置里，字体上方的「流畅模式」默认关闭。打开后关掉聊天区毛玻璃和正文淡入，并把抓帧上限压到 30。
- 微端设置最后一项可换界面字体：微软雅黑、楷体、仿宋。默认微软雅黑，外壳和酒馆视口一起换。
- 角色卡、世界书、API、扩展请在中央酒馆视口中管理。
- 升级时会保留 runtime\\data（聊天、角色卡、密钥），不会清空用户数据。

SillyTavern 使用 AGPL-3.0，源码见 resources\\sillytavern。
`,
);

for (const rel of junk) wipe(rel);

console.log('portable ready:', dest);
console.log('builtAt', builtAt);
console.log(
  'exe', join(dest, '道渊微端.exe'),
  existsSync(join(dest, '道渊微端.exe')),
);
console.log('app.so', existsSync(join(dest, 'data/app.so')));
