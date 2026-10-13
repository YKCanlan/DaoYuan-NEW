/// 道渊视觉主题：道教界面 (Explosive Dynamic Ink Wash & Futuristic Taoist Desktop UI)。
/// 极致冷冽黑白大反差 (Stark Monochrome Chiaroscuro) 与浮空发光毛玻璃发丝线体系。
library;

import 'package:flutter/material.dart';

/// 主题常量与道教玄墨发光色盘。
abstract final class DaoYuanTheme {
  // === 极致冷冽黑白大反差色盘 (Stark Monochrome Chiaroscuro) ===

  /// 极渊深黑底色 (#030406) - 宇宙虚无背景
  static const Color voidPitch = Color(0xFF030406);

  /// 深墨底色 (#080A0E) - 主视口与墨浪底色
  static const Color inkBlack = Color(0xFF080A0E);

  /// 冷白炽光真气 (#FFFFFF) - 主高光、纯白激活态、核心焦点
  static const Color blindingWhite = Color(0xFFFFFFFF);

  /// 发光白气 (#F4F8FC) - 一级正文、白气流体、主发光文字
  static const Color luminousChi = Color(0xFFF4F8FC);

  /// 幽灰次级字色 (#788294) - 次级字色、白描轮廓、沉降元数据
  static const Color ashGhost = Color(0xFF788294);

  /// 金白微光波纹 (#FFF8DC) - 湖面同心波纹、太极流光、天道神纹
  static const Color goldWhiteRipple = Color(0xFFFFF8DC);

  // === 毛玻璃材质与微发丝线 (Glassmorphism & Hairline Tokens) ===

  /// 全透明发光浮空玻璃底色：rgba(8, 10, 14, 0.68)
  static const Color glassSurface = Color(0xAD080A0E);

  /// 极细发光发丝线边框：rgba(255, 255, 255, 0.16)
  static const Color hairlineBorder = Color(0x29FFFFFF);

  /// 聚焦与激活态发丝线边框：rgba(255, 255, 255, 0.35)
  static const Color hairlineBright = Color(0x59FFFFFF);

  /// 发光真气辉光：rgba(255, 255, 255, 0.85)
  static const Color vaporGlow = Color(0xD9FFFFFF);

  /// 极微弱背景白光泛光：rgba(255, 255, 255, 0.04)
  static const Color glassSurfaceLight = Color(0x0AFFFFFF);

  // === 兼容别名映射（平滑对接各子模块，保持一致黑白玄光质感） ===
  static const Color ink = voidPitch;
  static const Color inkSoft = inkBlack;
  static const Color inkRaised = Color(0xFF0F131B);
  static const Color jade = luminousChi;
  static const Color gold = goldWhiteRipple;
  static const Color cinnabar = Color(0xFFF43F5E);
  static const Color mist = ashGhost;

  /// 毛玻璃滤镜模糊度（统一 28px）
  static const double blurSigma = 28.0;

  // === 界面字体（对应用户设定 `ui.fontFamily`） ===

  /// 微软雅黑。
  static const String fontYaHei = 'yahei';

  /// 楷体。
  static const String fontKaiTi = 'kaiti';

  /// 仿宋。
  static const String fontFangSong = 'fangsong';

  /// 缺省界面字体：微软雅黑。
  static const String defaultFontId = fontYaHei;

  /// 用户设定下拉：微软雅黑 / 楷体 / 仿宋。
  static const List<(String, String)> fontChoices = [
    (fontYaHei, '微软雅黑'),
    (fontKaiTi, '楷体'),
    (fontFangSong, '仿宋'),
  ];

  /// 把设定值规整为受支持的字体 id；未知值回落微软雅黑。
  static String resolveFontId(String? raw) {
    switch ((raw ?? '').trim()) {
      case fontYaHei:
      case '微软雅黑':
      case 'Microsoft YaHei':
      case 'Microsoft YaHei UI':
        return fontYaHei;
      case fontFangSong:
      case '仿宋':
      case 'FangSong':
      case 'FangSong_GB2312':
      case 'STFangsong':
        return fontFangSong;
      case fontKaiTi:
      case '楷体':
      case 'KaiTi':
      case 'KaiTi_GB2312':
      case 'STKaiti':
        return fontKaiTi;
      default:
        return defaultFontId;
    }
  }

