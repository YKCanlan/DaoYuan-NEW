/**
 * 安装原生 SillyTavern（release 分支）到 resources/sillytavern。
 * 不修改 DaoYuan-Main。
 */
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ensureBuiltinExtensions } from './ensure-builtin-extensions.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dest = resolve(process.env.DAOYUAN_SILLYTAVERN_ROOT || join(root, 'resources', 'sillytavern'));
const repo = 'https://github.com/SillyTavern/SillyTavern.git';
const branch = process.env.DAOYUAN_ST_BRANCH || 'release';

function run(command, args, cwd) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: 'inherit',
      shell: process.platform === 'win32',
    });
    child.on('exit', (code) => {
      if (code === 0) resolvePromise();
      else reject(new Error(`${command} ${args.join(' ')} 退出码 ${code}`));
    });
  });
}

await mkdir(dirname(dest), { recursive: true });

if (!existsSync(join(dest, 'server.js'))) {
  console.log(`克隆 SillyTavern ${branch} → ${dest}`);
  // 完整克隆，与 SillyTavern-Launcher 一样能 git pull。浅克隆后续更新会失败。
  await run('git', ['clone', '--branch', branch, repo, dest], root);
} else {
  console.log(`已存在酒馆内核：${dest}`);
}

if (!existsSync(join(dest, 'node_modules'))) {
  console.log('安装 SillyTavern npm 依赖…');
  await run('npm', ['install', '--omit=dev'], dest);
} else {
  console.log('npm 依赖已就绪。');
}

const extensions = await ensureBuiltinExtensions({
  tavernRoot: dest,
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

console.log('setup 完成。随后可执行：');
console.log('  npm run dev:ui');
