/**
 * 检查或更新官方 SillyTavern release。
 * 对齐 SillyTavern-Launcher：git fetch，再 git pull，然后 npm install。
 * 不启动 server.js，不改 runtime/data。stdout 末行是 DAOYUAN_UPDATE_JSON。
 */
import { spawn, execFileSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

function arg(name, fallback = '') {
  const index = process.argv.indexOf(`--${name}`);
  if (index >= 0 && process.argv[index + 1]) return process.argv[index + 1];
  return fallback;
}

const mode = arg('mode', 'check');
const tavernRoot = resolve(arg('tavern'));
const runtimeRoot = resolve(arg('runtime') || join(tavernRoot, '..', '..', 'runtime'));
const nodeBin = arg('node');
const logFile = join(runtimeRoot, 'logs', 'update.log');

const gitEnv = {
  ...process.env,
  GIT_TERMINAL_PROMPT: '0',
  GCM_INTERACTIVE: 'Never',
};

function readWindowsProxy() {
  if (process.platform !== 'win32') return '';
  try {
    const out = execFileSync(
      'reg',
      ['query', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings'],
      { encoding: 'utf8', windowsHide: true },
    );
    const enabled = /ProxyEnable\s+REG_DWORD\s+0x([0-9a-f]+)/i.exec(out);
    if (!enabled || Number.parseInt(enabled[1], 16) === 0) return '';
    const server = /ProxyServer\s+REG_SZ\s+(\S+)/i.exec(out);
    return server ? server[1].trim() : '';
  } catch {
    return '';
  }
}

function toProxyUrl(raw) {
  if (!raw) return '';
  const https = /(?:^|;)https=([^;]+)/i.exec(raw);
  const http = /(?:^|;)http=([^;]+)/i.exec(raw);
  const socks = /(?:^|;)socks=([^;]+)/i.exec(raw);
  let value = '';
  let scheme = 'http://';
  if (https) value = https[1].trim();
  else if (http) value = http[1].trim();
  else if (socks) {
    value = socks[1].trim();
    scheme = 'socks5h://';
  } else if (!raw.includes('=')) value = raw.trim();
  if (!value || /^direct$/i.test(value)) return '';
  if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(value)) value = scheme + value;
  return value;
}

function applySystemProxy(env) {
  const existing = env.HTTPS_PROXY || env.https_proxy || env.HTTP_PROXY || env.http_proxy;
  if (existing) return String(existing);
  const url = toProxyUrl(readWindowsProxy());
  if (!url) return '';
  env.HTTP_PROXY = url;
  env.HTTPS_PROXY = url;
  env.http_proxy = url;
  env.https_proxy = url;
  return url;
}

function networkFailure(error) {
  const raw = String(error?.message || error).replace(/\s+/g, ' ').trim();
  const offline = /could not connect|failed to connect|timed out|connection refused|443/i.test(raw);
  if (!offline) return `无法连接官方 release：${raw}`;
  const via = gitEnv.https_proxy || gitEnv.HTTPS_PROXY;
  if (via) {
    return `连不上 GitHub。已使用系统代理 ${via}，请确认代理软件正在运行。`;
  }
  return '连不上 GitHub（443）。当前网络不能直连，且没有开启系统代理。';
}

function log(message) {
  const line = `[${new Date().toISOString()}] ${String(message).trimEnd()}\n`;
  try {
    mkdirSync(dirname(logFile), { recursive: true });
    appendFileSync(logFile, line);
  } catch {
    /* ignore */
  }
}

function emit(report) {
  process.stdout.write(`DAOYUAN_UPDATE_JSON ${JSON.stringify(report)}\n`);
}

function findGit() {
  const candidates = [
    process.env.DAOYUAN_GIT,
    'C:\\Program Files\\Git\\cmd\\git.exe',
    'C:\\Program Files\\Git\\bin\\git.exe',
  ].filter(Boolean);
  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  try {
    const cmd = process.platform === 'win32' ? 'where.exe' : 'which';
    const found = execFileSync(cmd, ['git'], { encoding: 'utf8', windowsHide: true })
      .split(/\r?\n/)
      .map((line) => line.trim())
      .find((line) => line && existsSync(line));
    if (found) return found;
  } catch {
    /* ignore */
  }
  return 'git';
}

function findNpm(nodePath) {
  const beside = nodePath ? join(dirname(nodePath), 'npm.cmd') : '';
  const cliBeside = nodePath
    ? join(dirname(nodePath), 'node_modules', 'npm', 'bin', 'npm-cli.js')
    : '';
  const candidates = [
    beside,
    cliBeside,
    'C:\\Program Files\\nodejs\\npm.cmd',
    'C:\\Program Files\\nodejs\\node_modules\\npm\\bin\\npm-cli.js',
  ].filter(Boolean);
  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  try {
    const found = execFileSync('where.exe', ['npm.cmd'], {
      encoding: 'utf8',
      windowsHide: true,
    })
      .split(/\r?\n/)
      .map((line) => line.trim())
      .find((line) => line && existsSync(line));
    if (found) return found;
  } catch {
    /* ignore */
  }
  return '';
}

function run(command, args, { cwd, timeoutMs, env }) {
  return new Promise((resolvePromise, reject) => {
    log(`$ ${command} ${args.join(' ')}`);
    const child = spawn(command, args, {
      cwd,
      env: env ?? process.env,
      windowsHide: true,
    });
    let out = '';
    let err = '';
    const timer = setTimeout(() => {
      child.kill();
      reject(new Error(`${command} ${args[0] ?? ''} 超时`));
    }, timeoutMs);
    child.stdout.on('data', (chunk) => {
      out += chunk;
    });
    child.stderr.on('data', (chunk) => {
      err += chunk;
    });
    child.on('error', (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.on('exit', (code) => {
      clearTimeout(timer);
      const text = `${out}${err}`.trim();
      if (text) log(text);
      if (code === 0) resolvePromise(out.trim());
      else reject(new Error(text || `${command} 退出码 ${code}`));
    });
  });
}

function readVersion() {
  try {
    const pkg = JSON.parse(readFileSync(join(tavernRoot, 'package.json'), 'utf8'));
    return String(pkg.version ?? '');
  } catch {
    return '';
  }
}

function blockingDirty(statusText) {
  const blocking = [];
  for (const raw of statusText.split(/\r?\n/)) {
    if (!raw.trim()) continue;
    const path = raw.slice(3).trim().replace(/\\/g, '/');
    if (path === 'package-lock.json') continue;
    blocking.push(raw.trim());
  }
  return blocking;
}

async function git(gitBin, args, timeoutMs) {
  return run(gitBin, args, { cwd: tavernRoot, timeoutMs, env: gitEnv });
}

async function inspect(gitBin) {
  const base = {
    version: readVersion(),
    branch: '',
    localSha: '',
    remoteSha: '',
    shallow: false,
    message: '',
  };
  if (!existsSync(join(tavernRoot, 'server.js'))) {
    return { ...base, phase: 'unavailable', message: '未找到酒馆内核（server.js）。' };
  }
  if (!existsSync(join(tavernRoot, '.git'))) {
    return {
      ...base,
      phase: 'unavailable',
      message: '内核目录没有 Git 仓库，无法对照官方 release。将使用当前内核。',
    };
  }
  try {
    base.branch = await git(gitBin, ['rev-parse', '--abbrev-ref', 'HEAD'], 20000);
    base.localSha = await git(gitBin, ['rev-parse', 'HEAD'], 20000);
    const shallow = await git(gitBin, ['rev-parse', '--is-shallow-repository'], 20000);
    base.shallow = shallow === 'true';
  } catch (error) {
    return {
      ...base,
      phase: 'unavailable',
      message: `无法读取本地内核：${error.message || error}`,
    };
  }
  try {
    await git(gitBin, ['fetch', 'origin', 'release'], 60000);
    base.remoteSha = await git(gitBin, ['rev-parse', 'origin/release'], 20000);
  } catch (error) {
    return {
      ...base,
      phase: 'unavailable',
      message: networkFailure(error),
    };
  }
  if (base.localSha && base.localSha === base.remoteSha && base.branch === 'release') {
    return { ...base, phase: 'up-to-date', message: '已与官方 release 一致。' };
  }
  return {
    ...base,
    phase: 'available',
    message: '官方 release 有新提交。',
  };
}

async function apply(gitBin) {
  const current = await inspect(gitBin);
  if (current.phase === 'unavailable') {
    return { ...current, phase: 'failed' };
  }
  if (current.phase === 'up-to-date') return current;

  let status = '';
  try {
    status = await git(gitBin, ['status', '--porcelain'], 20000);
  } catch (error) {
    return { ...current, phase: 'failed', message: `无法检查工作区：${error.message || error}` };
  }
  const blocking = blockingDirty(status);
  if (blocking.length > 0) {
    return {
      ...current,
      phase: 'failed',
      message: `内核目录有本地修改，已停止更新：${blocking.slice(0, 5).join('；')}`,
    };
  }
  if (status.includes('package-lock.json')) {
    try {
      await git(gitBin, ['checkout', '--', 'package-lock.json'], 20000);
    } catch (error) {
      return {
        ...current,
        phase: 'failed',
        message: `无法还原 package-lock.json：${error.message || error}`,
      };
    }
  }

  try {
    if (current.shallow) {
      log('浅克隆无法快进，正在补全历史');
      await git(gitBin, ['fetch', '--unshallow', 'origin'], 600000);
    }
    if (current.branch !== 'release') {
      await git(gitBin, ['switch', 'release'], 60000);
    }
    let pulled = false;
    let lastError = null;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        await git(gitBin, ['pull', '--ff-only', 'origin', 'release'], 180000);
        pulled = true;
        break;
      } catch (error) {
        lastError = error;
        log(`git pull 第 ${attempt} 次失败`);
      }
    }
    if (!pulled) {
      return {
        ...current,
        phase: 'failed',
        message: `更新失败：${lastError?.message || lastError}`,
      };
    }
  } catch (error) {
    return { ...current, phase: 'failed', message: `更新失败：${error.message || error}` };
  }

  const npm = findNpm(nodeBin);
  if (!npm) {
    return {
      ...current,
      phase: 'failed',
      message: '代码已更新，但找不到 npm，依赖未安装。',
    };
  }
  try {
    const npmArgs = [
      'install',
      '--no-save',
      '--no-audit',
      '--no-fund',
      '--loglevel=error',
      '--no-progress',
      '--omit=dev',
    ];
    if (npm.endsWith('npm-cli.js') && nodeBin && existsSync(nodeBin)) {
      await run(nodeBin, [npm, ...npmArgs], {
        cwd: tavernRoot,
        timeoutMs: 600000,
        env: { ...gitEnv, NODE_ENV: 'production' },
      });
    } else if (process.platform === 'win32') {
      const command = `"${npm}" ${npmArgs.join(' ')}`;
      await run('cmd.exe', ['/d', '/s', '/c', command], {
        cwd: tavernRoot,
        timeoutMs: 600000,
        env: { ...gitEnv, NODE_ENV: 'production' },
      });
    } else {
      await run(npm, npmArgs, {
        cwd: tavernRoot,
        timeoutMs: 600000,
        env: { ...gitEnv, NODE_ENV: 'production' },
      });
    }
  } catch (error) {
    return {
      ...current,
      phase: 'failed',
      message: `代码已更新，但依赖安装失败：${error.message || error}`,
    };
  }

  const next = await inspect(gitBin);
  if (next.phase === 'available') {
    return { ...next, phase: 'failed', message: '拉取后仍落后于官方 release。' };
  }
  if (next.phase === 'up-to-date') {
    return { ...next, phase: 'updated', message: '官方 release 已更新，依赖已安装。' };
  }
  return next.phase === 'failed'
    ? next
    : { ...next, phase: 'updated', message: next.message || '官方 release 已更新，依赖已安装。' };
}

const proxyInUse = applySystemProxy(gitEnv);
if (proxyInUse) log(`使用系统代理 ${proxyInUse}`);

const gitBin = findGit();
try {
  if (mode === 'apply') emit(await apply(gitBin));
  else emit(await inspect(gitBin));
} catch (error) {
  emit({
    phase: mode === 'apply' ? 'failed' : 'unavailable',
    version: '',
    branch: '',
    localSha: '',
    remoteSha: '',
    shallow: false,
    message: String(error?.message || error),
  });
}
