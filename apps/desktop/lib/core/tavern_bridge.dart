/// 注入到 SillyTavern 页面的壳层桥。
///
/// 不改 `resources/sillytavern` 源码：用 WebView 在文档创建时注入 CSS/JS，
/// 隐藏酒馆顶栏图标，把道渊左栏/顶栏点击映射到原生 `.drawer-toggle`，
/// 并用 [kTavernSkinCss] 把菜单铬拉到 NEW 玄墨语汇。
library;

import 'dart:convert';

import 'tavern_skin.dart';
import 'welcome_host.dart';

export 'tavern_skin.dart';
export 'welcome_host.dart';

/// 文档创建即跑，避免顶栏闪一下。
final String kTavernBridgeScript = _buildTavernBridgeScript();

String _buildTavernBridgeScript() {
  return r'''
(() => {
  if (window.__daoyuan) return window.__daoyuan;

  const MAP = {
    api_connect: '#sys-settings-button > .drawer-toggle',
    api_params: '#ai-config-button > .drawer-toggle',
    prompt: '#advanced-formatting-button > .drawer-toggle',
    characters: '#rightNavHolder > .drawer-toggle',
    worldbook: '#WI-SP-button > .drawer-toggle',
    persona: '#persona-management-button > .drawer-toggle',
    extensions: '#extensions-settings-button > .drawer-toggle',
    system: '#user-settings-button > .drawer-toggle',
  };

  const FONT_CLASS = {
    kaiti: 'daoyuan-font-kaiti',
    yahei: 'daoyuan-font-yahei',
    fangsong: 'daoyuan-font-fangsong',
  };

  const WELCOME_NAME = ''' + jsonEncode(kWelcomeAssistantName) + r''';
  const WELCOME_AVATAR = ''' + jsonEncode(kWelcomeAssistantAvatar) + r''';
  const WELCOME_HTML = ''' + jsonEncode(kWelcomeAssistantHtml) + r''';

  const CSS = ''' +
      jsonEncode(kTavernSkinCss) +
      r''';

  function applyShell() {
    const html = document.documentElement;
    html.classList.add('daoyuan-shell');
    if (!html.classList.contains('daoyuan-font-kaiti') &&
        !html.classList.contains('daoyuan-font-yahei') &&
        !html.classList.contains('daoyuan-font-fangsong')) {
      html.classList.add('daoyuan-font-yahei');
    }
    let style = document.getElementById('daoyuan-shell-style');
    if (!style) {
      style = document.createElement('style');
      style.id = 'daoyuan-shell-style';
      style.textContent = CSS;
    }
    const host = document.head || document.documentElement;
    if (style.parentNode !== host || host.lastElementChild !== style) {
      host.appendChild(style);
    }
  }

  function watchStyle() {
    if (window.__daoyuanStyleWatch) return;
    window.__daoyuanStyleWatch = true;
    const host = document.head || document.documentElement;
    const obs = new MutationObserver(() => {
      if (!document.getElementById('daoyuan-shell-style')) applyShell();
    });
    obs.observe(host, { childList: true });
  }

  function setFont(id) {
    applyShell();
    const html = document.documentElement;
    Object.values(FONT_CLASS).forEach((cls) => html.classList.remove(cls));
    html.classList.add(FONT_CLASS[id] || FONT_CLASS.yahei);
    return id || 'yahei';
  }

  function setSmooth(on) {
    applyShell();
    document.documentElement.classList.toggle('daoyuan-smooth', !!on);
    return !!on;
  }

  function pageReady() {
    return !!(
      document.querySelector('#top-settings-holder') &&
      (document.querySelector('#send_textarea') || document.querySelector('#sheld'))
    );
  }

  function isOpen(toggle) {
    const parent = toggle && toggle.parentElement;
    const content = parent && parent.querySelector(':scope > .drawer-content');
    return !!(content && content.classList.contains('openDrawer'));
  }

  function fireClick(el) {
    if (window.jQuery) {
      window.jQuery(el).trigger('click');
    } else if (typeof el.click === 'function') {
      el.click();
    }
  }

  function drawerContent(toggle) {
    const parent = toggle && toggle.parentElement;
    return parent ? parent.querySelector(':scope > .drawer-content') : null;
  }

  function stampFrame(el) {
    if (!el || !el.style || el.id === 'cfgConfig' || el.id === 'logprobsViewer') return;
    if (el.dataset.dyStamping === '1') return;
    el.dataset.dyStamping = '1';
    const wide = el.id === 'character_popup';
    const width = wide ? 'var(--dy-editor-width)' : 'var(--dy-panel-width)';
    const props = {
      position: 'fixed',
      top: 'var(--dy-inset)',
      left: '0',
      right: '0',
      bottom: 'auto',
      transform: 'none',
      width: width,
      'min-width': '0',
      'max-width': width,
      height: 'var(--dy-panel-height)',
      'min-height': '0',
      'max-height': 'var(--dy-panel-height)',
      margin: '0 auto',
      transition: 'none',
      animation: 'none',
      'overflow-x': 'hidden',
      'overflow-y': 'auto',
      'touch-action': 'pan-y',
    };
    relaxDrawer(el);
    Object.keys(props).forEach((key) => {
      if (el.style.getPropertyValue(key) === props[key] && el.style.getPropertyPriority(key) === 'important') return;
      el.style.setProperty(key, props[key], 'important');
    });
    el.dataset.dyStamping = '0';
  }

  function prepareDrawer(toggle) {
    const content = drawerContent(toggle);
    if (!content) return null;
    document.querySelectorAll('.drawer-content.openDrawer:not(.pinnedOpen)').forEach((el) => {
      if (el === content) return;
      el.classList.remove('openDrawer');
      el.classList.add('closedDrawer');
    });
    stampFrame(content);
    return content;
  }

  function relaxDrawer(panel) {
    if (!panel || panel.dataset.dyRelaxed === '1') return;
    panel.dataset.dyRelaxed = '1';
    panel.querySelectorAll('div, section, nav, ul, ol, form').forEach((node) => {
      if (node.closest('textarea, pre, .CodeMirror, .cm-editor, .select2-container, .select2-dropdown')) return;
      node.style.setProperty('height', 'auto', 'important');
      node.style.setProperty('max-height', 'none', 'important');
      node.style.setProperty('overflow', 'visible', 'important');
    });
  }

  function releaseFrame(el) {
    if (!el || !el.style) return;
    ['position', 'top', 'left', 'right', 'bottom', 'transform', 'width', 'min-width', 'max-width', 'height', 'min-height', 'max-height', 'margin', 'overflow-x', 'overflow-y', 'touch-action', 'transition', 'animation'].forEach((key) => {
      el.style.removeProperty(key);
    });
  }

  function canScrollAxis(el, delta, axis) {
    if (!(el instanceof Element) || !delta) return false;
    if (el === document.body || el === document.documentElement) return false;
    const style = getComputedStyle(el);
    const overflow = axis === 'y' ? style.overflowY : style.overflowX;
    if (overflow !== 'auto' && overflow !== 'scroll' && overflow !== 'overlay') return false;
    if (axis === 'y') {
      if (el.scrollHeight <= el.clientHeight + 1) return false;
      if (delta > 0 && el.scrollTop + el.clientHeight >= el.scrollHeight - 1) return false;
      if (delta < 0 && el.scrollTop <= 0) return false;
      return true;
    }
    if (el.scrollWidth <= el.clientWidth + 1) return false;
    if (delta > 0 && el.scrollLeft + el.clientWidth >= el.scrollWidth - 1) return false;
    if (delta < 0 && el.scrollLeft <= 0) return false;
    return true;
  }

  function activeNumberInput(hit) {
    const active = document.activeElement;
    if (!(active instanceof HTMLInputElement) || active.type !== 'number' || active.disabled || !active.hasAttribute('step')) return null;
    if (!(hit instanceof Element)) return null;
    if (hit === active) return active;
    const block = active.closest('.range-block-range-and-counter') || active.parentElement;
    if (block && block.contains(hit) && (hit === active || hit.matches('input[type="range"], input[type="number"]'))) return active;
    return null;
  }

  function tweakNumber(input, deltaY) {
    const step = parseFloat(input.step);
    const current = parseFloat(input.value);
    if (!isFinite(step) || step <= 0 || !isFinite(current) || !deltaY) return false;
    let next = current + (deltaY > 0 ? -step : step);
    next = Math.round(next / step) * step;
    const min = parseFloat(input.min);
    const max = parseFloat(input.max);
    if (isFinite(min)) next = Math.max(min, next);
    if (isFinite(max)) next = Math.min(max, next);
    next = Math.round(next * 1e10) / 1e10;
    if (next === current) return false;
    input.value = String(next);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    return true;
  }

  function scrollElement(el, dx, dy) {
    let used = false;
    if (canScrollAxis(el, dy, 'y')) {
      el.scrollTop += dy;
      used = true;
    }
    if (canScrollAxis(el, dx, 'x')) {
      el.scrollLeft += dx;
      used = true;
    }
    return used;
  }

  function scrollFrom(start, dx, dy) {
    let el = start;
    while (el && el !== document.body && el !== document.documentElement) {
      if (scrollElement(el, dx, dy)) return el;
      el = el.parentElement;
    }
    return null;
  }

  // 纹理模式下 WebView2 的滚轮到不了光标下的节点。壳层把 Flutter 的滚轮
  // 像素和指针位置传进来，从命中的元素往上找第一个还能滚的容器。
  function scrollAt(x, y, dx, dy) {
    if (!dx && !dy) return 'zero';
    const maxX = Math.max(0, (window.innerWidth || 1) - 1);
    const maxY = Math.max(0, (window.innerHeight || 1) - 1);
    x = Math.min(maxX, Math.max(0, x));
    y = Math.min(maxY, Math.max(0, y));
    const hit = document.elementFromPoint(x, y);
    const number = activeNumberInput(hit);
    if (number) return tweakNumber(number, dy) ? 'number' : 'number-skip';
    if (!(hit instanceof Element)) return 'miss';
    return scrollFrom(hit, dx, dy) ? 'ok' : 'none';
  }

  function installWheelGuard() {
    if (window.__daoyuanWheelGuard) return;
    window.__daoyuanWheelGuard = true;
    document.addEventListener('wheel', (event) => {
      // 系统滚轮要么打在错误坐标上，要么和 scrollAt 叠成两次。一律吃掉。
      event.preventDefault();
      event.stopPropagation();
    }, { capture: true, passive: false });
  }

  function watchFrames() {
    if (window.__daoyuanFrameWatch) return;
    window.__daoyuanFrameWatch = true;
    installWheelGuard();
    const obs = new MutationObserver((records) => {
      records.forEach((rec) => {
        const el = rec.target;
        if (!(el instanceof Element) || rec.attributeName !== 'class') return;
        const drawer = el.classList.contains('drawer-content');
        const editor = el.id === 'character_popup';
        if (!drawer && !editor) return;
        if (drawer && el.classList.contains('openDrawer')) stampFrame(el);
        if (drawer && !el.classList.contains('openDrawer')) releaseFrame(el);
        if (editor && el.classList.contains('open')) stampFrame(el);
        if (editor && !el.classList.contains('open')) releaseFrame(el);
        closeSelectMenu();
        dropSelect2();
      });
    });
    const host = document.body || document.documentElement;
    if (host) obs.observe(host, { subtree: true, attributes: true, attributeFilter: ['class', 'style'] });
  }

  function openDrawer(id) {
    applyShell();
    if (!pageReady()) return 'not-ready';
    const key = String(id || '');
    if (!key) {
      document.querySelectorAll('#top-settings-holder .drawer-toggle').forEach((toggle) => {
        if (isOpen(toggle)) fireClick(toggle);
      });
      return 'closed';
    }
    const selector = MAP[key];
    if (!selector) return 'unknown:' + key;
    const toggle = document.querySelector(selector);
    if (!toggle) return 'missing:' + key;
    const wasOpen = isOpen(toggle);
    if (!wasOpen) {
      prepareDrawer(toggle);
      fireClick(toggle);
      const content = drawerContent(toggle);
      stampFrame(content);
    }
    return wasOpen ? 'already:' + key : 'open:' + key;
  }

  function currentDrawer() {
    for (const key of Object.keys(MAP)) {
      const toggle = document.querySelector(MAP[key]);
      if (toggle && isOpen(toggle)) return key;
    }
    return '';
  }

  function isNativeSelect(el) {
    if (!(el instanceof HTMLSelectElement)) return false;
    if (el.disabled || el.size > 1) return false;
    if (el.classList.contains('select2-hidden-accessible')) return false;
    const rect = el.getBoundingClientRect();
    return rect.width > 2 && rect.height > 2;
  }

  let selectMenu = null;
  let selectMenuTarget = null;

  function closeSelectMenu() {
    if (selectMenu && typeof selectMenu.hidePopover === 'function') {
      try {
        if (selectMenu.matches(':popover-open')) selectMenu.hidePopover();
      } catch (err) { /* already closed */ }
    }
    if (selectMenu) selectMenu.remove();
    selectMenu = null;
    selectMenuTarget = null;
  }

  function placeMenu(menu, rect, count) {
    const width = Math.min(Math.max(rect.width, 220), Math.max(160, window.innerWidth - 16));
    let left = rect.left;
    if (left + width > window.innerWidth - 8) left = Math.max(8, window.innerWidth - width - 8);
    const estimated = Math.min(288, Math.max(36, (count || 1) * 32 + 8));
    let top = rect.bottom + 4;
    if (top + estimated > window.innerHeight - 8 && rect.top > estimated) {
      top = Math.max(8, rect.top - estimated - 4);
    }
    menu.style.setProperty('position', 'fixed', 'important');
    menu.style.setProperty('inset', 'auto', 'important');
    menu.style.setProperty('margin', '0', 'important');
    menu.style.setProperty('transform', 'none', 'important');
    menu.style.setProperty('right', 'auto', 'important');
    menu.style.setProperty('bottom', 'auto', 'important');
    menu.style.setProperty('left', left + 'px', 'important');
    menu.style.setProperty('top', top + 'px', 'important');
    menu.style.setProperty('width', width + 'px', 'important');
  }

  function shieldFloating(el) {
    if (!el || el.dataset.dyShield === '1') return;
    el.dataset.dyShield = '1';
    const stop = (event) => event.stopPropagation();
    el.addEventListener('mousedown', stop);
    el.addEventListener('touchstart', stop);
    el.addEventListener('pointerdown', stop);
  }

  function floatingAtPoint(x, y) {
    if (typeof x !== 'number' || typeof y !== 'number') return null;
    const nodes = document.querySelectorAll('.daoyuan-select-menu, .select2-dropdown, .daoyuan-select2-lift');
    for (let i = 0; i < nodes.length; i++) {
      const rect = nodes[i].getBoundingClientRect();
      if (rect.width < 2 || rect.height < 2) continue;
      if (x >= rect.left - 2 && x <= rect.right + 2 && y >= rect.top - 2 && y <= rect.bottom + 2) return nodes[i];
    }
    return null;
  }

  function mountMenu(menu) {
    const host = document.body || document.documentElement;
    if (!host) return;
    host.appendChild(menu);
    // 不用 Popover 顶层。WebView2 里点顶层滚动条会穿透到下面的聊天页，
    // 酒馆把这次按下当成抽屉外点击，直接关回主界面。
    shieldFloating(menu);
  }

  function commitSelect(select) {
    select.dispatchEvent(new Event('input', { bubbles: true }));
    select.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function openSelectMenu(select) {
    if (selectMenuTarget === select) {
      closeSelectMenu();
      return;
    }
    closeSelectMenu();
    const rect = select.getBoundingClientRect();
    const menu = document.createElement('div');
    menu.className = 'daoyuan-select-menu';
    const list = document.createElement('div');
    list.className = 'daoyuan-select-list';
    let lastGroup = null;
    Array.from(select.options).forEach((option, index) => {
      const group = option.parentElement && option.parentElement.tagName === 'OPTGROUP'
        ? option.parentElement
        : null;
      if (group && group !== lastGroup) {
        lastGroup = group;
        const label = document.createElement('div');
        label.className = 'daoyuan-select-group';
        label.textContent = group.label || '';
        list.appendChild(label);
      }
      const item = document.createElement('button');
      item.type = 'button';
      item.className = 'daoyuan-select-option';
      item.disabled = option.disabled;
      const picked = select.multiple ? option.selected : index === select.selectedIndex;
      if (picked) item.classList.add('is-selected');
      item.textContent = option.textContent || option.label || option.value;
      item.addEventListener('click', (event) => {
        event.preventDefault();
        event.stopPropagation();
        if (option.disabled) return;
        if (select.multiple) {
          option.selected = !option.selected;
          item.classList.toggle('is-selected', option.selected);
          commitSelect(select);
          return;
        }
        select.selectedIndex = index;
        commitSelect(select);
        closeSelectMenu();
      });
      list.appendChild(item);
    });
    menu.appendChild(list);
    mountMenu(menu);
    placeMenu(menu, rect, select.options.length);
    const selected = list.querySelector('.is-selected');
    if (selected) list.scrollTop = Math.max(0, selected.offsetTop - 8);
    selectMenu = menu;
    selectMenuTarget = select;
  }

  function datalistOf(input) {
    if (!(input instanceof HTMLInputElement) || input.disabled || input.readOnly) return null;
    const id = input.getAttribute('list');
    if (!id) return null;
    const list = document.getElementById(id);
    if (!(list instanceof HTMLDataListElement)) return null;
    return list;
  }

  function openDataList(input) {
    const list = datalistOf(input);
    if (!list) return;
    const needle = (input.value || '').trim().toLowerCase();
    const options = Array.from(list.options).filter((option) => {
      const text = (option.value || option.label || '').toLowerCase();
      return !needle || text.indexOf(needle) !== -1;
    }).slice(0, 80);
    if (!options.length) {
      if (selectMenuTarget === input) closeSelectMenu();
      return;
    }
    closeSelectMenu();
    const menu = document.createElement('div');
    menu.className = 'daoyuan-select-menu';
    const box = document.createElement('div');
    box.className = 'daoyuan-select-list';
    options.forEach((option) => {
      const item = document.createElement('button');
      item.type = 'button';
      item.className = 'daoyuan-select-option';
      item.textContent = option.value || option.label;
      item.addEventListener('click', (event) => {
        event.preventDefault();
        event.stopPropagation();
        input.value = option.value || option.label;
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        closeSelectMenu();
      });
      box.appendChild(item);
    });
    menu.appendChild(box);
    mountMenu(menu);
    placeMenu(menu, input.getBoundingClientRect(), options.length);
    selectMenu = menu;
    selectMenuTarget = input;
  }

  function onNativeSelect(event) {
    const target = event.target;
    if (!(target instanceof Element)) return;
    const owned = target.closest('.daoyuan-select-menu, .select2-dropdown, .select2-results, .daoyuan-select2-lift');
    if (owned) return;
    if ((event.type === 'mousedown' || event.type === 'touchstart') && floatingAtPoint(event.clientX, event.clientY)) {
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    const select = target.closest('select');
    if (isNativeSelect(select)) {
      event.preventDefault();
      if (event.type !== 'mousedown') return;
      event.stopPropagation();
      openSelectMenu(select);
      return;
    }
    const field = target.closest('input[list]');
    if (datalistOf(field)) {
      if (event.type === 'mousedown') openDataList(field);
      return;
    }
    if (event.type === 'mousedown') closeSelectMenu();
  }

  let select2Anchor = null;
  let select2LiftTimer = 0;
  let droppingSelect2 = false;

  function select2Box(select) {
    const sib = select && select.nextElementSibling;
    if (!sib || !sib.classList || !sib.classList.contains('select2')) return null;
    return sib.querySelector('.select2-selection') || sib;
  }

  function findOpenSelect2Holder() {
    let holder = null;
    document.querySelectorAll('.select2-container--open').forEach((el) => {
      if (el.querySelector('.select2-dropdown') && !el.querySelector('.select2-selection')) holder = el;
    });
    return holder;
  }

  function placeLiftedSelect2(holder, rect) {
    if (!holder || !rect || rect.width < 2) return;
    const host = document.body || document.documentElement;
    if (host && holder.parentElement !== host) host.appendChild(holder);
    holder.classList.add('daoyuan-select2-lift');
    shieldFloating(holder);
    const dropdown = holder.querySelector('.select2-dropdown');
    if (dropdown) {
      dropdown.style.setProperty('position', 'relative', 'important');
      dropdown.style.setProperty('left', '0', 'important');
      dropdown.style.setProperty('top', '0', 'important');
      dropdown.style.setProperty('right', 'auto', 'important');
      dropdown.style.setProperty('bottom', 'auto', 'important');
      dropdown.style.setProperty('width', '100%', 'important');
      dropdown.style.setProperty('margin', '0', 'important');
      dropdown.style.setProperty('transform', 'none', 'important');
      dropdown.style.setProperty('backdrop-filter', 'none', 'important');
      dropdown.style.setProperty('-webkit-backdrop-filter', 'none', 'important');
    }
    const width = Math.min(Math.max(rect.width, 220), Math.max(160, window.innerWidth - 16));
    let left = rect.left;
    if (left + width > window.innerWidth - 8) left = Math.max(8, window.innerWidth - width - 8);
    const height = Math.max(holder.offsetHeight || 0, dropdown ? dropdown.offsetHeight : 0, 36);
    const above = dropdown && dropdown.classList.contains('select2-dropdown--above');
    let top = above ? rect.top - height - 4 : rect.bottom + 4;
    if (!above && top + height > window.innerHeight - 8 && rect.top > height) top = Math.max(8, rect.top - height - 4);
    if (top < 8) top = 8;
    holder.style.setProperty('position', 'fixed', 'important');
    holder.style.setProperty('margin', '0', 'important');
    holder.style.setProperty('transform', 'none', 'important');
    holder.style.setProperty('right', 'auto', 'important');
    holder.style.setProperty('bottom', 'auto', 'important');
    holder.style.setProperty('left', left + 'px', 'important');
    holder.style.setProperty('top', top + 'px', 'important');
    holder.style.setProperty('width', width + 'px', 'important');
    holder.style.setProperty('z-index', '4800', 'important');
    holder.style.setProperty('backdrop-filter', 'none', 'important');
    holder.style.setProperty('-webkit-backdrop-filter', 'none', 'important');
  }

  function tickSelect2Lift() {
    if (!select2Anchor || !select2Anchor.isConnected) return;
    const holder = findOpenSelect2Holder();
    if (!holder) return;
    placeLiftedSelect2(holder, select2Anchor.getBoundingClientRect());
  }

  function liftOpenSelect2(event) {
    const box = select2Box(event && event.target);
    if (!box || !box.getBoundingClientRect) return;
    select2Anchor = box;
    tickSelect2Lift();
    window.requestAnimationFrame(tickSelect2Lift);
    window.setTimeout(tickSelect2Lift, 0);
    window.setTimeout(tickSelect2Lift, 60);
    if (select2LiftTimer) window.clearInterval(select2LiftTimer);
    let frames = 0;
    select2LiftTimer = window.setInterval(() => {
      frames += 1;
      if (frames > 8 || !document.querySelector('.select2-container--open .select2-dropdown')) {
        window.clearInterval(select2LiftTimer);
        select2LiftTimer = 0;
        return;
      }
      tickSelect2Lift();
    }, 50);
  }

  function clearSelect2Lift() {
    if (select2LiftTimer) {
      window.clearInterval(select2LiftTimer);
      select2LiftTimer = 0;
    }
    document.querySelectorAll('.daoyuan-select2-lift').forEach((el) => {
      el.classList.remove('daoyuan-select2-lift');
    });
    if (!document.querySelector('.select2-container--open .select2-dropdown')) select2Anchor = null;
  }

  function dropSelect2() {
    if (droppingSelect2) return;
    droppingSelect2 = true;
    select2Anchor = null;
    clearSelect2Lift();
    const jq = window.jQuery;
    if (jq) {
      document.querySelectorAll('select.select2-hidden-accessible').forEach((el) => {
        try { jq(el).select2('close'); } catch (err) { /* already closed */ }
      });
    }
    droppingSelect2 = false;
  }

  function bindSelect2Lift() {
    const jq = window.jQuery;
    if (!jq || window.__daoyuanSelect2Lift) return;
    window.__daoyuanSelect2Lift = true;
    jq(document).on('select2:open', liftOpenSelect2);
    jq(document).on('select2:close', clearSelect2Lift);
  }

  function brandWelcomeMessage(mes) {
    if (!mes || mes.getAttribute('type') !== 'assistant_message') return;
    if (mes.getAttribute('ch_name') !== 'Assistant') return;
    const body = mes.querySelector('.mes_text');
    const text = body ? (body.textContent || '') : '';
    if (!/已连接到一个 API|connected to an API|欢迎页面的助手|welcome page assistant/.test(text)) return;
    mes.setAttribute('ch_name', WELCOME_NAME);
    const nameEl = mes.querySelector('.name_text');
    if (nameEl) nameEl.textContent = WELCOME_NAME;
    const img = mes.querySelector('.avatar img');
    if (img) {
      img.hidden = false;
      img.style.display = '';
      img.alt = WELCOME_NAME;
      img.src = WELCOME_AVATAR;
    }
    if (body) body.innerHTML = WELCOME_HTML;
  }

  function brandWelcome() {
    document.querySelectorAll('#chat .mes[type="assistant_message"]').forEach(brandWelcomeMessage);
  }

  function watchWelcome() {
    if (window.__daoyuanWelcomeWatch) return;
    window.__daoyuanWelcomeWatch = true;
    const obs = new MutationObserver(brandWelcome);
    const start = () => {
      const chat = document.getElementById('chat');
      if (!chat) return;
      if (chat.dataset.dyWelcomeWatch !== '1') {
        chat.dataset.dyWelcomeWatch = '1';
        obs.observe(chat, { childList: true, subtree: true });
      }
      brandWelcome();
    };
    start();
    document.addEventListener('DOMContentLoaded', start);
    setTimeout(start, 400);
    setTimeout(start, 1600);
  }

  function watchSelects() {
    if (window.__daoyuanSelectWatch) return;
    window.__daoyuanSelectWatch = true;
    document.addEventListener('mousedown', onNativeSelect, true);
    document.addEventListener('mouseup', onNativeSelect, true);
    document.addEventListener('click', onNativeSelect, true);
    document.addEventListener('input', (event) => {
      if (datalistOf(event.target)) openDataList(event.target);
    }, true);
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        closeSelectMenu();
        return;
      }
      const select = event.target;
      if (!isNativeSelect(select)) return;
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp' || event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        event.stopPropagation();
        openSelectMenu(select);
      }
    }, true);
    document.addEventListener('scroll', (event) => {
      const target = event.target;
      if (select2Anchor && select2Anchor.isConnected) {
        const holder = findOpenSelect2Holder();
        if (holder && !(target instanceof Node && holder.contains(target))) tickSelect2Lift();
      }
      if (!selectMenu || !selectMenuTarget) return;
      if (target instanceof Node && selectMenu.contains(target)) return;
      if (!document.contains(selectMenuTarget)) {
        closeSelectMenu();
        return;
      }
      const count = selectMenuTarget.options ? selectMenuTarget.options.length : 8;
      placeMenu(selectMenu, selectMenuTarget.getBoundingClientRect(), count);
    }, true);
    bindSelect2Lift();
    document.addEventListener('DOMContentLoaded', bindSelect2Lift);
    setTimeout(bindSelect2Lift, 400);
    setTimeout(bindSelect2Lift, 1600);
  }

  applyShell();
  watchStyle();
  watchFrames();
  watchWelcome();
  watchSelects();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyShell, { once: true });
  }
  setTimeout(applyShell, 400);
  setTimeout(applyShell, 1600);

  const api = {
    openDrawer: openDrawer,
    currentDrawer: currentDrawer,
    pageReady: pageReady,
    applyShell: applyShell,
    setFont: setFont,
    setSmooth: setSmooth,
    scrollAt: scrollAt,
  };
  window.__daoyuan = api;
  return api;
})();
''';
}

/// 打开或关闭原生酒馆抽屉。空字符串表示收起全部。
String tavernOpenDrawerScript(String id) =>
    'window.__daoyuan ? window.__daoyuan.openDrawer(${jsonEncode(id)}) : "missing-bridge"';

/// 把 Flutter 界面字体同步进酒馆视口。
String tavernSetFontScript(String id) =>
    'window.__daoyuan ? window.__daoyuan.setFont(${jsonEncode(id)}) : "missing-bridge"';

/// 打开或关闭视口流畅模式（html.daoyuan-smooth）。
String tavernSetSmoothScript(bool on) =>
    'window.__daoyuan ? window.__daoyuan.setSmooth(${on ? 'true' : 'false'}) : "missing-bridge"';

/// 读取当前打开的抽屉 id。
const String kTavernCurrentDrawerScript =
    'window.__daoyuan ? window.__daoyuan.currentDrawer() : ""';

/// 页面是否已进入主界面。
const String kTavernPageReadyScript =
    'window.__daoyuan ? window.__daoyuan.pageReady() : false';
