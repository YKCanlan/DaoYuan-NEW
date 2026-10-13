/// 微端自己的设置。不打开酒馆「用户设置」抽屉。
library;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/tavern_address.dart';
import '../../core/tavern_update.dart';
import '../../core/theme.dart';

class ShellSettingsPage extends StatelessWidget {
  const ShellSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final report = state.tavernUpdate;
    return ColoredBox(
      color: DaoYuanTheme.voidPitch,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
            children: [
              const Text(
                '微端设置',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: DaoYuanTheme.blindingWhite,
                ),
              ),
              const SizedBox(height: 22),
              _SettingsModule(
                title: '酒馆内核',
                child: _KernelCard(state: state, report: report),
              ),
              const SizedBox(height: 16),
              const _SettingsModule(
                title: '本机地址',
                child: _AddressCard(),
              ),
              const SizedBox(height: 16),
              const _SettingsModule(
                title: '网页端酒馆同步',
                child: _RemoteSyncCard(),
              ),
              const SizedBox(height: 16),
              const _SettingsModule(
                title: '流畅模式',
                child: _SmoothCard(),
              ),
              const SizedBox(height: 16),
              const _SettingsModule(
                title: '界面字体',
                child: _FontCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 微端设置里的一块。默认收起，点标题栏展开或收起。展开状态只留在当前页面，不写进本机偏好。
class _SettingsModule extends StatefulWidget {
  const _SettingsModule({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  State<_SettingsModule> createState() => _SettingsModuleState();
}

class _SettingsModuleState extends State<_SettingsModule> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final action = _expanded ? '收起' : '展开';
    return Container(
      decoration: DaoYuanTheme.glassDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 8, _expanded ? 12 : 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DaoYuanTheme.blindingWhite,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: '$action${widget.title}',
                      child: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 22,
                        color: DaoYuanTheme.ashGhost,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: _expanded ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 12.5, color: DaoYuanTheme.ashGhost),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12.5, color: DaoYuanTheme.luminousChi),
            ),
          ),
        ],
      ),
    );
  }
}

class _KernelCard extends StatelessWidget {
  const _KernelCard({required this.state, required this.report});

  final AppState state;
  final TavernUpdateReport? report;

  @override
  Widget build(BuildContext context) {
    final busy = state.updateBusy ||
        state.bootGate == BootGate.checking ||
        state.bootGate == BootGate.updating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(label: '状态', value: _statusLabel(state, report)),
        _Row(label: '版本', value: _orDash(report?.version)),
        _Row(label: '分支', value: _orDash(report?.branch)),
        _Row(label: '当前提交', value: _orDash(report?.localShort)),
        _Row(label: '官方 release', value: _orDash(report?.remoteShort)),
        if ((report?.message ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            report!.message,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: DaoYuanTheme.luminousChi,
            ),
          ),
        ],
        const Divider(height: 28, color: DaoYuanTheme.hairlineBorder),
        Row(
          children: [
            const Expanded(
              child: Text(
                '自动更新',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: DaoYuanTheme.blindingWhite,
                ),
              ),
            ),
            Switch(
              value: state.autoUpdateTavern,
              onChanged: busy ? null : state.setAutoUpdateTavern,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: busy ? null : state.refreshTavernUpdate,
              child: const Text('立即检查'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: busy || report?.behind != true
                  ? null
                  : state.updateAndRestart,
              child: Text(busy ? '请稍候' : '更新并重启'),
            ),
          ],
        ),
      ],
    );
  }

  static String _orDash(String? value) {
    if (value == null || value.isEmpty) return '—';
    return value;
  }

  static String _statusLabel(AppState state, TavernUpdateReport? report) {
    if (state.bootGate == BootGate.checking ||
        (state.updateBusy && state.bootGate != BootGate.updating)) {
      return '正在检查';
    }
    if (state.bootGate == BootGate.updating) return '正在更新';
    switch (report?.phase) {
      case TavernUpdatePhase.upToDate:
        return '已是最新';
      case TavernUpdatePhase.available:
        return '有更新';
      case TavernUpdatePhase.updated:
        return '刚刚更新';
      case TavernUpdatePhase.failed:
        return '更新失败';
      case TavernUpdatePhase.unavailable:
        return '无法检查';
      case null:
        return '尚未检查';
    }
  }
}

