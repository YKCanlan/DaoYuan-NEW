import 'package:daoyuan_desktop/core/tavern_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('解析更新脚本的最后一条 JSON', () {
    const stdout = '''
fetching
DAOYUAN_UPDATE_JSON {"phase":"available","version":"1.19.0","branch":"release","localSha":"06bde939fb1e","remoteSha":"aaaaaaaaaaaa","shallow":true,"message":"官方 release 有新提交。"}
npm noise
''';
    final report = parseTavernUpdateOutput(stdout);
    expect(report.phase, TavernUpdatePhase.available);
    expect(report.version, '1.19.0');
    expect(report.localShort, '06bde93');
    expect(report.remoteShort, 'aaaaaaa');
    expect(report.shallow, isTrue);
    expect(report.behind, isTrue);
  });

  test('没有标记时视为无法检查', () {
    final report = parseTavernUpdateOutput('git failed');
    expect(report.phase, TavernUpdatePhase.unavailable);
  });
}
