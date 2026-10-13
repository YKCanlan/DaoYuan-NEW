/// 本机酒馆地址：端口 + 可选路径后缀。不改 SillyTavern 源码。
library;

const int kDefaultTavernPort = 8100;

const Set<String> kReservedTavernSuffixes = {
  'api',
  'assets',
  'backgrounds',
  'characters',
  'chats',
  'css',
  'csrf-token',
  'extensions',
  'favicon.ico',
  'img',
  'lib',
  'login',
  'script',
  'scripts',
  'sounds',
  'thumbnail',
  'user',
  'version',
  'webfonts',
};

/// 空字符串表示根路径。格式不对时返回 null。
String? normalizeTavernSuffix(String raw) {
  var text = raw.trim();
  while (text.startsWith('/')) {
    text = text.substring(1);
  }
  while (text.endsWith('/')) {
    text = text.substring(0, text.length - 1);
  }
  text = text.trim();
  if (text.isEmpty) return '';
  if (text.length > 64) return null;
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$').hasMatch(text)) return null;
  if (kReservedTavernSuffixes.contains(text.toLowerCase())) return null;
  return text;
}

int? normalizeTavernPort(String raw) {
  final port = int.tryParse(raw.trim());
  if (port == null || port < 1 || port > 65535) return null;
  return port;
}

String tavernEntryUrl({required int port, required String suffix}) {
  if (suffix.isEmpty) return 'http://127.0.0.1:$port/';
  return 'http://127.0.0.1:$port/$suffix/';
}
