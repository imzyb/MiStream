import 'dart:io';

import 'package:libmpv_dist/libmpv_dist.dart';

const _usage =
    '''
用法：
  libmpv_dist install [--dest <目录>] [--cache <文件>]
      下载锁定版本的 libmpv 归档、校验 SHA256、解包并把 ${'libmpv-2.dll'} 装进目录。
      已存在且校验通过时直接复用（幂等）。
  libmpv_dist verify <libmpv-2.dll 路径>
      校验一个已安装的 DLL 是否与清单中的 dllSha256 一致。
  libmpv_dist manifest
      打印当前锁定的版本与哈希。

任何校验失败都以退出码 1 结束。清单依据 docs/03-技术选型.md §2。
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    stdout.write(_usage);
    exit(args.isEmpty ? 64 : 0);
  }

  final manifest = LibmpvManifest.fromJson(
    File.fromUri(
      Platform.script.resolve('../assets/libmpv.manifest.json'),
    ).readAsStringSync(),
  );

  try {
    switch (args.first) {
      case 'install':
        await _install(manifest, args.skip(1).toList());
      case 'verify':
        await _verify(manifest, _requireValue(args, 'verify'));
      case 'manifest':
        _printManifest(manifest);
      default:
        stderr.writeln('未知子命令「${args.first}」\n');
        stdout.write(_usage);
        exit(64);
    }
  } on LibmpvException catch (e) {
    stderr.writeln('libmpv 分发失败：$e');
    exit(1);
  }
}

Future<void> _install(LibmpvManifest manifest, List<String> args) async {
  final dest = Directory(_flag(args, 'dest') ?? 'build/libmpv');
  final cache = File(
    _flag(args, 'cache') ?? 'build/libmpv-cache/${manifest.archive}',
  );

  final distribution = LibmpvDistribution(manifest: manifest);
  final dll = await distribution.install(cache, dest);

  stdout.writeln(
    'libmpv ${manifest.version}（${manifest.platform}）已就绪：${dll.path}',
  );
  stderr.writeln(
    '  运行时指定：MediaKitRuntime.ensureInitialized(libmpv: "${dll.path}")',
  );
}

Future<void> _verify(LibmpvManifest manifest, String path) async {
  final dll = File(path);
  if (!dll.existsSync()) {
    throw LibmpvException('文件不存在：$path');
  }
  final actual = await sha256Of(dll);
  if (actual != manifest.dllSha256.toLowerCase()) {
    throw LibmpvException(
      'SHA256 不匹配：期望 ${manifest.dllSha256}，实际 $actual',
    );
  }
  stdout.writeln('校验通过：$path 与清单一致（libmpv ${manifest.version}）');
}

void _printManifest(LibmpvManifest manifest) {
  stdout
    ..writeln('libmpv 锁定版本：${manifest.version}')
    ..writeln('平台：${manifest.platform}')
    ..writeln('归档：${manifest.archive}')
    ..writeln('归档 SHA256：${manifest.sha256}')
    ..writeln('${manifest.dll} SHA256：${manifest.dllSha256}')
    ..writeln('来源：${manifest.url}');
}

String? _flag(List<String> args, String name) {
  final index = args.indexOf('--$name');
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

String _requireValue(List<String> args, String flag) {
  if (args.length < 2) {
    stderr.writeln('$flag 需要一个参数');
    exit(64);
  }
  return args[1];
}
