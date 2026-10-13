import 'package:daoyuan_desktop/core/tavern_bridge.dart';
import 'package:daoyuan_desktop/features/tavern/tavern_drawers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('抽屉 id 唯一且写入注入脚本', () {
    final ids = TavernDrawer.values.map((item) => item.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final item in TavernDrawer.values) {
      expect(kTavernBridgeScript, contains('${item.id}:'));
      expect(kTavernBridgeScript, contains(item.stToggle));
      expect(item.stToggle, contains('.drawer-toggle'));
    }
  });

  test('按 id 查找抽屉', () {
    expect(TavernDrawer.byId('characters'), TavernDrawer.characters);
    expect(TavernDrawer.byId(''), isNull);
    expect(TavernDrawer.byId(null), isNull);
  });

  test('打开抽屉脚本转义 id', () {
    expect(
      tavernOpenDrawerScript('characters'),
      contains('"characters"'),
    );
    expect(tavernOpenDrawerScript(''), contains('openDrawer("")'));
  });

  test('注入脚本含道渊皮肤与字体桥', () {
    expect(kTavernSkinCss, contains('--dy-void: #030406'));
    expect(kTavernSkinCss, contains('--dy-hairline'));
    expect(kTavernSkinCss, contains('--dy-panel-width'));
    expect(kTavernSkinCss, contains('--dy-panel-height'));
    expect(kTavernSkinCss, contains('#character_popup'));
    expect(kTavernBridgeScript, contains('stampFrame'));
    expect(kTavernBridgeScript, contains('scrollAt'));
    expect(kTavernBridgeScript, contains('installWheelGuard'));
    expect(kTavernBridgeScript, contains('shieldFloating'));
    expect(kTavernSkinCss, contains('.drawer-content'));
    expect(kTavernSkinCss, contains('.menu_button'));
    expect(kTavernSkinCss, contains('.popup'));
    expect(kTavernSkinCss, contains('daoyuan-font-kaiti'));
    expect(kTavernSkinCss, contains('daoyuan-font-yahei'));
    expect(kTavernSkinCss, contains('daoyuan-font-fangsong'));
    expect(kTavernSkinCss, contains('--mainFontFamily: var(--dy-font-yahei)'));
    expect(kTavernSkinCss, contains('楷体'));
    expect(kTavernSkinCss, contains('微软雅黑'));
    expect(kTavernSkinCss, contains('仿宋'));
    expect(kTavernBridgeScript, contains('daoyuan-shell-style'));
    expect(kTavernBridgeScript, contains('setFont'));
    expect(kTavernBridgeScript, contains('setSmooth'));
    expect(kTavernSkinCss, contains('daoyuan-smooth'));
    expect(kTavernSkinCss, contains('content-visibility: auto'));
    expect(tavernSetSmoothScript(true), contains('setSmooth(true)'));
    expect(tavernSetSmoothScript(false), contains('setSmooth(false)'));
    expect(kTavernBridgeScript, contains('daoyuan-font-yahei'));
    expect(kTavernBridgeScript, contains('FONT_CLASS.yahei'));
    expect(kTavernBridgeScript, contains('daoyuan-select-menu'));
    expect(kTavernBridgeScript, contains('openSelectMenu'));
    expect(kTavernBridgeScript, contains('floatingAtPoint'));
    expect(kTavernBridgeScript, contains('select2:open'));
    expect(kTavernBridgeScript, contains('placeLiftedSelect2'));
    expect(kTavernSkinCss, contains('-webkit-transform: none'));
    expect(kTavernSkinCss, isNot(contains('width: max-content')));
    expect(kTavernBridgeScript, contains('HTMLDataListElement'));
    expect(kTavernSkinCss, contains('.daoyuan-select-menu'));
    expect(kTavernSkinCss, contains('.select2-dropdown'));
    expect(kTavernBridgeScript, contains('--dy-void'));
    expect(tavernSetFontScript('kaiti'), contains('"kaiti"'));
    expect(tavernSetFontScript('yahei'), contains('setFont("yahei")'));
    expect(kTavernBridgeScript, contains('YKCanlan'));
    expect(kTavernBridgeScript, contains('我是作者 YKCanlan'));
    expect(kTavernBridgeScript, contains('基于酒馆改造的道渊客户端'));
    expect(kTavernBridgeScript, contains('brandWelcome'));
    expect(kTavernBridgeScript, contains('data:image/jpeg;base64,'));
    expect(kWelcomeAssistantName, 'YKCanlan');
  });
}
