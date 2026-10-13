/// 注入到 SillyTavern 文档的道渊 NEW 皮肤。
///
/// 不进 `resources/sillytavern`：由酒馆桥写成 `<style id="daoyuan-shell-style">`。
/// 色盘与 Flutter DaoYuanTheme 对齐（玄墨 / 发丝线 / 毛玻璃 / 界面字体）。
library;

/// 完整皮肤 CSS。禁止出现反引号、`'''` 与孤立 `$`，以便嵌进 JS 字符串。
const String kTavernSkinCss = r'''
html.daoyuan-shell {
  --dy-void: #030406;
  --dy-ink: #080A0E;
  --dy-raised: #0F131B;
  --dy-input: #0A0D13;
  --dy-white: #FFFFFF;
  --dy-chi: #F4F8FC;
  --dy-ash: #788294;
  --dy-gold: #FFF8DC;
  --dy-cinnabar: #F43F5E;
  --dy-glass: rgba(8, 10, 14, 0.78);
  --dy-glass-strong: rgba(8, 10, 14, 0.92);
  --dy-fill: rgba(255, 255, 255, 0.045);
  --dy-fill-hover: rgba(255, 255, 255, 0.10);
  --dy-fill-active: rgba(255, 255, 255, 0.16);
  --dy-hairline: rgba(255, 255, 255, 0.16);
  --dy-hairline-bright: rgba(255, 255, 255, 0.35);
  --dy-radius: 12px;
  --dy-radius-sm: 10px;
  --dy-blur: 28px;
  --dy-inset: 16px;
  --dy-panel-width: min(720px, calc(100dvw - 32px));
  --dy-panel-height: calc(100dvh - 32px);
  --dy-editor-width: min(860px, calc(100dvw - 32px));
  --dy-modal-width: min(520px, calc(100dvw - 48px));
  --dy-modal-max-height: min(70dvh, calc(100dvh - 64px));
  --dy-font-kaiti: 楷体, KaiTi, KaiTi_GB2312, STKaiti, "Noto Serif CJK SC", serif;
  --dy-font-yahei: 微软雅黑, "Microsoft YaHei", "Microsoft YaHei UI", "PingFang SC", "Noto Sans CJK SC", sans-serif;
  --dy-font-fangsong: 仿宋, FangSong, FangSong_GB2312, STFangsong, 宋体, SimSun, serif;

  --topBarBlockSize: 0px !important;
  --topBarIconSize: 0px !important;
  --topBarBlockPadding: 0px !important;
  --blurStrength: 28 !important;
  --shadowWidth: 0 !important;
  --SmartThemeBlurStrength: 28px !important;
  --mainFontFamily: var(--dy-font-yahei) !important;
  --mainFontSize: 15px;

  --SmartThemeBodyColor: #F4F8FC !important;
  --SmartThemeEmColor: #788294 !important;
  --SmartThemeUnderlineColor: rgba(255, 255, 255, 0.55) !important;
  --SmartThemeQuoteColor: #FFF8DC !important;
  --SmartThemeBlurTintColor: rgba(8, 10, 14, 0.78) !important;
  --SmartThemeChatTintColor: rgba(3, 4, 6, 0.42) !important;
  --SmartThemeUserMesBlurTintColor: rgba(255, 255, 255, 0.045) !important;
  --SmartThemeBotMesBlurTintColor: rgba(15, 19, 27, 0.55) !important;
  --SmartThemeShadowColor: rgba(0, 0, 0, 0.45) !important;
  --SmartThemeBorderColor: rgba(255, 255, 255, 0.16) !important;
  --SmartThemeCheckboxBgColorR: 244 !important;
  --SmartThemeCheckboxBgColorG: 248 !important;
  --SmartThemeCheckboxBgColorB: 252 !important;
  --interactable-outline-color: #FFFFFF !important;
  --interactable-outline-color-faint: rgba(255, 255, 255, 0.28) !important;

  --active: #F4F8FC;
  --preferred: #F43F5E;
  --golden: #FFF8DC;
  --warning: rgba(244, 63, 94, 0.92);
  --okGreen70a: rgba(244, 248, 252, 0.18);
  --crimson70a: rgba(244, 63, 94, 0.55);
  --crimson-hover: rgba(244, 63, 94, 0.28);
  --fullred: #F43F5E;
  --greyCAIbg: #080A0E;
  --ivory: #F4F8FC;

  /* 酒馆给 html 加了 translateZ(0) 和 perspective，所有 fixed/absolute 都改相对 html。
     Select2 仍按视口坐标摆菜单，世界书和用户设定里会漂到面板中间。 */
  transform: none !important;
  -webkit-transform: none !important;
  perspective: none !important;
  -webkit-perspective: none !important;
  backface-visibility: visible !important;
  -webkit-backface-visibility: visible !important;
}

html.daoyuan-shell.daoyuan-font-kaiti {
  --mainFontFamily: var(--dy-font-kaiti) !important;
}
html.daoyuan-shell.daoyuan-font-yahei {
  --mainFontFamily: var(--dy-font-yahei) !important;
}
html.daoyuan-shell.daoyuan-font-fangsong {
  --mainFontFamily: var(--dy-font-fangsong) !important;
}

html.daoyuan-shell * {
  text-shadow: none !important;
}

html.daoyuan-shell,
html.daoyuan-shell body {
  touch-action: auto !important;
}
html.daoyuan-shell body {
  background-color: var(--dy-void) !important;
  color: var(--dy-chi) !important;
  font-family: var(--mainFontFamily) !important;
  color-scheme: dark;
}

html.daoyuan-shell #bg1,
html.daoyuan-shell #bg2,
html.daoyuan-shell #bg_custom,
html.daoyuan-shell .background-image {
  filter: saturate(0.28) brightness(0.38) contrast(1.05);
  opacity: 0.22;
}

html.daoyuan-shell #preloader,
html.daoyuan-shell #load-spinner,
html.daoyuan-shell .loader {
  background: var(--dy-void) !important;
  color: var(--dy-chi) !important;
}

html.daoyuan-shell #top-bar {
  display: none !important;
}
html.daoyuan-shell #top-settings-holder {
  height: 0 !important;
  min-height: 0 !important;
  max-height: 0 !important;
  overflow: visible !important;
  margin: 0 !important;
  padding: 0 !important;
  border: none !important;
  background: transparent !important;
  pointer-events: none !important;
}
html.daoyuan-shell #top-settings-holder > .drawer > .drawer-toggle {
  display: none !important;
}
html.daoyuan-shell #top-settings-holder .drawer-content,
html.daoyuan-shell #movingDivs .drawer-content {
  pointer-events: auto !important;
}

html.daoyuan-shell ::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}
html.daoyuan-shell ::-webkit-scrollbar-track {
  background: transparent;
}
html.daoyuan-shell ::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.18);
  border-radius: 99px;
  border: 2px solid transparent;
  background-clip: padding-box;
  box-shadow: none;
}
html.daoyuan-shell ::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.32);
  background-clip: padding-box;
}

html.daoyuan-shell .drawer-content,
html.daoyuan-shell #character_popup,
html.daoyuan-shell #world_popup,
html.daoyuan-shell #dialogue_popup,
html.daoyuan-shell #shadow_popup .dialogue_popup,
html.daoyuan-shell .popup,
html.daoyuan-shell .draggable {
  background: var(--dy-glass) !important;
  color: var(--dy-chi) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius) !important;
  box-shadow:
    0 18px 48px -12px rgba(0, 0, 0, 0.72),
    0 0 0 1px rgba(255, 255, 255, 0.04) inset !important;
  backdrop-filter: blur(var(--dy-blur)) saturate(1.15) !important;
  -webkit-backdrop-filter: blur(var(--dy-blur)) saturate(1.15) !important;
}

html.daoyuan-shell .drawer-content.openDrawer,
html.daoyuan-shell .fillLeft.openDrawer,
html.daoyuan-shell .fillRight.openDrawer {
  background: var(--dy-glass) !important;
}

html.daoyuan-shell .popup[open]::backdrop,
html.daoyuan-shell #shadow_popup {
  background-color: rgba(3, 4, 6, 0.62) !important;
  backdrop-filter: blur(18px) !important;
  -webkit-backdrop-filter: blur(18px) !important;
}

html.daoyuan-shell .drawer-content h2,
html.daoyuan-shell .drawer-content h3,
html.daoyuan-shell .drawer-content h4,
html.daoyuan-shell .popup h3,
html.daoyuan-shell .popup h4,
html.daoyuan-shell #character_popup h3,
html.daoyuan-shell #world_popup h3 {
  color: var(--dy-white) !important;
  letter-spacing: 0.14em;
  font-weight: 600;
}

html.daoyuan-shell #extensions_settings .inline-drawer-toggle.inline-drawer-header,
html.daoyuan-shell #extensions_settings2 .inline-drawer-toggle.inline-drawer-header,
html.daoyuan-shell #user-settings-block h4,
html.daoyuan-shell .standoutHeader,
html.daoyuan-shell .inline-drawer-header,
html.daoyuan-shell .inline-drawer-toggle {
  background-image: none !important;
  background: var(--dy-fill) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
  color: var(--dy-chi) !important;
  filter: none !important;
  letter-spacing: 0.08em;
}
html.daoyuan-shell #extensions_settings .inline-drawer-toggle.inline-drawer-header:hover,
html.daoyuan-shell #extensions_settings2 .inline-drawer-toggle.inline-drawer-header:hover,
html.daoyuan-shell .standoutHeader.inline-drawer-header:hover,
html.daoyuan-shell .inline-drawer-header:hover {
  filter: none !important;
  background: var(--dy-fill-hover) !important;
  border-color: var(--dy-hairline-bright) !important;
}
html.daoyuan-shell .standoutHeader ~ .inline-drawer-content {
  background: rgba(255, 255, 255, 0.03) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
}

html.daoyuan-shell .menu_button,
html.daoyuan-shell button.menu_button,
html.daoyuan-shell input[type="submit"],
html.daoyuan-shell input[type="button"],
html.daoyuan-shell .right_menu_button {
  color: var(--dy-chi) !important;
  background: var(--dy-fill) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
  filter: none !important;
  box-shadow: none !important;
  letter-spacing: 0.04em;
}
html.daoyuan-shell .menu_button:not(.disabled):not([disabled]):hover,
html.daoyuan-shell .menu_button:not(.disabled):not([disabled]).active,
html.daoyuan-shell .right_menu_button:hover,
html.daoyuan-shell .right_menu_button.active,
html.daoyuan-shell input[type="submit"]:hover,
html.daoyuan-shell input[type="button"]:hover {
  background: var(--dy-fill-active) !important;
  border-color: var(--dy-white) !important;
  color: var(--dy-white) !important;
  filter: none !important;
}
html.daoyuan-shell .menu_button.toggleable.toggled,
html.daoyuan-shell .menu_button.selected {
  border-color: var(--dy-white) !important;
  background: var(--dy-fill-active) !important;
  color: var(--dy-white) !important;
}
html.daoyuan-shell .menu_button.toggleable.toggled::before {
  color: var(--dy-white) !important;
}
html.daoyuan-shell .menu_button.api_button:hover {
  background: var(--dy-fill-active) !important;
}

html.daoyuan-shell .text_pole,
html.daoyuan-shell input[type="text"],
html.daoyuan-shell input[type="number"],
html.daoyuan-shell input[type="password"],
html.daoyuan-shell input[type="search"],
html.daoyuan-shell input[type="url"],
html.daoyuan-shell select,
html.daoyuan-shell textarea,
html.daoyuan-shell select.text_pole {
  background: var(--dy-input) !important;
  color: var(--dy-chi) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
  font-family: var(--mainFontFamily) !important;
}
html.daoyuan-shell .text_pole:focus,
html.daoyuan-shell input:focus,
html.daoyuan-shell select:focus,
html.daoyuan-shell textarea:focus {
  border-color: var(--dy-hairline-bright) !important;
  outline: 1px solid rgba(255, 255, 255, 0.18);
}
html.daoyuan-shell .text_pole::placeholder,
html.daoyuan-shell textarea::placeholder,
html.daoyuan-shell #send_textarea::placeholder {
  color: var(--dy-ash) !important;
}

html.daoyuan-shell #send_textarea {
  background: transparent !important;
  border: 0 !important;
  color: var(--dy-chi) !important;
  font-family: var(--mainFontFamily) !important;
}

html.daoyuan-shell input[type="checkbox"] {
  accent-color: var(--dy-white);
  border-color: var(--dy-hairline) !important;
}
html.daoyuan-shell input[type="range"],
html.daoyuan-shell .neo-range-slider {
  accent-color: var(--dy-white);
}
html.daoyuan-shell .range-block-counter input {
  background: var(--dy-input) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: 8px !important;
  color: var(--dy-chi) !important;
}

html.daoyuan-shell .select2-dropdown,
html.daoyuan-shell .select2-container--default .select2-selection--single,
html.daoyuan-shell .select2-container--default .select2-selection--multiple,
html.daoyuan-shell .select2-container .select2-selection {
  background: var(--dy-glass-strong) !important;
  color: var(--dy-chi) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
  box-shadow: 0 16px 40px rgba(0, 0, 0, 0.55) !important;
}
html.daoyuan-shell .select2-container .select2-selection {
  backdrop-filter: blur(var(--dy-blur)) !important;
  -webkit-backdrop-filter: blur(var(--dy-blur)) !important;
}
html.daoyuan-shell .select2-dropdown,
html.daoyuan-shell .select2-container--open,
html.daoyuan-shell .select2-results,
html.daoyuan-shell .select2-search {
  backdrop-filter: none !important;
  -webkit-backdrop-filter: none !important;
}
html.daoyuan-shell .select2-results__option {
  color: var(--dy-chi) !important;
}
html.daoyuan-shell .select2-results__option--highlighted,
html.daoyuan-shell .select2-results__option--selected,
html.daoyuan-shell .select2-container--default .select2-results__option--highlighted[aria-selected] {
  background: var(--dy-fill-active) !important;
  color: var(--dy-white) !important;
}
html.daoyuan-shell .select2-search__field {
  background: var(--dy-input) !important;
  color: var(--dy-chi) !important;
  border: 1px solid var(--dy-hairline) !important;
}

html.daoyuan-shell .options-content,
html.daoyuan-shell .list-group,
html.daoyuan-shell #extensionsMenu,
html.daoyuan-shell #options .options-content,
html.daoyuan-shell .autoComplete-wrap,
html.daoyuan-shell .ui-widget-content,
html.daoyuan-shell .ui-menu {
  background: var(--dy-glass-strong) !important;
  color: var(--dy-chi) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius) !important;
  box-shadow: 0 18px 40px rgba(0, 0, 0, 0.6) !important;
  backdrop-filter: blur(var(--dy-blur)) !important;
}
html.daoyuan-shell .options-content a,
html.daoyuan-shell .list-group-item,
html.daoyuan-shell #extensionsMenu > div,
html.daoyuan-shell #extensionsMenu > .extension_container > div {
  color: var(--dy-chi) !important;
  opacity: 0.88;
}
html.daoyuan-shell .options-content a:hover,
html.daoyuan-shell .list-group-item:hover,
html.daoyuan-shell #extensionsMenu > div:hover,
html.daoyuan-shell #extensionsMenu > .extension_container > div:hover {
  background: var(--dy-fill-hover) !important;
  opacity: 1;
}

html.daoyuan-shell #sheld {
  top: 0 !important;
}
html.daoyuan-shell #chat {
  background-color: var(--SmartThemeChatTintColor) !important;
  backdrop-filter: blur(18px) !important;
}
html.daoyuan-shell #send_form {
  background: var(--dy-glass) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius) !important;
  backdrop-filter: blur(var(--dy-blur)) !important;
  -webkit-backdrop-filter: blur(var(--dy-blur)) !important;
  box-shadow: 0 10px 32px rgba(0, 0, 0, 0.45);
}
html.daoyuan-shell #send_form:has(#send_textarea:focus-visible) {
  border-color: var(--dy-hairline-bright) !important;
  outline: none;
}
html.daoyuan-shell #leftSendForm > div,
html.daoyuan-shell #rightSendForm > div {
  color: var(--dy-ash);
}
html.daoyuan-shell #leftSendForm > div:hover,
html.daoyuan-shell #rightSendForm > div:hover,
html.daoyuan-shell #send_but {
  color: var(--dy-white);
}

html.daoyuan-shell .welcomePanel {
  background: var(--dy-glass) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius) !important;
  backdrop-filter: blur(var(--dy-blur)) !important;
}
html.daoyuan-shell .welcomePanel .welcomeHeaderTitle,
html.daoyuan-shell .welcomePanel .welcomeHeaderVersionDisplay,
html.daoyuan-shell .welcomePanel .recentChatsTitle {
  color: var(--dy-white);
  letter-spacing: 0.12em;
}

html.daoyuan-shell .character_select,
html.daoyuan-shell .group_select,
html.daoyuan-shell .avatar-container,
html.daoyuan-shell .recentChat {
  background: var(--dy-fill) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
}
html.daoyuan-shell .character_select:hover,
html.daoyuan-shell .group_select:hover,
html.daoyuan-shell .character_select.is_selected,
html.daoyuan-shell .character_select.selected,
html.daoyuan-shell .recentChat:hover {
  background: var(--dy-fill-hover) !important;
  border-color: var(--dy-hairline-bright) !important;
}

html.daoyuan-shell .tag,
html.daoyuan-shell .tag.actionable {
  background: var(--dy-fill) !important;
  border: 1px solid var(--dy-hairline) !important;
  color: var(--dy-chi) !important;
  border-radius: 999px !important;
}

html.daoyuan-shell .world_entry,
html.daoyuan-shell .world_entry_form,
html.daoyuan-shell .completion_prompt_manager_list .completion_prompt_manager_list_item,
html.daoyuan-shell .prompt-manager-entry {
  background: var(--dy-fill) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
}

html.daoyuan-shell .CodeMirror,
html.daoyuan-shell .cm-editor {
  background: var(--dy-input) !important;
  color: var(--dy-chi) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
}

html.daoyuan-shell #toast-container > div,
html.daoyuan-shell .toast,
html.daoyuan-shell .toast-success,
html.daoyuan-shell .toast-info,
html.daoyuan-shell .toast-warning,
html.daoyuan-shell .toast-error {
  background: var(--dy-glass-strong) !important;
  color: var(--dy-chi) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
  box-shadow: 0 16px 36px rgba(0, 0, 0, 0.55) !important;
  opacity: 1 !important;
  backdrop-filter: blur(var(--dy-blur)) !important;
}
html.daoyuan-shell .toast-error {
  border-color: rgba(244, 63, 94, 0.55) !important;
}
html.daoyuan-shell .toast-success {
  border-color: var(--dy-hairline-bright) !important;
}
html.daoyuan-shell .toast-title,
html.daoyuan-shell .toast-message,
html.daoyuan-shell .toast-close-button {
  color: var(--dy-chi) !important;
  text-shadow: none !important;
}

html.daoyuan-shell body.login,
html.daoyuan-shell body.login #shadow_popup {
  background: var(--dy-void) !important;
}
html.daoyuan-shell body.login .userSelect {
  background: var(--dy-glass) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius) !important;
  color: var(--dy-chi) !important;
}
html.daoyuan-shell body.login .userSelect:hover {
  background: var(--dy-fill-hover) !important;
  border-color: var(--dy-hairline-bright) !important;
}

html.daoyuan-shell .fav_on,
html.daoyuan-shell .world_set,
html.daoyuan-shell .toggleEnabled {
  color: var(--dy-gold) !important;
}

html.daoyuan-shell a {
  color: var(--dy-chi);
}
html.daoyuan-shell a:hover {
  color: var(--dy-white);
}

html.daoyuan-shell .mes .mes_text {
  font-family: var(--mainFontFamily);
}

/* 居中同框：工作卷 / 编辑卷 / 问对。不改 #sheld。 */
html.daoyuan-shell .drawer-content.openDrawer:not(#cfgConfig):not(#logprobsViewer) {
  position: fixed !important;
  top: var(--dy-inset) !important;
  left: 0 !important;
  right: 0 !important;
  bottom: auto !important;
  transform: none !important;
  width: var(--dy-panel-width) !important;
  min-width: 0 !important;
  max-width: var(--dy-panel-width) !important;
  height: var(--dy-panel-height) !important;
  min-height: 0 !important;
  max-height: var(--dy-panel-height) !important;
  margin: 0 auto !important;
  padding: 16px !important;
  touch-action: pan-y !important;
  border-radius: var(--dy-radius) !important;
  box-sizing: border-box !important;
  display: block !important;
  overflow-x: hidden !important;
  overflow-y: auto !important;
  overscroll-behavior: contain !important;
  resize: none !important;
  z-index: 4010 !important;
  animation: none !important;
  transition: none !important;
}

html.daoyuan-shell .fillLeft.openDrawer,
html.daoyuan-shell .fillRight.openDrawer {
  position: fixed !important;
  top: var(--dy-inset) !important;
  left: 0 !important;
  right: 0 !important;
  bottom: auto !important;
  transform: none !important;
  width: var(--dy-panel-width) !important;
  min-width: 0 !important;
  max-width: var(--dy-panel-width) !important;
  height: var(--dy-panel-height) !important;
  min-height: 0 !important;
  max-height: var(--dy-panel-height) !important;
  margin: 0 auto !important;
}
html.daoyuan-shell .drawer-content.openDrawer:not(#cfgConfig):not(#logprobsViewer) :where(div, section, nav, ul, ol, form, fieldset):not(.select2-results):not(.select2-results__options) {
  height: auto !important;
  max-height: none !important;
  overflow: visible !important;
}
html.daoyuan-shell .drawer-content.openDrawer:not(#cfgConfig):not(#logprobsViewer) :is(textarea, pre, .CodeMirror, .cm-editor, .cm-scroller, .select2-dropdown, .select2-results__options) {
  height: auto !important;
  max-height: 280px !important;
  overflow: auto !important;
}

html.daoyuan-shell .drawer-content {
  transition: none !important;
  animation: none !important;
}
html.daoyuan-shell .drawer-content.openDrawer .scrollableInner,
html.daoyuan-shell .drawer-content.openDrawer .scrollableInnerFull,
html.daoyuan-shell .drawer-content.openDrawer #rm_print_characters_block,
html.daoyuan-shell .drawer-content.openDrawer #rm_ch_create_block {
  height: auto !important;
  max-height: none !important;
  overflow: visible !important;
  flex: none !important;
}
html.daoyuan-shell #WorldInfo.openDrawer #world_popup,
html.daoyuan-shell #WorldInfo.openDrawer #world_popup_entries_list {
  position: relative !important;
  top: auto !important;
  left: auto !important;
  right: auto !important;
  bottom: auto !important;
  transform: none !important;
  width: auto !important;
  min-width: 0 !important;
  max-width: none !important;
  height: auto !important;
  min-height: 0 !important;
  max-height: none !important;
  margin: 0 !important;
  flex: none !important;
  display: block !important;
  overflow: visible !important;
  z-index: auto !important;
}

html.daoyuan-shell #character_popup {
  position: fixed !important;
  top: var(--dy-inset) !important;
  left: 0 !important;
  right: 0 !important;
  bottom: auto !important;
  transform: none !important;
  width: var(--dy-editor-width) !important;
  min-width: 0 !important;
  max-width: var(--dy-editor-width) !important;
  height: var(--dy-panel-height) !important;
  min-height: 0 !important;
  max-height: var(--dy-panel-height) !important;
  margin: 0 auto !important;
  touch-action: pan-y !important;
  padding: 16px !important;
  border-radius: var(--dy-radius) !important;
  box-sizing: border-box !important;
  overflow-x: hidden !important;
  overflow-y: auto !important;
  overscroll-behavior: contain !important;
  resize: none !important;
  z-index: 4050 !important;
}

html.daoyuan-shell #shadow_popup {
  z-index: 4090 !important;
}
html.daoyuan-shell #dialogue_popup,
html.daoyuan-shell #bulk_tag_popup {
  position: fixed !important;
  top: 50% !important;
  left: 50% !important;
  right: auto !important;
  bottom: auto !important;
  transform: translate(-50%, -50%) !important;
  width: var(--dy-modal-width) !important;
  min-width: 0 !important;
  max-width: var(--dy-modal-width) !important;
  height: auto !important;
  min-height: 0 !important;
  max-height: var(--dy-modal-max-height) !important;
  margin: 0 !important;
  padding: 16px 18px !important;
  border-radius: var(--dy-radius) !important;
  box-sizing: border-box !important;
  z-index: 4100 !important;
}
html.daoyuan-shell dialog.popup {
  position: fixed !important;
  top: 50% !important;
  left: 50% !important;
  right: auto !important;
  bottom: auto !important;
  transform: translate(-50%, -50%) !important;
  width: var(--dy-modal-width) !important;
  min-width: 0 !important;
  max-width: var(--dy-modal-width) !important;
  height: fit-content !important;
  min-height: 0 !important;
  max-height: var(--dy-modal-max-height) !important;
  margin: 0 !important;
  padding: 16px 18px !important;
  border-radius: var(--dy-radius) !important;
  box-sizing: border-box !important;
}
html.daoyuan-shell #dialogue_popup.large_dialogue_popup,
html.daoyuan-shell #bulk_tag_popup.large_dialogue_popup,
html.daoyuan-shell dialog.popup.large_dialogue_popup:not(:has(.img_enlarged)) {
  top: var(--dy-inset) !important;
  transform: translateX(-50%) !important;
  width: var(--dy-panel-width) !important;
  max-width: var(--dy-panel-width) !important;
  height: var(--dy-panel-height) !important;
  max-height: var(--dy-panel-height) !important;
}
html.daoyuan-shell #dialogue_popup.wide_dialogue_popup,
html.daoyuan-shell #dialogue_popup.wider_dialogue_popup,
html.daoyuan-shell dialog.popup.wide_dialogue_popup,
html.daoyuan-shell dialog.popup.wider_dialogue_popup {
  width: var(--dy-panel-width) !important;
  min-width: 0 !important;
  max-width: var(--dy-panel-width) !important;
}

html.daoyuan-shell .drag-grabber {
  display: none !important;
}
html.daoyuan-shell .select2-container--open,
html.daoyuan-shell .select2-dropdown {
  z-index: 4700 !important;
}
html.daoyuan-shell #toast-container {
  z-index: 4200 !important;
}

/* WebView2 纹理模式不画系统 <select> 弹层，由桥脚本改用这个页内菜单。 */
html.daoyuan-shell .daoyuan-select-menu,
html.daoyuan-shell .daoyuan-select-menu:popover-open {
  position: fixed !important;
  pointer-events: auto !important;
  inset: auto !important;
  top: auto !important;
  right: auto !important;
  bottom: auto !important;
  left: auto !important;
  z-index: 4800 !important;
  margin: 0 !important;
  transform: none !important;
  padding: 4px !important;
  box-sizing: border-box !important;
  background: #080a0e !important;
  color: var(--dy-chi) !important;
  border: 1px solid var(--dy-hairline) !important;
  border-radius: var(--dy-radius-sm) !important;
  box-shadow: 0 18px 40px rgba(0, 0, 0, 0.6) !important;
  overflow: hidden !important;
}
html.daoyuan-shell .daoyuan-select-list {
  max-height: 280px !important;
  overflow: auto !important;
  overscroll-behavior: contain !important;
  pointer-events: auto !important;
}
html.daoyuan-shell .daoyuan-select-group {
  padding: 6px 10px 2px !important;
  font-size: 11px !important;
  letter-spacing: 0.08em !important;
  color: var(--dy-ash) !important;
}
html.daoyuan-shell .daoyuan-select-option {
  display: block !important;
  width: 100% !important;
  margin: 0 !important;
  padding: 7px 10px !important;
  border: 0 !important;
  border-radius: 8px !important;
  background: transparent !important;
  color: var(--dy-chi) !important;
  font: inherit !important;
  text-align: left !important;
  cursor: pointer !important;
}
html.daoyuan-shell .daoyuan-select-option:hover,
html.daoyuan-shell .daoyuan-select-option.is-selected {
  background: var(--dy-fill-active) !important;
  color: var(--dy-white) !important;
}
html.daoyuan-shell .daoyuan-select-option:disabled {
  opacity: 0.4 !important;
  cursor: default !important;
}
html.daoyuan-shell .daoyuan-select2-lift,
html.daoyuan-shell .daoyuan-select2-lift:popover-open,
html.daoyuan-shell .select2-dropdown {
  pointer-events: auto !important;
}
html.daoyuan-shell .daoyuan-select2-lift,
html.daoyuan-shell .daoyuan-select2-lift:popover-open {
  position: fixed !important;
  margin: 0 !important;
  transform: none !important;
  -webkit-transform: none !important;
  z-index: 4800 !important;
  max-width: calc(100vw - 16px) !important;
  background: #080a0e !important;
  overflow: visible !important;
  backdrop-filter: none !important;
  -webkit-backdrop-filter: none !important;
}
html.daoyuan-shell .daoyuan-select2-lift > .select2-dropdown {
  position: relative !important;
  left: 0 !important;
  top: 0 !important;
  right: auto !important;
  bottom: auto !important;
  width: 100% !important;
  margin: 0 !important;
  transform: none !important;
}

/* 流畅模式：html.daoyuan-smooth 打开。纹理回退仍整帧拷回 CPU，这里只减少脏帧。 */
html.daoyuan-shell.daoyuan-smooth {
  --SmartThemeBlurStrength: 0px;
  --dy-blur: 0px;
  --animation-duration: 0ms;
  --animation-duration-2x: 0ms;
  --animation-duration-3x: 0ms;
  --animation-duration-slow: 0ms;
}
html.daoyuan-shell.daoyuan-smooth #chat,
html.daoyuan-shell.daoyuan-smooth #send_form,
html.daoyuan-shell.daoyuan-smooth .draggable,
html.daoyuan-shell.daoyuan-smooth .drawer-content,
html.daoyuan-shell.daoyuan-smooth #shadow_popup,
html.daoyuan-shell.daoyuan-smooth .welcomePanel,
html.daoyuan-shell.daoyuan-smooth .toast,
html.daoyuan-shell.daoyuan-smooth .toast-error,
html.daoyuan-shell.daoyuan-smooth .select2-dropdown,
html.daoyuan-shell.daoyuan-smooth .ui-menu,
html.daoyuan-shell.daoyuan-smooth .list-group,
html.daoyuan-shell.daoyuan-smooth .ui-widget-content,
html.daoyuan-shell.daoyuan-smooth #character_popup,
html.daoyuan-shell.daoyuan-smooth #options,
html.daoyuan-shell.daoyuan-smooth .info-block {
  backdrop-filter: none !important;
  -webkit-backdrop-filter: none !important;
}
html.daoyuan-shell.daoyuan-smooth .draggable,
html.daoyuan-shell.daoyuan-smooth #bg1,
html.daoyuan-shell.daoyuan-smooth #bg2,
html.daoyuan-shell.daoyuan-smooth #bg_custom,
html.daoyuan-shell.daoyuan-smooth .background-image {
  filter: none !important;
}
html.daoyuan-shell.daoyuan-smooth .mes:not(.last_mes) {
  content-visibility: auto;
  contain-intrinsic-size: auto 140px;
  contain: layout paint style;
}
html.daoyuan-shell.daoyuan-smooth .mes.last_mes {
  contain: layout paint;
}
html.daoyuan-shell.daoyuan-smooth .mes_text .text_segment,
html.daoyuan-shell.daoyuan-smooth .mes_reasoning .text_segment,
html.daoyuan-shell.daoyuan-smooth .slide {
  animation: none !important;
}
''';
