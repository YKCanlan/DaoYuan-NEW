/// 应用主外壳：左栏 + 顶栏 + 中央酒馆视口 + 右侧灵台。
/// 视觉语言保留 NEW 版；功能抽屉点击原生 SillyTavern 面板。
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../hud/hud_panel.dart';
import '../tavern/tavern_drawers.dart';
import '../tavern/tavern_view.dart';
import 'shell_settings_page.dart';

const double _navWidth = 240;
const double _hudWidth = 380;
const double _topBarHeight = 50;

/// 主外壳。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppState? _state;
  bool _askingUpdate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.of(context);
    if (_state != next) {
      _state?.removeListener(_onAppState);
      _state = next;
      next.addListener(_onAppState);
    }
    _onAppState();
  }

  void _onAppState() {
    final state = _state;
    if (state == null || !state.pendingUpdateChoice || _askingUpdate || !mounted) {
      return;
    }
    final report = state.tavernUpdate;
    if (report == null) return;
    _askingUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final apply = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateChoiceDialog(report: report),
      );
      state.decideUpdate(apply == true);
      _askingUpdate = false;
    });
  }

  @override
  void dispose() {
    _state?.removeListener(_onAppState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final activeDrawer = TavernDrawer.byId(state.activeDrawerId);
    return Scaffold(
      backgroundColor: DaoYuanTheme.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              _Collapsible(
                collapsed: state.navCollapsed,
                width: _navWidth,
                child: _NavBody(
                  activeDrawer: activeDrawer,
                  shellSettingsOpen: state.shellSettingsOpen,
                  onSelectPlay: state.selectPlay,
                  onSelectDrawer: (drawer) => state.selectDrawer(drawer.id),
                  onSelectSettings: state.selectShellSettings,
                  onCollapse: () => state.setNavCollapsed(true),
                ),
              ),
              if (!state.navCollapsed) const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _TavernTopBar(
                      activeDrawer: activeDrawer,
                      state: state,
                      onToggleDrawer: (drawer) => state.selectDrawer(drawer.id),
                      onSelectPlay: state.selectPlay,
                    ),
                    const Divider(height: 1),
                    const Expanded(
                      child: _MainViewport(),
                    ),
                  ],
                ),
              ),
              if (!state.hudCollapsed) const VerticalDivider(width: 1),
              _Collapsible(
                collapsed: state.hudCollapsed,
                width: _hudWidth,
                child: const HudPanel(),
              ),
            ],
          ),
          if (state.navCollapsed)
            Positioned(
              left: 6,
              top: 60,
              child: _EdgeHandle(
                tooltip: '展开山门总览（左栏）',
                icon: Icons.chevron_right,
                onTap: () => state.setNavCollapsed(false),
              ),
            ),
          if (state.hudCollapsed)
            Positioned(
              right: 6,
              top: 60,
              child: _EdgeHandle(
                tooltip: '展开本命灵台（右栏）',
                icon: Icons.chevron_left,
                onTap: () => state.setHudCollapsed(false),
              ),
            ),
        ],
      ),
    );
  }
}

class _RotatingTaiChiEmblem extends StatefulWidget {
  const _RotatingTaiChiEmblem({this.size = 18});

  final double size;

  @override
  State<_RotatingTaiChiEmblem> createState() => _RotatingTaiChiEmblemState();
}

class _RotatingTaiChiEmblemState extends State<_RotatingTaiChiEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _MiniTaiChiPainter(angle: _controller.value * 2 * math.pi),
          );
        },
      ),
    );
  }
}

class _MiniTaiChiPainter extends CustomPainter {
  const _MiniTaiChiPainter({required this.angle});

  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 0.8;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final whitePaint = Paint()
      ..color = DaoYuanTheme.blindingWhite
      ..style = PaintingStyle.fill;
    final blackPaint = Paint()
      ..color = DaoYuanTheme.voidPitch
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = DaoYuanTheme.blindingWhite.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    canvas.drawCircle(Offset.zero, radius, blackPaint);

    final path = Path();
    path.arcTo(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      -math.pi / 2,
      math.pi,
      false,
    );
    path.arcTo(
      Rect.fromCircle(center: Offset(0, -radius / 2), radius: radius / 2),
      math.pi / 2,
      math.pi,
      false,
    );
    path.arcTo(
      Rect.fromCircle(center: Offset(0, radius / 2), radius: radius / 2),
      math.pi / 2,
      -math.pi,
      false,
    );
    canvas.drawPath(path, whitePaint);