/// 启动时的更新选择，对应启动器菜单的 1 / 2。
class UpdateChoiceDialog extends StatelessWidget {
  const UpdateChoiceDialog({super.key, required this.report});

  final TavernUpdateReport report;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          decoration: DaoYuanTheme.glassDecoration(
            backgroundColor: DaoYuanTheme.inkBlack,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '官方酒馆有更新',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DaoYuanTheme.blindingWhite,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'release ${report.version.isEmpty ? '' : report.version}\n'
                '当前 ${report.localShort.isEmpty ? '未知' : report.localShort}'
                '  →  上游 ${report.remoteShort.isEmpty ? '未知' : report.remoteShort}',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: DaoYuanTheme.ashGhost,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('更新并进入'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('直接进入'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteSyncCard extends StatefulWidget {
  const _RemoteSyncCard();

  @override
  State<_RemoteSyncCard> createState() => _RemoteSyncCardState();
}

class _RemoteSyncCardState extends State<_RemoteSyncCard> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  AppState? _state;
  var _seeded = false;
  var _dirty = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.of(context);
    if (_state != next) {
      _state?.removeListener(_seed);
      _state = next;
      next.addListener(_seed);
    }
    _seed();
  }

  void _seed() {
    final state = _state;
    if (_seeded || _dirty || state == null || !state.uiReady) return;
    _seeded = true;
    _url.text = state.remoteSyncUrl;
    _token.text = state.remoteSyncToken;
    _username.text = state.remoteSyncUsername;
    _password.text = state.remoteSyncPassword;
  }

  @override
  void dispose() {
    _state?.removeListener(_seed);
    _url.dispose();
    _token.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(String mode) async {
    final state = AppScope.of(context);
    if (state.remoteSyncBusy) return;
    if (mode == 'sync') {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => const _SyncConfirmDialog(),
      );
      if (go != true || !mounted) return;
    }
    await AppScope.of(context).runRemoteSync(
      mode: mode,
      url: _url.text,
      token: _token.text,
      username: _username.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final busy = state.remoteSyncBusy;
    final tone = state.remoteSyncTone;
    final messageColor = tone == 'error'
        ? DaoYuanTheme.cinnabar
        : tone == 'ready'
            ? DaoYuanTheme.luminousChi
            : DaoYuanTheme.ashGhost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          label: '网页端酒馆网址',
          controller: _url,
          hint: 'http://127.0.0.1:8000',
        ),
        _field(
          label: '访问令牌（可选）',
          controller: _token,
          hint: 'Bearer Token；无账号模式可留空',
          secret: true,
        ),
        _field(
          label: '网页端账号（可选）',
          controller: _username,
          hint: '启用 Basic Auth 时填写',
          keyboardType: TextInputType.text,
        ),
        _field(
          label: '网页端密码（可选）',
          controller: _password,
          hint: '启用 Basic Auth 时填写',
          secret: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => _run('check'),
              child: const Text('测试连接'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: busy ? null : () => _run('sync'),
              child: Text(busy ? '请稍候' : '同步配置'),
            ),
          ],
        ),
        if (state.remoteSyncMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            state.remoteSyncMessage,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: messageColor),
          ),
        ],
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool secret = false,
    TextInputType keyboardType = TextInputType.url,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: DaoYuanTheme.ashGhost),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: secret,
            enableSuggestions: !secret,
            autocorrect: !secret,
            keyboardType: secret ? TextInputType.visiblePassword : keyboardType,
            style:
                const TextStyle(fontSize: 13, color: DaoYuanTheme.luminousChi),
            decoration: InputDecoration(hintText: hint, isDense: true),
            onChanged: (_) => _dirty = true,
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatefulWidget {
  const _AddressCard();

  @override
  State<_AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends State<_AddressCard> {
  final _port = TextEditingController();
  final _suffix = TextEditingController();
  AppState? _state;
  var _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.of(context);
    if (_state != next) {
      _state?.removeListener(_seed);
      _state = next;
      next.addListener(_seed);
    }
    _seed();
  }

  void _seed() {
    final state = _state;
    if (_seeded || state == null || !state.uiReady) return;
    _seeded = true;
    _port.text = '${state.tavernPortPref}';
    _suffix.text = state.urlSuffix;
  }

  @override
  void dispose() {
    _state?.removeListener(_seed);
    _port.dispose();
    _suffix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final busy = state.addressBusy || state.connection == KernelStatus.launching;
    final tone = state.addressTone;
    final messageColor = tone == 'error'
        ? DaoYuanTheme.cinnabar
        : tone == 'ready'
            ? DaoYuanTheme.luminousChi
            : DaoYuanTheme.ashGhost;
    final previewPort = int.tryParse(_port.text.trim()) ?? state.tavernPortPref;
    final previewSuffix = normalizeTavernSuffix(_suffix.text) ?? _suffix.text.trim();
    final preview = tavernEntryUrl(
      port: previewPort < 1 ? state.tavernPortPref : previewPort,
      suffix: normalizeTavernSuffix(_suffix.text) ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          label: '本地端口',
          controller: _port,
          hint: '8100',
          keyboardType: TextInputType.number,
        ),
        _field(
          label: '地址后缀',
          controller: _suffix,
          hint: '留空，或例如 daoyuan',
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 10),
        Text(
          '打开地址 $preview',
          style: const TextStyle(fontSize: 12.5, color: DaoYuanTheme.luminousChi),
        ),
        if (previewSuffix.isNotEmpty && normalizeTavernSuffix(_suffix.text) == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '这个后缀不能用。',
              style: TextStyle(fontSize: 12, color: DaoYuanTheme.cinnabar),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: busy
                ? null
                : () => state.applyTavernAddress(
                      portText: _port.text,
                      suffixText: _suffix.text,
                    ),
            child: Text(busy ? '请稍候' : '保存并重启'),
          ),
        ),
        if (state.addressMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            state.addressMessage,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: messageColor),
          ),
        ],
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: DaoYuanTheme.ashGhost),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13, color: DaoYuanTheme.luminousChi),
            decoration: InputDecoration(hintText: hint, isDense: true),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}

