/**
 * 启动隔离 SillyTavern。对应旧 PC 微端 host:start。
 * 仅监听 127.0.0.1，数据写在 runtime/，不打开系统浏览器。
 * 父进程退出后用 taskkill 收掉整棵进程树。
 */
import { createServer } from 'node:net';
import { spawn, spawnSync } from 'node:child_process';
import { appendFileSync, existsSync, openSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { access, mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { normalizeSuffix } = require('./url-suffix.cjs');
const { ensureBuiltinExtensions } = await import('./ensure-builtin-extensions.mjs');

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');

function arg(name, fallback = '') {
  const index = process.argv.indexOf(`--${name}`);
  if (index >= 0 && process.argv[index + 1]) return process.argv[index + 1];
  return fallback;
}

const runtimeRoot = resolve(
  arg('runtime') || process.env.DAOYUAN_RUNTIME_ROOT || join(root, 'runtime'),
);
const tavernRoot = resolve(
  arg('tavern') ||
    process.env.DAOYUAN_SILLYTAVERN_ROOT ||
    join(root, 'resources', 'sillytavern'),
);
const dataRoot = resolve(process.env.DAOYUAN_DATA_ROOT || join(runtimeRoot, 'data'));
const configPath = resolve(join(runtimeRoot, 'config.yaml'));
const parentPid = Number(arg('parentPid') || process.env.DAOYUAN_PARENT_PID || 0);
const requestedPort = Number(arg('port') || process.env.DAOYUAN_TAVERN_PORT || 8100);
const urlSuffix = normalizeSuffix(arg('urlSuffix') || process.env.DAOYUAN_URL_SUFFIX || '');
const lockPath = join(runtimeRoot, 'host.lock');

async function exists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

function pickPort(preferred) {
  return new Promise((resolvePromise, reject) => {
    const server = createServer();
    server.unref();
    server.on('error', () => {
      const fallback = createServer();
      fallback.unref();
      fallback.on('error', reject);
      fallback.listen(0, '127.0.0.1', () => {
        const address = fallback.address();
        const port = typeof address === 'object' && address ? address.port : 0;
        fallback.close(() => resolvePromise(port));
      });
    });
    server.listen(preferred, '127.0.0.1', () => {
      const address = server.address();
      const port = typeof address === 'object' && address ? address.port : preferred;
      server.close(() => resolvePromise(port));
    });
  });
}

function isPidAlive(pid) {
  if (!pid || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    const code = error && error.code;
    if (code === 'EPERM' || code === 'EACCES') return true;
    return false;
  }
}

function killTree(pid) {
  if (!pid || pid <= 0 || pid === process.pid) return;
  if (process.platform === 'win32') {
    spawnSync('taskkill', ['/PID', String(pid), '/T', '/F'], {
      windowsHide: true,
      stdio: 'ignore',
    });
    return;
  }
  try {
    process.kill(pid, 'SIGTERM');
  } catch {
    /* ignore */
  }
}

function norm(value) {
  return String(value || '').replaceAll('/', '\\').toLowerCase();
}

function reapStaleNodes() {
  if (process.platform !== 'win32') return;
  const markers = [
    configPath,
    dataRoot,
    join(here, 'start-tavern.mjs'),
    join(here, 'update-tavern.mjs'),
    join(here, 'sync-remote-tavern.mjs'),
    join(here, 'windows-safe-cp.cjs'),
    join(here, 'url-suffix.cjs'),
  ].map(norm);
  const dump = join(runtimeRoot, 'logs', `reap-${process.pid}.json`);
  const dumpPs = dump.replaceAll("'", "''");
  const script = `
$ErrorActionPreference = 'SilentlyContinue'
$rows = @()
Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" | ForEach-Object {
  $rows += [PSCustomObject]@{ pid = [int]$_.ProcessId; cmd = [string]$_.CommandLine }
}
$rows | ConvertTo-Json -Compress | Out-File -FilePath '${dumpPs}' -Encoding utf8
`;
  try {
    spawnSync(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      { windowsHide: true, stdio: 'ignore', timeout: 20000 },
    );
    if (!existsSync(dump)) return;
    let text = readFileSync(dump, 'utf8').replace(/^\uFEFF/, '').trim();
    if (!text || text === 'null') return;
    const decoded = JSON.parse(text);
    const rows = Array.isArray(decoded) ? decoded : [decoded];
    for (const row of rows) {
      const processId = Number(row && row.pid);
      const cmd = norm(row && row.cmd);
      if (!processId || processId === process.pid || processId === parentPid) continue;
      if (markers.some((marker) => marker && cmd.includes(marker))) killTree(processId);
    }
  } catch {
    /* 回收失败不阻止启动 */
  } finally {
    try {
      if (existsSync(dump)) unlinkSync(dump);
    } catch {
      /* ignore */
    }
  }
}

function patchHostConfig(config, { dataRoot: nextDataRoot, port: nextPort }) {
  let next = config.replace(/^listen:.*$/m, 'listen: false');
  next = next.replace(
    /(browserLaunch:\s*\n(?:[ \t]+.*\n)*?[ \t]+enabled:\s*)true/m,
    '$1false',
  );
  if (nextDataRoot) {
    next = next.replace(
      /^dataRoot:.*$/m,
      `dataRoot: ${String(nextDataRoot).replaceAll('\\', '/')}`,
    );
  }
  if (nextPort) {
    next = next.replace(/^port:\s*\d+.*$/m, `port: ${nextPort}`);
  }
  return next;
}

await mkdir(runtimeRoot, { recursive: true });
await mkdir(join(runtimeRoot, 'logs'), { recursive: true });

if (existsSync(lockPath)) {
  const other = Number(readFileSync(lockPath, 'utf8'));
  if (other && other !== process.pid && isPidAlive(other)) {
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 800));
    const again = existsSync(lockPath) ? Number(readFileSync(lockPath, 'utf8')) : 0;
    if (again && again !== process.pid && isPidAlive(again)) {
      console.log(`already starting pid ${again}`);
      process.exit(0);
    }
  }
}
writeFileSync(lockPath, String(process.pid));
const releaseLock = () => {
  try {
    if (existsSync(lockPath) && readFileSync(lockPath, 'utf8').trim() === String(process.pid)) {
      unlinkSync(lockPath);
    }
  } catch {
    /* ignore */
  }
};
process.on('exit', releaseLock);