    canvas.drawCircle(Offset(0, -radius / 2), radius * 0.18, blackPaint);
    canvas.drawCircle(Offset(0, radius / 2), radius * 0.18, whitePaint);
    canvas.drawCircle(Offset.zero, radius, ringPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniTaiChiPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

class _TavernTopBar extends StatelessWidget {
  const _TavernTopBar({
    required this.activeDrawer,
    required this.state,
    required this.onToggleDrawer,
    required this.onSelectPlay,
  });

  final TavernDrawer? activeDrawer;
  final AppState state;
  final ValueChanged<TavernDrawer> onToggleDrawer;
  final VoidCallback onSelectPlay;

  @override
  Widget build(BuildContext context) {
    final isPlayActive = activeDrawer == null && !state.shellSettingsOpen;
    final online = state.online;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: DaoYuanTheme.blurSigma,
          sigmaY: DaoYuanTheme.blurSigma,
        ),
        child: Container(
          height: _topBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: DaoYuanTheme.glassSurface,
            border: Border(
              bottom: BorderSide(color: DaoYuanTheme.hairlineBorder, width: 1),
            ),
          ),
          child: Row(
            children: [
              Tooltip(
                message: '推演演义（天道长卷 · 酒馆核心聊天视口）',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onSelectPlay,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPlayActive
                          ? DaoYuanTheme.blindingWhite.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPlayActive
                            ? DaoYuanTheme.hairlineBright
                            : DaoYuanTheme.hairlineBorder,
                      ),
                      boxShadow: isPlayActive
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.2),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _RotatingTaiChiEmblem(size: 16),
                        const SizedBox(width: 7),
                        Text(
                          '天道推演',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isPlayActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isPlayActive
                                ? DaoYuanTheme.blindingWhite
                                : DaoYuanTheme.ashGhost,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                height: 20,
                child: VerticalDivider(
                    width: 1, color: DaoYuanTheme.hairlineBorder),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in TavernDrawer.values) ...[
                        _TavernIconButton(
                          icon: item.icon,
                          tooltip: '${item.label} (${item.english})',
                          isActive: activeDrawer == item,
                          onTap: () => onToggleDrawer(item),
                        ),
                        const SizedBox(width: 3),
                      ],
                    ],
                  ),
                ),
              ),
              _Pill(
                icon: online ? Icons.memory : Icons.hourglass_empty,
                label: online
                    ? '酒馆内核 · :${state.tavernPort}'
                    : state.bootGate == BootGate.checking
                        ? '正在检查更新'
                        : state.bootGate == BootGate.awaitingChoice
                            ? '等待更新选择'
                            : state.bootGate == BootGate.updating
                                ? '正在更新内核'
                                : state.connection == KernelStatus.launching
                                    ? '正在拉起'
                                    : '未连接',
                color: online
                    ? DaoYuanTheme.blindingWhite
                    : DaoYuanTheme.ashGhost,
                compact: true,
                tooltip: online
                    ? 'SillyTavern 正在 ${state.tavernUrl} 运行'
                    : state.connectionError.isEmpty
                        ? '酒馆内核未连接'
                        : state.connectionError,
                onTap: state.connect,
              ),
              const SizedBox(width: 4),
              const SizedBox(
                height: 20,
                child: VerticalDivider(
                    width: 1, color: DaoYuanTheme.hairlineBorder),
              ),
              Tooltip(
                message: state.hudCollapsed ? '展开本命灵台 (HUD)' : '收起本命灵台 (铺满聊天)',
                child: IconButton(
                  constraints:
                      const BoxConstraints.tightFor(width: 30, height: 30),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    state.hudCollapsed
                        ? Icons.view_sidebar_outlined
                        : Icons.view_sidebar,
                    size: 18,
                    color: !state.hudCollapsed
                        ? DaoYuanTheme.blindingWhite
                        : DaoYuanTheme.ashGhost,
                  ),
                  onPressed: () =>
                      state.setHudCollapsed(!state.hudCollapsed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TavernIconButton extends StatelessWidget {
  const _TavernIconButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive
            ? DaoYuanTheme.blindingWhite.withValues(alpha: 0.16)
            : DaoYuanTheme.voidPitch.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? DaoYuanTheme.blindingWhite
                    : DaoYuanTheme.hairlineBorder,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.18),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 17,
              color:
                  isActive ? DaoYuanTheme.blindingWhite : DaoYuanTheme.ashGhost,
            ),
          ),
        ),
      ),
    );
  }
}