class _SyncConfirmDialog extends StatelessWidget {
  const _SyncConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          decoration: DaoYuanTheme.glassDecoration(
            backgroundColor: DaoYuanTheme.inkBlack,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '同步网页端配置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DaoYuanTheme.blindingWhite,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '会覆盖本地同名设置、预设、世界书和角色卡，开始前自动备份。第三方插件只补本地还没有的目录。聊天记录和密钥不会动。',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: DaoYuanTheme.ashGhost,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('开始同步'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 字体上方：关掉毛玻璃与正文动画，并把抓帧上限压到 30。
class _SmoothCard extends StatelessWidget {
  const _SmoothCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '开启',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: DaoYuanTheme.blindingWhite,
                ),
              ),
            ),
            Switch(
              value: state.uiSmooth,
              onChanged: state.setUiSmooth,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '关掉聊天区毛玻璃和正文淡入，屏幕外的消息先不画，抓帧上限 30。长消息滚回时高度可能跳一下。默认关闭，玻璃外观不变。不改酒馆内核。',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: DaoYuanTheme.ashGhost,
          ),
        ),
      ],
    );
  }
}

/// 微端设置最后一块：三种内置字体，选中后写入本机偏好并推到酒馆。
class _FontCard extends StatelessWidget {
  const _FontCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < DaoYuanTheme.fontChoices.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _FontChoice(
            id: DaoYuanTheme.fontChoices[i].$1,
            label: DaoYuanTheme.fontChoices[i].$2,
            selected: state.uiFontFamily == DaoYuanTheme.fontChoices[i].$1,
            onTap: () => state.setFontFamily(DaoYuanTheme.fontChoices[i].$1),
          ),
        ],
      ],
    );
  }
}

class _FontChoice extends StatelessWidget {
  const _FontChoice({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = DaoYuanTheme.fontSpec(id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? DaoYuanTheme.glassSurfaceLight
                : const Color(0xFF0A0D13),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? DaoYuanTheme.blindingWhite
                  : DaoYuanTheme.hairlineBorder,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
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
                    fontFamily: spec.family,
                    fontFamilyFallback: spec.fallback,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? DaoYuanTheme.blindingWhite
                        : DaoYuanTheme.luminousChi,
                  ),
                ),
              ),
              if (id == DaoYuanTheme.defaultFontId)
                const Text(
                  '默认',
                  style: TextStyle(fontSize: 11.5, color: DaoYuanTheme.ashGhost),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
