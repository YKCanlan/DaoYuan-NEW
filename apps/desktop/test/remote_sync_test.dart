import 'package:daoyuan_desktop/core/remote_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('解析同步脚本的最后一条 JSON', () {
    const stdout = '''
noise
DAOYUAN_SYNC_JSON {"ok":true,"mode":"sync","remoteVersion":"1.13.0","synced":{"settings":true,"presets":2,"worldInfo":3,"characters":4,"extensions":1,"extensionsSkipped":2},"errors":[],"backup":"daoyuan-sync-1","user":"default-user"}
''';
    final report = parseRemoteSyncOutput(stdout);
    expect(report.ok, isTrue);
    expect(report.settings, isTrue);
    expect(report.presets, 2);
    expect(report.worldInfo, 3);
    expect(report.characters, 4);
    expect(report.extensions, 1);
    expect(report.extensionsSkipped, 2);
    expect(report.user, 'default-user');
    expect(report.describe('sync'), contains('预设 2 份'));
    expect(report.describe('sync'), contains('角色卡 4 张'));
    expect(report.describe('sync'), contains('未覆盖'));
  });

  test('失败时带上错误，没有标记则视为脚本无结果', () {
    final failed = parseRemoteSyncOutput(
      'DAOYUAN_SYNC_JSON {"ok":false,"errors":["/csrf-token 返回 HTTP 401。"],"synced":{"settings":false,"presets":0,"worldInfo":0}}',
    );
    expect(failed.ok, isFalse);
    expect(failed.describe('check'), contains('401'));

    final missing = parseRemoteSyncOutput('node crashed');
    expect(missing.ok, isFalse);
    expect(missing.describe('sync'), contains('没有返回结果'));
  });
}
