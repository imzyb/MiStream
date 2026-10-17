/// 生成自动更新的 feed（`latest.json`）。
///
/// 发布流水线在打完 zip 之后调用它。为什么要单独一个工具而不是写在 YAML 里：
/// sha256 与字节数必须从**真实产物**算，写进 YAML 只能靠 shell 拼 JSON，
/// 出错时（少了引号、算了错文件）发布出去才发现，而客户端只会表现为
/// 「更新检查失败」—— 那是排查成本最高的一种失败。
///
/// 用法：
///   dart run tools/gen_update_feed.dart \
///     --zip dist/mistream-v0.2.0-windows-x64.zip \
///     --tag v0.2.0 \
///     [--base-url https://github.com/imzyb/MiStream/releases/download/v0.2.0] \
///     [--channel stable|beta] \
///     [--out dist/latest.json] \
///     [--notes "更新说明"] [--minimum-version 0.1.0]
///
/// 写完会**用客户端那套解析器回读一遍**（`UpdateManifest.parse`）：生成器和
/// 解析器一旦对不上，这里就会红，而不是等到用户点「检查更新」。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:updater/updater.dart';

const String _defaultRepo = 'imzyb/MiStream';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    stdout.writeln(_usage);
    exit(2);
  }

  final zip = File(options['zip']!);
  if (!zip.existsSync()) {
    stderr.writeln('[FATAL] zip 不存在: ${zip.path}');
    exit(2);
  }
  final tag = options['tag']!;
  final versionText = options['version'] ?? tag.replaceFirst(RegExp('^v'), '');
  final channel = UpdateChannel.parse(options['channel']);
  final baseUrl =
      options['base-url'] ??
      'https://github.com/$_defaultRepo/releases/download/$tag';
  final out = File(
    options['out'] ?? p.join(p.dirname(zip.path), 'latest.json'),
  );

  final AppVersion version;
  try {
    version = AppVersion.parse(versionText);
  } on FormatException catch (e) {
    stderr.writeln('[FATAL] 版本号不合法: ${e.message}');
    exit(2);
  }

  final bytes = await zip.readAsBytes();
  if (bytes.isEmpty) {
    stderr.writeln('[FATAL] zip 是 0 字节: ${zip.path}');
    exit(2);
  }
  final digest = sha256.convert(bytes).toString();
  final fileName = p.basename(zip.path);
  final assetUrl = '$baseUrl/$fileName';

  final manifest = <String, Object?>{
    'channel': channel.wireName,
    'version': version.toString(),
    'releasedAt': DateTime.now().toUtc().toIso8601String(),
    if ((options['notes'] ?? '').isNotEmpty) 'notes': options['notes'],
    if (options['minimum-version'] != null)
      'minimumVersion': options['minimum-version'],
    'assets': {
      portableAssetKey: {
        'url': assetUrl,
        'sha256': digest,
        'size': bytes.length,
        'fileName': fileName,
      },
    },
  };

  final body = const JsonEncoder.withIndent('  ').convert(manifest);
  await out.parent.create(recursive: true);
  await out.writeAsString('$body\n', flush: true);

  // 回读校验：生成器与客户端解析器必须是同一套语义。
  final parsed = UpdateManifest.tryParse(body, channel: channel);
  if (parsed == null) {
    stderr.writeln('[FATAL] 生成的 feed 自己解析不了 —— 生成器与解析器已经漂移');
    exit(1);
  }
  if (parsed.version != version ||
      parsed.portable?.sha256 != digest ||
      parsed.portable?.size != bytes.length) {
    stderr.writeln('[FATAL] 回读结果与写入内容不一致');
    exit(1);
  }

  stdout.writeln('feed      : ${out.path}');
  stdout.writeln('channel   : ${channel.wireName}');
  stdout.writeln('version   : $version');
  stdout.writeln('asset     : $assetUrl');
  stdout.writeln('sha256    : $digest');
  stdout.writeln('size      : ${bytes.length} 字节');
}

Map<String, String>? _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) return null;
    final key = arg.substring(2);
    if (i + 1 >= args.length) return null;
    map[key] = args[++i];
  }
  if (map['zip'] == null || map['tag'] == null) return null;
  return map;
}

const String _usage = '''
用法: dart run tools/gen_update_feed.dart --zip <path> --tag <vX.Y.Z>
      [--version X.Y.Z] [--base-url <url>] [--channel stable|beta]
      [--out <path>] [--notes <text>] [--minimum-version <X.Y.Z>]
''';
