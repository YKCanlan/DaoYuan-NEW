/**
 * 从网页端 SillyTavern 拉取设置、预设、世界书、角色卡和第三方插件，写入本机 runtime/data。
 * 不改酒馆源码，不覆盖聊天和 secrets.json。已有插件目录不覆盖。
 * 内置全局扩展已有同名 manifest 时，不再克隆一份到用户目录。
 * 凭据只从 stdin 读入，不进参数、不进日志。
 */
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, statSync, copyFileSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const bundledThirdParty = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  'resources',
  'sillytavern',
  'public',
  'scripts',
  'extensions',
  'third-party',
);

const MAX_BODY = 50 * 1024 * 1024;
const MAX_PRESETS = 500;
const MAX_WORLDS = 500;
const MAX_CHARACTERS = 500;
const MAX_EXTENSIONS = 40;
const RESERVED = /^(con|prn|aux|nul|com[1-9]|lpt[1-9])$/i;

function emptySynced() {
  return {
    settings: false,
    presets: 0,
    worldInfo: 0,
    characters: 0,
    extensions: 0,
    extensionsSkipped: 0,
  };
}

function emit(report) {
  process.stdout.write(`DAOYUAN_SYNC_JSON ${JSON.stringify(report)}\n`);
}

function explain(error) {
  const name = error?.name || error?.cause?.name;
  if (name === 'AbortError' || name === 'TimeoutError') return '连接网页端超时。';
  const code = error?.cause?.code || error?.code;
  if (code === 'ENOTFOUND' || code === 'ECONNREFUSED' || code === 'EHOSTUNREACH' || code === 'ECONNRESET') {
    return `无法连接网页端（${code}）。`;
  }
  return error instanceof Error ? error.message : String(error);
}