class _Collapsible extends StatelessWidget {
  const _Collapsible({
    required this.collapsed,
    required this.width,
    required this.child,
  });

  final bool collapsed;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: collapsed ? 0 : width,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: DaoYuanTheme.voidPitch),
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: width,
        maxWidth: width,
        child: SizedBox(width: width, child: child),
      ),
    );
  }
}

class _EdgeHandle extends StatelessWidget {
  const _EdgeHandle({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: DaoYuanTheme.voidPitch.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DaoYuanTheme.hairlineBorder),
            ),
            child: Icon(icon, size: 16, color: DaoYuanTheme.blindingWhite),
          ),
        ),
      ),
    );
  }
}

class _MainViewport extends StatelessWidget {
  const _MainViewport();

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).shellSettingsOpen;
    return IndexedStack(
      index: settings ? 1 : 0,
      children: const [
        TavernView(),
        ShellSettingsPage(),
      ],
    );
  }
}

class _NavBody extends StatelessWidget {
  const _NavBody({
    required this.activeDrawer,
    required this.shellSettingsOpen,
    required this.onSelectPlay,
    required this.onSelectDrawer,
    required this.onSelectSettings,
    required this.onCollapse,
  });

  final TavernDrawer? activeDrawer;
  final bool shellSettingsOpen;
  final VoidCallback onSelectPlay;
  final ValueChanged<TavernDrawer> onSelectDrawer;
  final VoidCallback onSelectSettings;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final isPlay = activeDrawer == null && !shellSettingsOpen;
    return Container(
      decoration: const BoxDecoration(
        color: DaoYuanTheme.glassSurface,
        border: Border(
          right: BorderSide(color: DaoYuanTheme.hairlineBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 8, 12),
            child: _BrandMark(),
          ),
          const Divider(height: 1, color: DaoYuanTheme.hairlineBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  label: '推演演义',
                  icon: Icons.forum_outlined,
                  selected: isPlay,
                  onTap: onSelectPlay,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Divider(height: 1, color: DaoYuanTheme.hairlineBorder),
                ),
                for (final item in TavernDrawer.values)
                  _NavItem(
                    label: item.label,
                    icon: item.icon,
                    selected: !shellSettingsOpen && activeDrawer == item,
                    onTap: () => onSelectDrawer(item),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: DaoYuanTheme.hairlineBorder),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 12, 2),
            child: Text(
              '道渊微端',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                color: DaoYuanTheme.ashGhost,
              ),
            ),
          ),
          _NavItem(
            label: '微端设置',
            icon: Icons.tune,
            selected: shellSettingsOpen,
            onTap: onSelectSettings,
          ),
          const Divider(height: 1, color: DaoYuanTheme.hairlineBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
            child: Row(
              children: [
                const Text(
                  '收起左栏（铺满视口）',
                  style: TextStyle(fontSize: 11, color: DaoYuanTheme.ashGhost),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '收起左侧功能栏',
                  onPressed: onCollapse,
                  icon: const Icon(Icons.chevron_left,
                      size: 20, color: DaoYuanTheme.ashGhost),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? DaoYuanTheme.blindingWhite.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    selected ? DaoYuanTheme.hairlineBright : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: selected
                        ? DaoYuanTheme.blindingWhite
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.6),
                              blurRadius: 6,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? DaoYuanTheme.blindingWhite
                      : DaoYuanTheme.ashGhost,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? DaoYuanTheme.blindingWhite
                          : DaoYuanTheme.luminousChi,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: DaoYuanTheme.voidPitch,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: DaoYuanTheme.blindingWhite.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.12),
                blurRadius: 10,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const _RotatingTaiChiEmblem(size: 22),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '道渊',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: DaoYuanTheme.blindingWhite,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: DaoYuanTheme.blindingWhite.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: DaoYuanTheme.hairlineBorder),
                  ),
                  child: const Text(
                    '矩阵',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: DaoYuanTheme.goldWhiteRipple,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'DAOYUAN MATRIX · 渊极演义',
              style: TextStyle(
                fontSize: 8,
                color: DaoYuanTheme.ashGhost,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? tooltip;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: tooltip ?? label,
        child: Material(
          color: DaoYuanTheme.voidPitch.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DaoYuanTheme.hairlineBorder),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
