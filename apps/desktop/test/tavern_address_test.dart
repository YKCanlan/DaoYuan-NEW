import 'package:daoyuan_desktop/core/host_process.dart';
import 'package:daoyuan_desktop/core/st_launcher.dart';
import 'package:daoyuan_desktop/core/tavern_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('地址后缀留空是根路径，非法或保留名拒绝', () {
    expect(normalizeTavernSuffix('  '), '');
    expect(normalizeTavernSuffix('/Dao-Yuan_/'), 'Dao-Yuan_');
    expect(normalizeTavernSuffix('api'), isNull);
    expect(normalizeTavernSuffix('CSS'), isNull);
    expect(normalizeTavernSuffix('../x'), isNull);
    expect(normalizeTavernSuffix('a/b'), isNull);
    expect(normalizeTavernPort('8100'), 8100);
    expect(normalizeTavernPort('0'), isNull);
    expect(normalizeTavernPort(''), isNull);
    expect(
      tavernEntryUrl(port: 8100, suffix: 'daoyuan'),
      'http://127.0.0.1:8100/daoyuan/',
    );
  });

  test('握手保留后缀，探测地址不再丢掉路径', () {
    final handshake = HostHandshake.fromJson({
      'pid': 4,
      'wrapperPid': 9,
      'port': 8100,
      'url': 'http://127.0.0.1:8100/daoyuan/',
      'urlSuffix': 'daoyuan',
    });
    expect(handshake, isNotNull);
    expect(handshake!.wrapperPid, 9);
    expect(handshake.urlSuffix, 'daoyuan');
    expect(
      handshake.probeUri('csrf-token'),
      Uri.parse('http://127.0.0.1:8100/daoyuan/csrf-token'),
    );
  });

  test('旧握手没有后缀字段时从根地址得到空后缀', () {
    final handshake = HostHandshake.fromJson({
      'pid': 4,
      'port': 8100,
      'url': 'http://127.0.0.1:8100/',
    });
    expect(handshake!.urlSuffix, '');
    expect(handshake.wrapperPid, 0);
    expect(
      handshake.probeUri('csrf-token'),
      Uri.parse('http://127.0.0.1:8100/csrf-token'),
    );
  });

  test('只匹配本次安装的 Node 命令行', () {
    const marker = r'E:\DaoYuan\交付\NEW-Main\scripts\start-tavern.mjs';
    expect(
      commandMatchesInstall(
        r'node.exe E:\DaoYuan\交付\NEW-Main\scripts\start-tavern.mjs --runtime E:\DaoYuan\交付\NEW-Main\runtime',
        const [marker],
      ),
      isTrue,
    );
    expect(
      commandMatchesInstall(
        r'node.exe C:\Users\Admin\pi\cli.js --session E:\DaoYuan\DaoYuan-New',
        const [marker],
      ),
      isFalse,
    );
  });
}
