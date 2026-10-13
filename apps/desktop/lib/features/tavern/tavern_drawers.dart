/// 道渊壳层抽屉，id 必须与 `tavern_bridge.dart` 里的 MAP 键一致。
library;

import 'package:flutter/material.dart';

/// 对齐原生 SillyTavern 顶栏抽屉。
enum TavernDrawer {
  apiConnect(
    id: 'api_connect',
    label: 'API 连接',
    english: 'API Connections',
    icon: Icons.hub_outlined,
    stToggle: '#sys-settings-button > .drawer-toggle',
  ),
  generationParams(
    id: 'api_params',
    label: 'AI 响应配置',
    english: 'AI Response Configuration',
    icon: Icons.tune,
    stToggle: '#ai-config-button > .drawer-toggle',
  ),
  advancedFormatting(
    id: 'prompt',
    label: '高级格式化',
    english: 'Advanced Formatting',
    icon: Icons.code_outlined,
    stToggle: '#advanced-formatting-button > .drawer-toggle',
  ),
  characters(
    id: 'characters',
    label: '角色管理',
    english: 'Characters',
    icon: Icons.badge_outlined,
    stToggle: '#rightNavHolder > .drawer-toggle',
  ),
  worldbook(
    id: 'worldbook',
    label: '世界书',
    english: 'World Info',
    icon: Icons.menu_book_outlined,
    stToggle: '#WI-SP-button > .drawer-toggle',
  ),
  persona(
    id: 'persona',
    label: '用户设定',
    english: 'Persona Management',
    icon: Icons.face_6_outlined,
    stToggle: '#persona-management-button > .drawer-toggle',
  ),
  extensions(
    id: 'extensions',
    label: '拓展程序',
    english: 'Extensions',
    icon: Icons.extension_outlined,
    stToggle: '#extensions-settings-button > .drawer-toggle',
  ),
  userSettings(
    id: 'system',
    label: '用户设置',
    english: 'User Settings',
    icon: Icons.settings_outlined,
    stToggle: '#user-settings-button > .drawer-toggle',
  );

  const TavernDrawer({
    required this.id,
    required this.label,
    required this.english,
    required this.icon,
    required this.stToggle,
  });

  final String id;
  final String label;
  final String english;
  final IconData icon;

  /// SillyTavern `.drawer-toggle` 选择器（只读对照，实际点击由注入脚本执行）。
  final String stToggle;

  static TavernDrawer? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in values) {
      if (item.id == id) return item;
    }
    return null;
  }
}
