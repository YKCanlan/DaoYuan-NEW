/**
 * 把酒馆助手和提示词模板装进 SillyTavern 全局扩展目录。
 * 与酒馆扩展面板的安装相同：git clone --depth 1，origin 保持上游仓库。
 * 已有 manifest.json 的目录不覆盖，扩展面板的更新 / 换分支仍走原 remote。
 */
import { spawn, spawnSync, execFileSync } from 'node:child_process';
import {
  chmodSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmdirSync,
  unlinkSync,
} from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(here, '..');

export const builtinExtensions = [
  {
    title: '酒馆助手',
    url: 'https://github.com/N0VI028/JS-Slash-Runner.git',
  },
  {
    title: '提示词模板',
    url: 'https://github.com/zonde306/ST-Prompt-Template.git',
  },
];

export function extensionNameFromUrl(url) {
  const parsed = new URL(url);
  if (parsed.protocol !== 'https:' || parsed.hostname !== 'github.com') {
    throw new Error('内置扩展只允许 https://github.com 仓库。');
  }
  if (parsed.username || parsed.password) {
    throw new Error('内置扩展地址不能带账号。');
  }
  const segment = decodeURIComponent(parsed.pathname.split('/').filter(Boolean).pop() || '');
  const name = segment.replace(/\.git$/i, '');
  if (!/^[A-Za-z0-9._-]{1,80}$/.test(name)) {
    throw new Error(`扩展目录名无效：${name}`);
  }
  return name;
}

export function canonicalGithub(url) {
  let value = String(url || '').trim().replace(/\/$/, '');
  const ssh = /^git@github\.com:(.+)$/i.exec(value);
  if (ssh) value = `https://github.com/${ssh[1]}`;
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    return '';
  }
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return '';
  if (parsed.hostname.toLowerCase() !== 'github.com') return '';
  const parts = parsed.pathname.split('/').filter(Boolean);
  if (parts.length < 2) return '';
  const repo = parts[1].replace(/\.git$/i, '');
  if (!repo) return '';
  return `https://github.com/${parts[0]}/${repo}`.toLowerCase();
}

export function isOfficialRemote(actual, expected) {
  const left = canonicalGithub(actual);
  const right = canonicalGithub(expected);
  return Boolean(left) && left === right;
}

export function planBuiltinInstall(hasManifest) {
  return hasManifest ? 'keep' : 'clone';
}

export function channelIntact(action) {
  return action === 'cloned' || action === 'kept';
}

function isInside(parent, target) {
  const rel = relative(resolve(parent), resolve(target));
  return rel !== '' && !rel.startsWith('..') && !isAbsolute(rel);
}

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
  return '';
}

function killPid(pid) {
  if (!pid) return;
  if (process.platform === 'win32') {
    spawnSync('taskkill', ['/PID', String(pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' });
    return;
  }
  try {
    process.kill(pid);
  } catch {
    /* ignore */
  }
}

function rimraf(target) {
  if (!existsSync(target)) return;
  const st = lstatSync(target);
  if (st.isSymbolicLink()) {
    unlinkSync(target);
    return;
  }
  if (st.isDirectory()) {
    for (const name of readdirSync(target)) rimraf(join(target, name));
    rmdirSync(target);
    return;
  }
  try {
    chmodSync(target, 0o666);
  } catch {
    /* ignore */
  }
  unlinkSync(target);
}

function runGit(gitBin, args, { cwd, timeoutMs, env }) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(gitBin, args, {
      cwd,
      env,
      windowsHide: true,
    });
    let out = '';
    let err = '';
    const timer = setTimeout(() => {
      killPid(child.pid);
      reject(new Error(`git 超时：${args.filter((part) => part !== '-c' && !part.startsWith('core.')).slice(0, 3).join(' ')}`));
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
      if (code === 0) resolvePromise(out.trim());
      else reject(new Error((`${err}\n${out}`).trim() || `git 退出码 ${code}`));
    });
  });
}

function networkHint(error, proxy) {
  const raw = String(error?.message || error).replace(/\s+/g, ' ').trim();
  const offline = /could not connect|failed to connect|timed out|connection refused|443|git 超时/i.test(raw);
  if (!offline) return raw;
  if (proxy) return `连不上 GitHub。已使用代理 ${proxy}。${raw}`;
  return `连不上 GitHub。${raw}`;
}

