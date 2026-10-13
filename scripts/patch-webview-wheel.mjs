/**
 * 纹理模式下 webview_windows 的滚轮进不了页面，点击还可能落在上一次悬停处。
 * 壳层自己用 Flutter 指针位置调用 __daoyuan.scrollAt，这里关掉插件的滚轮转发，
 * 并在按下 / 松开时先把光标移到这次事件的位置。
 *
 * 改的是 Pub Cache 里的插件源码。flutter pub get 不会覆盖已解压的包；
 * 缓存被清掉之后，打包前再跑一次本脚本。
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const marker = 'daoyuan-wheel';
const pubCache = process.env.PUB_CACHE
  || (process.env.LOCALAPPDATA ? join(process.env.LOCALAPPDATA, 'Pub', 'Cache') : '');
const target = join(
  pubCache,
  'hosted',
  'pub.dev',
  'webview_windows-0.4.0',
  'lib',
  'src',
  'webview.dart',
);

export function patchWebviewWheel() {
  if (!existsSync(target)) {
    console.warn(`skip patch, missing ${target}`);
    return 'missing';
  }
  return patchFile(target);
}

function patchFile(target) {
  const original = readFileSync(target, 'utf8');
  const crlf = original.includes('\r\n');
  let source = original.replace(/\r\n/g, '\n');
  if (source.includes(marker)) {
    console.log('webview_windows wheel patch already applied');
    return 'applied';
  }

const down = `                      final button = getButton(ev.buttons);
                      _downButtons[ev.pointer] = button;
                      _controller._setPointerButtonState(button, true);`;
const downNext = `                      final button = getButton(ev.buttons);
                      _downButtons[ev.pointer] = button;
                      // ${marker}: land the click on this event, not the previous hover.
                      _controller._setCursorPos(ev.localPosition);
                      _controller._setPointerButtonState(button, true);`;

const up = `                      final button = _downButtons.remove(ev.pointer);
                      if (button != null) {
                        _controller._setPointerButtonState(button, false);
                      }
                    },
                    onPointerCancel:`;
const upNext = `                      _controller._setCursorPos(ev.localPosition);
                      final button = _downButtons.remove(ev.pointer);
                      if (button != null) {
                        _controller._setPointerButtonState(button, false);
                      }
                    },
                    onPointerCancel:`;

const wheel = `                    onPointerSignal: (signal) {
                      if (signal is PointerScrollEvent) {
                        _controller._setScrollDelta(
                            -signal.scrollDelta.dx, -signal.scrollDelta.dy);
                      }
                    },
                    onPointerPanZoomUpdate: (signal) {
                      _controller._setScrollDelta(
                          signal.panDelta.dx, signal.panDelta.dy);
                    },`;
const wheelNext = `                    // ${marker}: texture-mode SendMouseInput(WHEEL) never
                    // hits the node under the cursor. DaoYuan scrolls via
                    // window.__daoyuan.scrollAt from its own listener.
                    onPointerSignal: (_) {},
                    onPointerPanZoomUpdate: (_) {},`;

const steps = [
  [down, downNext],
  [up, upNext],
  [wheel, wheelNext],
];
for (const [from, to] of steps) {
  if (!source.includes(from)) {
    throw new Error(`webview_windows 源码对不上，无法打滚轮补丁：${target}`);
  }
  source = source.replace(from, to);
}
  writeFileSync(target, crlf ? source.replace(/\n/g, '\r\n') : source);
  console.log('patched', target);
  return 'patched';
}

const invoked = process.argv[1]
  && pathToFileURL(resolve(process.argv[1])).href === pathToFileURL(fileURLToPath(import.meta.url)).href;
if (invoked) patchWebviewWheel();