reapStaleNodes();

if (!(await exists(join(tavernRoot, 'server.js')))) {
  throw new Error(
    `找不到 SillyTavern：${join(tavernRoot, 'server.js')}。请先运行 npm run setup。`,
  );
}

await mkdir(dataRoot, { recursive: true });

if (!(await exists(configPath))) {
  const templateCandidates = [
    join(tavernRoot, 'config.yaml'),
    join(tavernRoot, 'default', 'config.yaml'),
  ];
  const templatePath = templateCandidates.find((path) => existsSync(path));
  if (!templatePath) {
    throw new Error('找不到 SillyTavern 默认 config.yaml。');
  }
  let config = await readFile(templatePath, 'utf8');
  config = patchHostConfig(config, { dataRoot, port: requestedPort });
  await writeFile(configPath, config, 'utf8');
} else {
  const existing = await readFile(configPath, 'utf8');
  const patched = patchHostConfig(existing, { dataRoot: null, port: null });
  if (patched !== existing) {
    await writeFile(configPath, patched, 'utf8');
  }
}

const port = await pickPort(requestedPort);
const url = urlSuffix
  ? `http://127.0.0.1:${port}/${urlSuffix}/`
  : `http://127.0.0.1:${port}/`;
const logFile = join(runtimeRoot, 'logs', 'tavern.log');
const handshakePath = join(runtimeRoot, 'host.json');

const nodeBin = process.execPath;
const safeCp = join(here, 'windows-safe-cp.cjs');
const suffixHook = join(here, 'url-suffix.cjs');
const args = [
  '--require',
  suffixHook,
  ...(process.platform === 'win32' ? ['--require', safeCp] : []),
  'server.js',
  '--configPath',
  configPath,
  '--dataRoot',
  dataRoot,
  '--port',
  String(port),
  '--listen',
  'false',
  '--browserLaunchEnabled',
  'false',
];

const showConsole = ['1', 'true', 'TRUE', 'yes', 'YES'].includes(
  String(process.env.DAOYUAN_HOST_CONSOLE || ''),
);

const logFd = openSync(logFile, 'a');
const stamp = `[${new Date().toISOString()}] start ${nodeBin} ${args.join(' ')}\n`;
await writeFile(logFile, stamp, { flag: 'a' });

try {
  await ensureBuiltinExtensions({
    tavernRoot,
    timeoutMs: 90000,
    strict: false,
    log: (message) => {
      const line = `[${new Date().toISOString()}] ${message}\n`;
      try {
        appendFileSync(logFile, line);
      } catch {
        /* ignore */
      }
      console.log(message);
    },
  });
} catch (error) {
  const line = `[${new Date().toISOString()}] 内置扩展：${error?.message || error}\n`;
  try {
    appendFileSync(logFile, line);
  } catch {
    /* ignore */
  }
}

const childEnv = { ...process.env, NODE_ENV: 'production' };
delete childEnv.NODE_OPTIONS;
delete childEnv.NODE_INSPECT;
delete childEnv.NODE_DEBUG;
childEnv.DAOYUAN_TAVERN_PORT = String(port);
if (urlSuffix) childEnv.DAOYUAN_URL_SUFFIX = urlSuffix;
else delete childEnv.DAOYUAN_URL_SUFFIX;

const child = spawn(nodeBin, args, {
  cwd: tavernRoot,
  windowsHide: !showConsole,
  env: childEnv,
  stdio: showConsole ? 'inherit' : ['ignore', logFd, logFd],
});

const handshake = {
  pid: child.pid ?? 0,
  wrapperPid: process.pid,
  port,
  url,
  urlSuffix,
  dataRoot,
  tavernRoot,
  startedAt: new Date().toISOString(),
};
await writeFile(handshakePath, `${JSON.stringify(handshake, null, 2)}\n`, 'utf8');

let stopping = false;
let timer = null;
function logLine(message) {
  try {
    appendFileSync(logFile, `[${new Date().toISOString()}] ${message}\n`);
  } catch {
    /* ignore */
  }
}

function stop() {
  if (stopping) return;
  stopping = true;
  if (timer) clearInterval(timer);
  logLine(`stop wrapper ${process.pid} child ${child.pid ?? 0}`);
  killTree(child.pid);
  releaseLock();
  process.exit(0);
}

process.once('SIGINT', stop);
process.once('SIGTERM', stop);

child.on('exit', (code) => {
  logLine(`tavern exit ${code ?? 0}`);
  if (!stopping) {
    stopping = true;
    clearInterval(timer);
    releaseLock();
    process.exit(code ?? 0);
  }
});

timer = setInterval(() => {
  if (parentPid > 0 && !isPidAlive(parentPid)) {
    logLine(`parent ${parentPid} gone; stop`);
    stop();
  }
}, 1000);

console.log(`SillyTavern ${url}`);
console.log(`dataRoot ${dataRoot}`);
console.log(`pid ${child.pid}`);