  /// Windows 中文族名优先，英文族名与通用黑体作为回退。
  static ({String family, List<String> fallback}) fontSpec(String? id) {
    switch (resolveFontId(id)) {
      case fontYaHei:
        return (
          family: '微软雅黑',
          fallback: const [
            'Microsoft YaHei',
            'Microsoft YaHei UI',
            'PingFang SC',
            'Noto Sans CJK SC',
            'Segoe UI',
            'sans-serif',
          ],
        );
      case fontFangSong:
        return (
          family: '仿宋',
          fallback: const [
            'FangSong',
            'FangSong_GB2312',
            'STFangsong',
            '宋体',
            'SimSun',
            '微软雅黑',
            'Microsoft YaHei',
            'serif',
          ],
        );
      case fontKaiTi:
      default:
        return (
          family: '楷体',
          fallback: const [
            'KaiTi',
            'KaiTi_GB2312',
            'STKaiti',
            '宋体',
            'SimSun',
            '微软雅黑',
            'Microsoft YaHei',
            'serif',
          ],
        );
    }
  }

  /// 纯白发光阴影生成器
  static List<BoxShadow> glowShadow({
    Color color = const Color(0x33FFFFFF),
    double blurRadius = 16,
    double spreadRadius = 0,
    Offset offset = Offset.zero,
  }) =>
      [
        BoxShadow(
          color: color,
          blurRadius: blurRadius,
          spreadRadius: spreadRadius,
          offset: offset,
        ),
      ];

  /// 浮空发丝线玻璃装饰
  static BoxDecoration glassDecoration({
    BorderRadius? borderRadius,
    Color backgroundColor = glassSurface,
    Color borderColor = hairlineBorder,
    double borderWidth = 1.0,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
      );

  static ThemeData dark({String? fontFamily}) {
    final spec = fontSpec(fontFamily);
    final scheme = ColorScheme.fromSeed(
      seedColor: blindingWhite,
      brightness: Brightness.dark,
      surface: inkBlack,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: spec.family,
      fontFamilyFallback: spec.fallback,
      colorScheme: scheme.copyWith(
        surface: inkBlack,
        primary: blindingWhite,
        onPrimary: inkBlack,
        secondary: goldWhiteRipple,
        error: cinnabar,
      ),
      scaffoldBackgroundColor: voidPitch,
      canvasColor: inkBlack,
      cardTheme: CardThemeData(
        color: glassSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: hairlineBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: hairlineBorder,
        space: 1,
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: blindingWhite,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        headlineMedium: TextStyle(
          color: blindingWhite,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        titleLarge: TextStyle(
          color: blindingWhite,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
        titleMedium: TextStyle(
          color: luminousChi,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        titleSmall: TextStyle(
          color: luminousChi,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: luminousChi,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          color: luminousChi,
          height: 1.65,
        ),
        bodySmall: TextStyle(
          color: ashGhost,
          height: 1.4,
        ),
      ).apply(
        fontFamily: spec.family,
        fontFamilyFallback: spec.fallback,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A0D13),
        hintStyle: const TextStyle(color: ashGhost, fontSize: 13),
        labelStyle: const TextStyle(color: ashGhost),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: hairlineBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: hairlineBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: blindingWhite, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: inkBlack,
        indicatorColor: blindingWhite,
        selectedIconTheme: IconThemeData(color: inkBlack),
        selectedLabelTextStyle:
            TextStyle(color: blindingWhite, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: ashGhost),
        unselectedIconTheme: IconThemeData(color: ashGhost),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blindingWhite,
          foregroundColor: inkBlack,
          elevation: 0,
          shadowColor: blindingWhite.withValues(alpha: 0.4),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: luminousChi,
          side: const BorderSide(color: hairlineBorder, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: luminousChi,
      ),
    );
  }
}
