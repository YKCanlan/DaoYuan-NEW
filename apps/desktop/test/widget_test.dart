import 'package:daoyuan_desktop/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('默认字体为微软雅黑', () {
    expect(DaoYuanTheme.defaultFontId, DaoYuanTheme.fontYaHei);
    expect(DaoYuanTheme.resolveFontId(null), DaoYuanTheme.fontYaHei);
    expect(DaoYuanTheme.resolveFontId('楷体'), DaoYuanTheme.fontKaiTi);
    expect(DaoYuanTheme.resolveFontId('仿宋'), DaoYuanTheme.fontFangSong);
    expect(DaoYuanTheme.resolveFontId('Microsoft YaHei'), DaoYuanTheme.fontYaHei);
  });

  test('主题色盘保持玄墨发丝线', () {
    expect(DaoYuanTheme.voidPitch, const Color(0xFF030406));
    expect(DaoYuanTheme.jade, DaoYuanTheme.luminousChi);
    final theme = DaoYuanTheme.dark();
    expect(theme.scaffoldBackgroundColor, DaoYuanTheme.voidPitch);
  });
}