export function safeName(value, fallback = 'imported') {
  const cleaned = String(value || fallback)
    .replace(/[<>:"/\\|?*\u0000-\u001f]/g, '_')
    .replace(/\.+$/g, '')
    .trim();
  let name = (cleaned || fallback).slice(0, 180);
  if (name === '.' || name === '..') name = fallback;
  if (RESERVED.test(name)) name = `${fallback}-${name}`;
  return name;
}

export function isInside(parent, target) {
  const rel = relative(resolve(parent), resolve(target));
  return rel === '' || (!rel.startsWith('..') && !isAbsolute(rel));
}

export function worldNamesFromList(listed) {
  const rows = Array.isArray(listed)
    ? listed
    : (listed && typeof listed === 'object' && Array.isArray(listed.worlds) ? listed.worlds : []);
  const names = [];
  const seen = new Set();
  for (const item of rows) {
    let raw = '';
    if (typeof item === 'string') raw = item;
    else if (item && typeof item === 'object') raw = item.file_id || item.name || '';
    const stem = String(raw).trim().replace(/\.json$/i, '');
    if (!stem || stem.includes('..') || seen.has(stem) || safeName(stem) !== stem) continue;
    seen.add(stem);
    names.push(stem);
  }
  return names;
}

export function characterFileName(avatar) {
  const base = String(avatar || '').split(/[/\\]/).pop() || '';
  if (!base.toLowerCase().endsWith('.png')) return '';
  const stem = base.slice(0, -4);
  if (!stem || stem === '.' || stem === '..' || safeName(stem) !== stem) return '';
  return `${stem}.png`;
}

export function extensionFolderName(name) {
  const raw = String(name || '').trim();
  const folder = raw.startsWith('third-party/') ? raw.slice('third-party/'.length) : raw;
  if (!folder || folder.includes('/') || folder.includes('\\') || folder.includes('..')) return '';
  if (folder.startsWith('.') || safeName(folder) !== folder) return '';
  return folder;
}

export function gitCloneUrl(value) {
  let url;
  try {
    url = new URL(String(value || '').trim());
  } catch {
    return '';
  }
  if (!['http:', 'https:'].includes(url.protocol) || !url.hostname) return '';
  if (url.username || url.password) return '';
  return url.href;
}

function gitBranch(value) {
  const branch = String(value || '').trim();
  if (!branch || branch.startsWith('-') || branch.includes('..') || !/^[A-Za-z0-9._/-]+$/.test(branch)) return '';
  return branch;
}

function isPng(buffer) {
  return buffer.length >= 8
    && buffer[0] === 0x89
    && buffer[1] === 0x50
    && buffer[2] === 0x4e
    && buffer[3] === 0x47;
}

export function parseRemote(input, token, username, password) {
  let remote;
  try {
    remote = new URL(String(input || '').trim());
  } catch {
    return { error: '网页端酒馆地址无效。' };
  }
  if (!['http:', 'https:'].includes(remote.protocol)) {
    return { error: '只支持 http/https 网页端酒馆地址。' };
  }
  const urlUsername = remote.username ? decodeURIComponent(remote.username) : '';
  const urlPassword = remote.password ? decodeURIComponent(remote.password) : '';
  remote.username = '';
  remote.password = '';
  remote.hash = '';
  remote.search = '';
  remote.pathname = remote.pathname.replace(/\/+$/, '');
  const baseUrl = remote.toString().replace(/\/$/, '');
  const basicUsername = String(username || '').trim() || urlUsername;
  const basicPassword = typeof password === 'string' && password.length > 0 ? password : urlPassword;
  const bearer = String(token || '').trim();
  const authorizationHeaders = basicUsername
    ? { Authorization: `Basic ${Buffer.from(`${basicUsername}:${basicPassword}`, 'utf8').toString('base64')}` }
    : (bearer ? { Authorization: `Bearer ${bearer}` } : {});
  return { baseUrl, origin: remote.origin, authorizationHeaders };
}

function readHandles(dataRoot) {
  const storage = join(dataRoot, '_storage');
  if (!existsSync(storage)) return [];
  const handles = new Set();
  for (const name of readdirSync(storage)) {
    const file = join(storage, name);
    let info;
    try {
      info = statSync(file);
    } catch {
      continue;
    }
    if (!info.isFile() || info.size > 1024 * 1024) continue;
    let text = '';
    try {
      text = readFileSync(file, 'utf8');
    } catch {
      continue;
    }
    if (!text.includes('user:')) continue;
    try {
      const parsed = JSON.parse(text);
      const key = typeof parsed?.key === 'string' ? parsed.key : '';
      if (key.startsWith('user:')) handles.add(key.slice('user:'.length));
    } catch {
      const match = text.match(/"key"\s*:\s*"user:([^"]+)"/);
      if (match?.[1]) handles.add(match[1]);
    }
  }
  return [...handles];
}

export function resolveUserRoot(dataRoot) {
  if (!existsSync(dataRoot)) {
    throw new Error('还没有本地酒馆数据。请先进入一次酒馆，再同步。');
  }
  const stored = readHandles(dataRoot).filter((handle) => existsSync(join(dataRoot, handle)));
  let handle = '';
  if (stored.length === 1) handle = stored[0];
  else if (stored.includes('default-user')) handle = 'default-user';
  else if (stored.length > 1) {
    throw new Error('本地有多个酒馆用户。同步写入 default-user；当前没有这个用户目录。');
  } else {
    const dirs = readdirSync(dataRoot, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && !entry.name.startsWith('_') && !entry.name.startsWith('.'))
      .map((entry) => entry.name)
      .filter((name) => existsSync(join(dataRoot, name, 'settings.json')));
    if (dirs.length === 1) handle = dirs[0];
    else if (dirs.includes('default-user')) handle = 'default-user';
  }
  if (!handle) throw new Error('还没有本地酒馆用户。请先进入一次酒馆，再同步。');
  const root = resolve(dataRoot, handle);
  if (!isInside(dataRoot, root) || !existsSync(join(root, 'settings.json'))) {
    throw new Error('本地酒馆设置尚未生成。请先进入一次酒馆，再同步。');
  }
  return { root, handle };
}

function userDirectories(root) {
  return {
    root,
    backups: join(root, 'backups'),
    openAI_Settings: join(root, 'OpenAI Settings'),
    novelAI_Settings: join(root, 'NovelAI Settings'),
    textGen_Settings: join(root, 'TextGen Settings'),
    koboldAI_Settings: join(root, 'KoboldAI Settings'),
    instruct: join(root, 'instruct'),
    context: join(root, 'context'),
    sysprompt: join(root, 'sysprompt'),
    reasoning: join(root, 'reasoning'),
    worlds: join(root, 'worlds'),
    characters: join(root, 'characters'),
    extensions: join(root, 'extensions'),
  };
}

function rememberCookies(jar, result) {
  const values = typeof result.headers.getSetCookie === 'function'
    ? result.headers.getSetCookie()
    : (result.headers.get('set-cookie') ? [result.headers.get('set-cookie')] : []);
  for (const value of values) {
    const pair = String(value).split(';', 1)[0];
    const separator = pair.indexOf('=');
    if (separator > 0) jar.set(pair.slice(0, separator).trim(), pair.slice(separator + 1).trim());
  }
}

function cookieHeader(jar) {
  return [...jar.entries()].map(([name, value]) => `${name}=${value}`).join('; ');
}

function replaceFile(target, temporary) {
  if (!existsSync(target)) {
    renameSync(temporary, target);
    return;
  }
  const aside = `${target}.daoyuan-sync-aside-${process.pid}`;
  renameSync(target, aside);
  try {
    renameSync(temporary, target);
  } catch (error) {
    try {
      renameSync(aside, target);
    } catch {
      /* 原文件留在 aside，交给上层报错 */
    }
    throw error;
  }
  rmSync(aside, { force: true });
}

function atomicWrite(target, content, temporaryFiles, parent) {
  if (!isInside(parent, target)) throw new Error('拒绝写入数据目录之外的路径。');
  mkdirSync(resolve(target, '..'), { recursive: true });
  const temporary = `${target}.daoyuan-sync-${process.pid}-${Math.random().toString(16).slice(2)}`;
  temporaryFiles.push(temporary);
  writeFileSync(temporary, content);
  replaceFile(target, temporary);
  const index = temporaryFiles.indexOf(temporary);
  if (index >= 0) temporaryFiles.splice(index, 1);
}

function backupExisting(target, userRoot, backupRoot) {
  if (!existsSync(target)) return;
  const rel = relative(userRoot, target);
  if (!rel || rel.startsWith('..') || isAbsolute(rel)) return;
  const backup = join(backupRoot, rel);
  if (!isInside(backupRoot, backup)) return;
  mkdirSync(resolve(backup, '..'), { recursive: true });
  copyFileSync(target, backup);
}

async function readLimited(result, route) {
  const text = await result.text();
  if (text.length > MAX_BODY) throw new Error(`${route} 响应超过 50MB。`);
  return text;
}

function selfTest() {
  const named = safeName('a/../../b:c');
  if (named.includes('/') || named.includes('\\') || named.includes(':')) {
    throw new Error(`safeName failed: ${named}`);
  }
  if (safeName('..') === '..' || safeName('CON') === 'CON') throw new Error('safeName reserved');
  const remote = parseRemote('http://user:secret@127.0.0.1:8000/foo/', '', '', '');
  if (remote.error || remote.baseUrl !== 'http://127.0.0.1:8000/foo') {
    throw new Error(`parseRemote base: ${remote.baseUrl || remote.error}`);
  }
  if (!remote.authorizationHeaders.Authorization?.startsWith('Basic ')) {
    throw new Error('parseRemote basic auth missing');
  }
  const rejected = parseRemote('file:///c:/windows', '', '', '');
  if (!rejected.error) throw new Error('file url should fail');
  const parent = resolve('runtime/data/default-user/worlds');
  if (isInside(parent, resolve(parent, '..', '..', 'secrets.json'))) {
    throw new Error('isInside allowed escape');
  }
  const worlds = worldNamesFromList([
    { file_id: '酒馆', name: '忽略' },
    '旧世界.json',
    { name: '../逃逸' },
    'CON',
  ]);
  if (worlds.join('|') !== '酒馆|旧世界') throw new Error(`worldNamesFromList: ${worlds.join(',')}`);
  if (characterFileName('角色.png') !== '角色.png') throw new Error('character png');
  if (characterFileName('a/../../b.png') !== 'b.png') throw new Error('character basename');
  if (characterFileName('notes.txt') || characterFileName('CON.png')) throw new Error('character rejected');
  if (extensionFolderName('third-party/my-ext') !== 'my-ext') throw new Error('extension folder');
  if (extensionFolderName('third-party/../x') || extensionFolderName('a/b')) throw new Error('extension rejected');
  if (gitCloneUrl('https://github.com/a/b.git') !== 'https://github.com/a/b.git') throw new Error('git url');
  if (gitCloneUrl('file:///tmp/x') || gitCloneUrl('https://user:pw@github.com/a/b.git')) {
    throw new Error('git url should reject');
  }
  emit({ ok: true, selfTest: true });
}

async function run(temporaryFiles) {
  const raw = await new Promise((resolvePromise, reject) => {
    const chunks = [];
    let size = 0;
    process.stdin.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1024 * 1024) {
        reject(new Error('同步请求过大。'));
        return;
      }
      chunks.push(chunk);
    });
    process.stdin.on('end', () => resolvePromise(Buffer.concat(chunks).toString('utf8')));
    process.stdin.on('error', reject);
  });
  let input;
  try {
    input = JSON.parse(raw || '{}');
  } catch {
    throw new Error('同步请求不是有效 JSON。');
  }
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new Error('同步请求格式无效。');
  }
  const mode = input.mode === 'check' || input.mode === 'sync' ? input.mode : '';
  if (!mode) throw new Error('未知同步模式。');
  const remote = parseRemote(input.remoteUrl, input.token, input.username, input.password);
  if (remote.error) throw new Error(remote.error);

  const runtimeRoot = resolve(String(input.runtime || process.env.DAOYUAN_RUNTIME_ROOT || join(process.cwd(), 'runtime')));
  const dataRoot = resolve(String(input.dataRoot || process.env.DAOYUAN_DATA_ROOT || join(runtimeRoot, 'data')));
  const timeoutMs = mode === 'check' ? 20000 : 600000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const errors = [];
  const synced = emptySynced();
  const gitChildren = new Set();
  let backupName = null;
  let userHandle = null;

  const jar = new Map();
  let remoteCsrfToken = '';

  const ensureRemoteSession = async () => {
    if (remoteCsrfToken) return;
    const result = await fetch(`${remote.baseUrl}/csrf-token`, {
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 DaoYuan-Mini-Client/remote-sync',
        ...remote.authorizationHeaders,
      },
      redirect: 'manual',
      signal: controller.signal,
    });
    rememberCookies(jar, result);
    const text = await readLimited(result, '/csrf-token');
    if (!result.ok) {
      const detail = text.replace(/\s+/g, ' ').trim().slice(0, 180);
      const authHint = result.status === 401 || result.status === 403
        ? '请检查网页端账号/密码、访问令牌或远端 Basic Auth 设置。'
        : '';
      throw new Error(`/csrf-token 返回 HTTP ${result.status}。${authHint}${detail ? ` 远端响应：${detail}` : ''}`);
    }
    let payload;
    try {
      payload = JSON.parse(text);
    } catch {
      throw new Error('网页端 /csrf-token 返回的不是有效 JSON。');
    }
    remoteCsrfToken = typeof payload.token === 'string' ? payload.token : '';
    if (!remoteCsrfToken) throw new Error('网页端没有返回 CSRF token。');
  };

  const fetchRemoteResponse = async (route, body) => {
    await ensureRemoteSession();
    const headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 DaoYuan-Mini-Client/remote-sync',
      Origin: remote.origin,
      Referer: `${remote.baseUrl}/`,
      'X-CSRF-Token': remoteCsrfToken,
      ...remote.authorizationHeaders,
    };
    const cookies = cookieHeader(jar);
    if (cookies) headers.Cookie = cookies;
    return fetch(`${remote.baseUrl}${route}`, {
      method: 'POST',
      headers,
      body: body ?? '{}',
      redirect: 'manual',
      signal: controller.signal,
    });
  };

  const fetchRemote = async (route, body) => {
    const result = await fetchRemoteResponse(route, body);
    rememberCookies(jar, result);
    const text = await readLimited(result, route);
    if (!result.ok) {
      const hint = result.status === 401 || result.status === 403
        ? '（请检查网页端账号/密码、访问令牌、CSRF 或 Basic Auth 设置）'
        : '';
      const detail = text.replace(/\s+/g, ' ').trim().slice(0, 180);
      throw new Error(`${route} 返回 HTTP ${result.status}${hint}${detail ? `：${detail}` : '。'}`);
    }
    try {
      return JSON.parse(text);
    } catch {
      throw new Error(`${route} 返回的不是有效 JSON。`);
    }
  };

  const fetchRemoteBytes = async (route) => {
    await ensureRemoteSession();
    const headers = {
      'User-Agent': 'Mozilla/5.0 DaoYuan-Mini-Client/remote-sync',
      Origin: remote.origin,
      Referer: `${remote.baseUrl}/`,
      ...remote.authorizationHeaders,
    };
    const cookies = cookieHeader(jar);
    if (cookies) headers.Cookie = cookies;
    const result = await fetch(`${remote.baseUrl}${route}`, {
      method: 'GET',
      headers,
      redirect: 'manual',
      signal: controller.signal,
    });
    rememberCookies(jar, result);
    if (result.status >= 300 && result.status < 400) {
      try { await result.body?.cancel(); } catch { /* ignore */ }
      throw new Error(`${route} 被重定向，已拒绝。`);
    }
    if (!result.ok) {
      try { await result.body?.cancel(); } catch { /* ignore */ }
      const hint = result.status === 401 || result.status === 403
        ? '（请检查网页端账号/密码、访问令牌或 Basic Auth 设置）'
        : '';
      throw new Error(`${route} 返回 HTTP ${result.status}${hint}。`);
    }
    const bytes = Buffer.from(await result.arrayBuffer());
    if (bytes.length > MAX_BODY) throw new Error(`${route} 响应超过 50MB。`);
    return bytes;
  };

  const fetchRemoteGet = async (route) => {
    const text = (await fetchRemoteBytes(route)).toString('utf8');
    try {
      return JSON.parse(text);
    } catch {
      throw new Error(`${route} 返回的不是有效 JSON。`);
    }
  };

  const runGit = (args) => new Promise((resolvePromise, reject) => {
    const child = spawn('git', args, {
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, GIT_TERMINAL_PROMPT: '0', GCM_INTERACTIVE: 'Never' },
    });
    gitChildren.add(child);
    let stderr = '';
    const gitTimer = setTimeout(() => child.kill(), 120000);
    let settled = false;
    const finish = (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(gitTimer);
      gitChildren.delete(child);
      if (error) reject(error);
      else resolvePromise();
    };
    controller.signal.addEventListener('abort', () => child.kill(), { once: true });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString('utf8');
      if (stderr.length > 2000) stderr = stderr.slice(-2000);
    });
    child.on('error', (error) => {
      if (error && error.code === 'ENOENT') {
        const missing = new Error('本机没有 git，无法同步插件。');
        missing.code = 'NO_GIT';
        finish(missing);
        return;
      }
      finish(error);
    });
    child.on('close', (code) => {
      if (code === 0) finish();
      else finish(new Error((stderr || `git 退出 ${code}`).replace(/\s+/g, ' ').trim().slice(0, 180)));
    });
  });

  try {
    const settingsPayload = await fetchRemote('/api/settings/get');
    const settingsText = typeof settingsPayload.settings === 'string' ? settingsPayload.settings : '';
    if (!settingsText) throw new Error('网页端未返回 settings.json。');
    const parsedSettings = JSON.parse(settingsText);
    if (!parsedSettings || typeof parsedSettings !== 'object' || Array.isArray(parsedSettings)) {
      throw new Error('网页端 settings.json 格式无效。');
    }
    const remoteVersion = parsedSettings.version || parsedSettings.sillyTavernVersion || null;
    if (mode === 'check') {
      return {
        ok: true,
        mode,
        remoteVersion,
        synced,
        errors,
        backup: null,
        user: null,
      };
    }

    const user = resolveUserRoot(dataRoot);
    userHandle = user.handle;
    const directories = userDirectories(user.root);
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupRoot = join(directories.backups, `daoyuan-sync-${timestamp}`);
    if (!isInside(user.root, backupRoot)) throw new Error('备份路径无效。');
    mkdirSync(backupRoot, { recursive: true });
    backupName = `daoyuan-sync-${timestamp}`;

    const localSettings = join(directories.root, 'settings.json');
    backupExisting(localSettings, user.root, backupRoot);
    atomicWrite(localSettings, `${JSON.stringify(parsedSettings, null, 4)}\n`, temporaryFiles, user.root);
    synced.settings = true;

    const presets = [
      ['openai_settings', 'openai_setting_names', directories.openAI_Settings],
      ['novelai_settings', 'novelai_setting_names', directories.novelAI_Settings],
      ['textgenerationwebui_presets', 'textgenerationwebui_preset_names', directories.textGen_Settings],
      ['koboldai_settings', 'koboldai_setting_names', directories.koboldAI_Settings],
      ['instruct', null, directories.instruct],
      ['context', null, directories.context],
      ['sysprompt', null, directories.sysprompt],
      ['reasoning', null, directories.reasoning],
    ];
    for (const [contentsKey, namesKey, directory] of presets) {
      const contents = Array.isArray(settingsPayload[contentsKey]) ? settingsPayload[contentsKey] : [];
      const names = namesKey && Array.isArray(settingsPayload[namesKey]) ? settingsPayload[namesKey] : [];
      const limited = contents.slice(0, MAX_PRESETS);
      if (contents.length > MAX_PRESETS) errors.push(`${contentsKey} 超过 ${MAX_PRESETS} 份，其余已跳过。`);
      for (let index = 0; index < limited.length; index += 1) {
        try {
          const rawPreset = typeof limited[index] === 'string' ? limited[index] : JSON.stringify(limited[index]);
          const parsed = JSON.parse(rawPreset);
          const requestedName = names[index] || parsed?.name || `${contentsKey}-${index + 1}`;
          const file = join(directory, `${safeName(String(requestedName).replace(/\.json$/i, ''))}.json`);
          backupExisting(file, user.root, backupRoot);
          atomicWrite(file, `${JSON.stringify(parsed, null, 4)}\n`, temporaryFiles, user.root);
          synced.presets += 1;
        } catch (error) {
          errors.push(`${contentsKey}[${index}]：${explain(error)}`);
        }
      }
    }

    let worldList = [];
    try {
      worldList = worldNamesFromList(await fetchRemote('/api/worldinfo/list'));
    } catch (error) {
      errors.push(`世界书列表：${explain(error)}`);
    }
    if (worldList.length > MAX_WORLDS) {
      errors.push(`世界书超过 ${MAX_WORLDS} 份，其余已跳过。`);
      worldList = worldList.slice(0, MAX_WORLDS);
    }
    for (const name of worldList) {
      try {
        const result = await fetchRemoteResponse('/api/worldinfo/get', JSON.stringify({ name }));
        rememberCookies(jar, result);
        const text = await readLimited(result, '/api/worldinfo/get');
        if (!result.ok) throw new Error(`返回 HTTP ${result.status}。`);
        const body = JSON.parse(text);
        if (!body || typeof body !== 'object' || !body.entries) {
          throw new Error('格式无效。');
        }
        const file = join(directories.worlds, `${safeName(name)}.json`);
        backupExisting(file, user.root, backupRoot);
        atomicWrite(file, `${JSON.stringify(body, null, 4)}\n`, temporaryFiles, user.root);
        synced.worldInfo += 1;
      } catch (error) {
        errors.push(`世界书 ${name}：${explain(error)}`);
      }
    }

    const characterFiles = [];
    const seenCharacters = new Set();
    try {
      const listed = await fetchRemote('/api/characters/all');
      if (!Array.isArray(listed)) {
        throw new Error(listed && listed.overflow ? '角色卡过多，网页端拒绝列出。' : '角色卡列表格式无效。');
      }
      for (const item of listed) {
        const fileName = characterFileName(item && item.avatar);
        if (!fileName || seenCharacters.has(fileName)) continue;
        seenCharacters.add(fileName);
        characterFiles.push(fileName);
      }
    } catch (error) {
      errors.push(`角色卡列表：${explain(error)}`);
    }
    if (characterFiles.length > MAX_CHARACTERS) {
      errors.push(`角色卡超过 ${MAX_CHARACTERS} 张，其余已跳过。`);
      characterFiles.length = MAX_CHARACTERS;
    }
    for (const fileName of characterFiles) {
      try {
        const bytes = await fetchRemoteBytes(`/characters/${encodeURIComponent(fileName)}`);
        if (!isPng(bytes)) throw new Error('不是 PNG 角色卡。');
        const file = join(directories.characters, fileName);
        backupExisting(file, user.root, backupRoot);
        atomicWrite(file, bytes, temporaryFiles, user.root);
        synced.characters += 1;
      } catch (error) {
        errors.push(`角色卡 ${fileName}：${explain(error)}`);
      }
    }

    const plugins = [];
    const seenPlugins = new Set();
    try {
      const listed = await fetchRemoteGet('/api/extensions/discover');
      const rows = Array.isArray(listed) ? listed : [];
      for (const item of rows) {
        if (!item || (item.type !== 'local' && item.type !== 'global')) continue;
        const folder = extensionFolderName(item.name);
        if (!folder || seenPlugins.has(folder)) continue;
        seenPlugins.add(folder);
        plugins.push({ folder, global: item.type === 'global' });
      }
    } catch (error) {
      errors.push(`插件列表：${explain(error)}`);
    }
    if (plugins.length > MAX_EXTENSIONS) {
      errors.push(`插件超过 ${MAX_EXTENSIONS} 个，其余已跳过。`);
      plugins.length = MAX_EXTENSIONS;
    }
    let gitMissing = false;
    for (const plugin of plugins) {
      if (gitMissing) break;
      const dest = join(directories.extensions, plugin.folder);
      if (!isInside(directories.extensions, dest)) {
        errors.push(`插件 ${plugin.folder}：路径无效。`);
        continue;
      }
      if (existsSync(dest) || existsSync(join(bundledThirdParty, plugin.folder, 'manifest.json'))) {
        synced.extensionsSkipped += 1;
        continue;
      }
      let started = false;
      try {
        const version = await fetchRemote('/api/extensions/version', JSON.stringify({
          extensionName: plugin.folder,
          global: plugin.global,
        }));
        const remoteUrl = gitCloneUrl(version && version.remoteUrl);
        if (!remoteUrl) {
          errors.push(`插件 ${plugin.folder}：网页端没有可用的 http(s) git 地址，无法复制文件。`);
          continue;
        }
        const branch = gitBranch(version && version.currentBranchName);
        const args = ['clone', '--depth', '1'];
        if (branch) args.push('--branch', branch);
        args.push('--', remoteUrl, dest);
        mkdirSync(directories.extensions, { recursive: true });
        started = true;
        await runGit(args);
        if (!existsSync(join(dest, 'manifest.json'))) {
          throw new Error('克隆结果没有 manifest.json。');
        }
        synced.extensions += 1;
      } catch (error) {
        if (started) {
          try { rmSync(dest, { recursive: true, force: true }); } catch { /* ignore */ }
        }
        if (error && error.code === 'NO_GIT') {
          gitMissing = true;
          errors.push(explain(error));
          continue;
        }
        errors.push(`插件 ${plugin.folder}：${explain(error)}`);
      }
    }

    return {
      ok: errors.length === 0,
      mode,
      remoteVersion,
      synced,
      errors,
      backup: backupName,
      user: userHandle,
    };
  } catch (error) {
    errors.push(explain(error));
    return {
      ok: false,
      mode,
      remoteVersion: null,
      synced,
      errors,
      backup: backupName,
      user: userHandle,
    };
  } finally {
    clearTimeout(timer);
    for (const child of gitChildren) {
      try { child.kill(); } catch { /* ignore */ }
    }
  }
}

async function main() {
  if (process.argv.includes('--self-test')) {
    selfTest();
    return;
  }
  if (process.stdin.isTTY) {
    emit({ ok: false, error: '请从微端设置发起同步。', errors: ['请从微端设置发起同步。'], synced: emptySynced() });
    process.exitCode = 1;
    return;
  }
  const temporaryFiles = [];
  let report;
  try {
    report = await run(temporaryFiles);
  } catch (error) {
    const message = explain(error);
    report = {
      ok: false,
      error: message,
      errors: [message],
      synced: emptySynced(),
      backup: null,
      user: null,
    };
  } finally {
    for (const temporary of temporaryFiles) {
      try {
        rmSync(temporary, { force: true });
      } catch {
        /* ignore */
      }
    }
  }
  emit(report);
  if (!report.ok) process.exitCode = 1;
}

const invokedDirectly = process.argv[1]
  && import.meta.url === pathToFileURL(resolve(process.argv[1])).href;
if (invokedDirectly) await main();
