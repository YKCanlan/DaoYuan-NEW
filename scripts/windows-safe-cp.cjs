/**
 * Node 在 Windows 上对含非 ASCII 的目录调用 fs.cpSync 会直接中止进程
 * （0xC0000409，见 nodejs/node#54476）。交付目录「交付」会踩中。
 * 由 start-tavern.mjs 在 server.js 之前 --require，不改 SillyTavern 源码。
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');

function hasNonAscii(value) {
  const text = String(value);
  for (let i = 0; i < text.length; i += 1) {
    if (text.charCodeAt(i) > 127) return true;
  }
  return false;
}

function copyRecursive(src, dest, opts) {
  const filter = typeof opts.filter === 'function' ? opts.filter : null;
  if (filter && filter(src, dest) === false) return;

  const stat = fs.lstatSync(src);
  if (stat.isSymbolicLink()) {
    const link = fs.readlinkSync(src);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.rmSync(dest, { recursive: true, force: true });
    fs.symlinkSync(link, dest, stat.isDirectory() ? 'junction' : 'file');
    return;
  }

  if (stat.isDirectory()) {
    if (opts.recursive !== true) {
      const error = new Error(`cp: ${src} is a directory (not copied)`);
      error.code = 'ERR_FS_EISDIR';
      throw error;
    }
    fs.mkdirSync(dest, { recursive: true });
    for (const name of fs.readdirSync(src)) {
      copyRecursive(path.join(src, name), path.join(dest, name), opts);
    }
    return;
  }

  if (fs.existsSync(dest)) {
    if (opts.force === false) {
      const error = new Error(`EEXIST: file already exists, cp '${src}' -> '${dest}'`);
      error.code = 'EEXIST';
      throw error;
    }
    const destStat = fs.lstatSync(dest);
    if (destStat.isDirectory()) {
      const error = new Error(`EISDIR: cannot overwrite directory '${dest}'`);
      error.code = 'EISDIR';
      throw error;
    }
  } else {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
  }
  fs.copyFileSync(src, dest);
}

const originalCpSync = fs.cpSync;
fs.cpSync = function cpSync(src, dest, opts) {
  const options = opts && typeof opts === 'object' ? opts : {};
  if (process.platform === 'win32' && (hasNonAscii(src) || hasNonAscii(dest))) {
    return copyRecursive(src, dest, options);
  }
  return originalCpSync.call(this, src, dest, opts);
};
