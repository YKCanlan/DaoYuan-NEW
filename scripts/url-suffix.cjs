/**
 * 在不改 SillyTavern 源码的前提下，给本机酒馆加一层地址后缀。
 * 由 start-tavern.mjs 在 server.js 之前 --require。
 * 环境变量 DAOYUAN_URL_SUFFIX 为空时什么都不做。
 */
'use strict';

const reserved = new Set([
  'api',
  'assets',
  'backgrounds',
  'characters',
  'chats',
  'css',
  'csrf-token',
  'extensions',
  'favicon.ico',
  'img',
  'lib',
  'login',
  'script',
  'scripts',
  'sounds',
  'thumbnail',
  'user',
  'version',
  'webfonts',
]);

function normalizeSuffix(raw) {
  let text = String(raw || '').trim().replace(/^\/+|\/+$/g, '');
  if (!text) return '';
  if (text.length > 64) {
    throw new Error('地址后缀过长。');
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(text)) {
    throw new Error('地址后缀只能包含字母、数字、下划线和连字符。');
  }
  if (reserved.has(text.toLowerCase())) {
    throw new Error(`地址后缀「${text}」和酒馆自己的路径冲突。`);
  }
  return text;
}

/** 剥掉后缀。不匹配时返回 null。 */
function rewriteRequestUrl(url, suffix) {
  const prefix = `/${suffix}`;
  const queryAt = url.indexOf('?');
  const path = queryAt === -1 ? url : url.slice(0, queryAt);
  const query = queryAt === -1 ? '' : url.slice(queryAt);
  if (path === prefix) return `/${query}`;
  if (path.startsWith(`${prefix}/`)) {
    const rest = path.slice(prefix.length) || '/';
    return `${rest}${query}`;
  }
  return null;
}

function install(suffix) {
  const http = require('node:http');
  const originalEmit = http.Server.prototype.emit;
  http.Server.prototype.emit = function emit(event, req, res, ...rest) {
    if (event === 'request' && req && res && typeof req.url === 'string') {
      const rewritten = rewriteRequestUrl(req.url, suffix);
      if (rewritten != null) {
        req.url = rewritten;
      } else if (req.method === 'GET' && (req.url === '/' || req.url.startsWith('/?'))) {
        const accept = String(req.headers.accept || '');
        if (accept.includes('text/html')) {
          res.writeHead(302, { Location: `/${suffix}/` });
          res.end();
          return true;
        }
      }
    }
    return originalEmit.call(this, event, req, res, ...rest);
  };
}

const suffix = normalizeSuffix(process.env.DAOYUAN_URL_SUFFIX || '');
if (suffix) install(suffix);

module.exports = { normalizeSuffix, rewriteRequestUrl, reserved };

if (require.main === module && process.argv.includes('--self-test')) {
  const assert = require('node:assert/strict');
  assert.equal(normalizeSuffix(''), '');
  assert.equal(normalizeSuffix('/Dao-Yuan_/'), 'Dao-Yuan_');
  assert.equal(rewriteRequestUrl('/Dao-Yuan_/style.css', 'Dao-Yuan_'), '/style.css');
  assert.equal(rewriteRequestUrl('/Dao-Yuan_', 'Dao-Yuan_'), '/');
  assert.equal(rewriteRequestUrl('/Dao-Yuan_/csrf-token?x=1', 'Dao-Yuan_'), '/csrf-token?x=1');
  assert.equal(rewriteRequestUrl('/script.js', 'Dao-Yuan_'), null);
  assert.throws(() => normalizeSuffix('api'));
  assert.throws(() => normalizeSuffix('../x'));
  console.log('url-suffix self-test ok');
}
