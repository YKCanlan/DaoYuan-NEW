/// 右侧本命灵台。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';

/// 右栏占位。
class HudPanel extends StatelessWidget {
  const HudPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: DaoYuanTheme.glassSurface,
        border: Border(
          left: BorderSide(color: DaoYuanTheme.hairlineBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: DaoYuanTheme.hairlineBorder),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '本命灵台',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: DaoYuanTheme.blindingWhite,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'HUD',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: DaoYuanTheme.ashGhost,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '收起本命灵台',
                  onPressed: () => state.setHudCollapsed(true),
                  icon: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: DaoYuanTheme.ashGhost,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: ListView(
                children: [
                  Text(
                    state.online ? '内核在线' : '等待内核',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DaoYuanTheme.luminousChi,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.online
                        ? 'SillyTavern 正在 ${state.tavernUrl} 运行。'
                            '角色卡、世界书、扩展与生成都在中央视口完成。'
                        : '小手机与世界推衍将作为酒馆之上的壳层能力逐步接入。'
                            '状态权威来自 SillyTavern 会话变量，不再使用独立 Rust 内核。',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: DaoYuanTheme.ashGhost,
                    ),
                  ),
                  if (state.online) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: state.tavernUrl),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      label: Text('复制 ${state.tavernUrl}'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