function readManifestEntry(dir) {
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(join(dir, 'manifest.json'), 'utf8'));
  } catch (error) {
    return { ok: false, message: `manifest.json 无法解析：${error.message || error}` };
  }
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
    return { ok: false, message: 'manifest.json 不是对象。' };
  }
  const js = String(manifest.js || '').replace(/\\/g, '/').trim();
  if (!js || js.includes('..') || js.startsWith('/') || !existsSync(join(dir, js))) {
    return { ok: false, message: 'manifest 的 js 入口不存在，不本地构建以免弄脏更新。' };
  }
  const css = String(manifest.css || '').replace(/\\/g, '/').trim();
  if (css && (css.includes('..') || css.startsWith('/') || !existsSync(join(dir, css)))) {
    return { ok: false, message: 'manifest 的 css 入口不存在。' };
  }
  return {
    ok: true,
    version: String(manifest.version || ''),
    display: String(manifest.display_name || ''),
  };
}

async function readOrigin(gitBin, dir, env, timeoutMs) {
  if (!existsSync(join(dir, '.git'))) return '';
  try {
    return await runGit(gitBin, ['-C', dir, 'remote', 'get-url', 'origin'], {
      timeoutMs: Math.min(timeoutMs, 20000),
      env,
    });
  } catch {
    return '';
  }
}

async function installOne(spec, { thirdParty, gitBin, env, timeoutMs, proxy }) {
  const name = extensionNameFromUrl(spec.url);
  const dest = resolve(thirdParty, name);
  const base = {
    name,
    title: spec.title,
    url: spec.url,
    action: 'failed',
    version: '',
    sha: '',
    remote: '',
    message: '',
  };
  if (!isInside(thirdParty, dest)) {
    return { ...base, message: '扩展目录超出全局扩展路径。' };
  }
  if (existsSync(dest) && lstatSync(dest).isSymbolicLink()) {
    return { ...base, message: '扩展路径是符号链接，已拒绝。' };
  }

  const hasManifest = existsSync(join(dest, 'manifest.json'));
  if (planBuiltinInstall(hasManifest) === 'keep') {
    const remote = await readOrigin(gitBin, dest, env, timeoutMs);
    const entry = readManifestEntry(dest);
    let action = 'kept';
    let message = '已存在，保留现有目录和更新渠道。';
    if (!remote) {
      action = 'kept-no-git';
      message = '已有文件，但没有 Git 仓库，扩展面板无法对照上游更新。未覆盖。';
    } else if (!isOfficialRemote(remote, spec.url)) {
      action = 'kept-foreign';
      message = `已有仓库的 origin 不是上游（${remote}），未改 remote。`;
    }
    if (!entry.ok) message = `${message} ${entry.message}`;
    return {
      ...base,
      action,
      version: entry.version || '',
      remote,
      message,
    };
  }

  if (!gitBin) {
    return { ...base, message: '未找到 Git，无法克隆上游仓库。' };
  }

  if (existsSync(dest)) rimraf(dest);
  try {
    await runGit(
      gitBin,
      [
        '-c', 'core.longpaths=true',
        '-c', 'core.autocrlf=false',
        'clone',
        '--depth', '1',
        '--',
        spec.url,
        dest,
      ],
      { cwd: thirdParty, timeoutMs, env },
    );
    const remote = await readOrigin(gitBin, dest, env, timeoutMs);
    if (!isOfficialRemote(remote, spec.url)) {
      throw new Error(`克隆后的 origin 不是上游：${remote || '空'}`);
    }
    const entry = readManifestEntry(dest);
    if (!entry.ok) throw new Error(entry.message);
    let sha = '';
    try {
      sha = await runGit(gitBin, ['-C', dest, 'rev-parse', '--short=7', 'HEAD'], {
        timeoutMs: Math.min(timeoutMs, 20000),
        env,
      });
    } catch {
      sha = '';
    }
    return {
      ...base,
      action: 'cloned',
      version: entry.version,
      sha,
      remote,
      message: `已从上游浅克隆${entry.display ? `（${entry.display} ${entry.version}）` : ''}。`,
    };
  } catch (error) {
    if (existsSync(dest)) {
      try {
        rimraf(dest);
      } catch {
        /* 留下的残目录下次会再试 */
      }
    }
    return { ...base, message: networkHint(error, proxy) };
  }
}

export async function ensureBuiltinExtensions(options = {}) {
  const tavernRoot = resolve(options.tavernRoot || join(projectRoot, 'resources', 'sillytavern'));
  const thirdParty = join(tavernRoot, 'public', 'scripts', 'extensions', 'third-party');
  const timeoutMs = options.timeoutMs ?? 90000;
  const strict = options.strict === true;
  const log = typeof options.log === 'function' ? options.log : () => {};
  mkdirSync(thirdParty, { recursive: true });

  const env = {
    ...process.env,
    GIT_TERMINAL_PROMPT: '0',
    GCM_INTERACTIVE: 'Never',
  };
  const proxy = applySystemProxy(env);
  const gitBin = findGit();
  if (proxy) log(`内置扩展使用代理 ${proxy}`);
  if (!gitBin) log('未找到 Git，无法克隆内置扩展。');

  const results = await Promise.all(builtinExtensions.map((spec) => installOne(spec, {
    thirdParty,
    gitBin,
    env,
    timeoutMs,
    proxy,
  })));
  for (const row of results) {
    log(`内置扩展 ${row.title}（${row.name}）：${row.action} ${row.message}`);
  }
  const ok = results.every((row) => row.action !== 'failed' && (!strict || channelIntact(row.action)));
  return { ok, strict, results };
}

function selfTest() {
  const assert = (cond, message) => {
    if (!cond) throw new Error(message);
  };
  assert(extensionNameFromUrl(builtinExtensions[0].url) === 'JS-Slash-Runner', 'jsr name');
  assert(extensionNameFromUrl(builtinExtensions[1].url) === 'ST-Prompt-Template', 'spt name');
  assert(builtinExtensions.every((spec) => spec.url.startsWith('https://github.com/')), 'https only');
  assert(isOfficialRemote(
    'git@github.com:N0VI028/JS-Slash-Runner.git',
    'https://github.com/N0VI028/JS-Slash-Runner.git',
  ), 'ssh remote');
  assert(isOfficialRemote(
    'https://github.com/zonde306/ST-Prompt-Template',
    'https://github.com/zonde306/ST-Prompt-Template.git',
  ), 'no .git suffix');
  assert(!isOfficialRemote('https://github.com/evil/JS-Slash-Runner.git', builtinExtensions[0].url), 'foreign');
  assert(!isOfficialRemote('https://example.com/N0VI028/JS-Slash-Runner.git', builtinExtensions[0].url), 'host');
  assert(planBuiltinInstall(true) === 'keep', 'keep manifest');
  assert(planBuiltinInstall(false) === 'clone', 'clone missing');
  assert(channelIntact('cloned') && channelIntact('kept'), 'channel');
  assert(!channelIntact('kept-no-git') && !channelIntact('kept-foreign') && !channelIntact('failed'), 'broken channel');
  let rejected = false;
  try {
    extensionNameFromUrl('https://user:pass@github.com/N0VI028/JS-Slash-Runner.git');
  } catch {
    rejected = true;
  }
  assert(rejected, 'credentials rejected');
  console.log('ensure-builtin-extensions self-test ok');
}

function arg(name, fallback = '') {
  const index = process.argv.indexOf(`--${name}`);
  if (index >= 0 && process.argv[index + 1]) return process.argv[index + 1];
  return fallback;
}

function invokedDirectly() {
  const entry = process.argv[1];
  if (!entry) return false;
  try {
    return import.meta.url === pathToFileURL(resolve(entry)).href;
  } catch {
    return false;
  }
}

if (invokedDirectly()) {
  if (process.argv.includes('--self-test')) {
    selfTest();
  } else {
    const report = await ensureBuiltinExtensions({
      tavernRoot: arg('tavern') || undefined,
      timeoutMs: Number(arg('timeoutMs') || 600000),
      strict: !process.argv.includes('--loose'),
      log: (message) => console.log(message),
    });
    console.log(`DAOYUAN_EXTENSIONS_JSON ${JSON.stringify(report)}`);
    if (!report.ok) process.exitCode = 1;
  }
}
