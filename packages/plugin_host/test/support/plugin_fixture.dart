import 'dart:convert';
import 'dart:io';

import 'package:plugin_host/plugin_host.dart';

/// 造一份「已下载解压好」的插件产物目录，供 [PluginStore.writeVersion] 复制。
///
/// [marker] 写进 `index.js`，用来验证同名版本被整体替换（而不是新旧混在一起）。
Directory makeVersionSource(
  String root,
  String id,
  String version, {
  String? marker,
}) {
  final sep = Platform.pathSeparator;
  final dir = Directory('$root${sep}sources$sep${id}_$version')
    ..createSync(recursive: true);
  File('${dir.path}${sep}manifest.json').writeAsStringSync(
    jsonEncode({'id': id, 'name': id, 'version': version, 'type': 'source'}),
  );
  File('${dir.path}${sep}index.js').writeAsStringSync(marker ?? '// $version');
  return dir;
}

/// 造一个只含身份信息的 [PluginManifest]。
PluginManifest manifestOf(String id, String version) => PluginManifest(
  id: id,
  name: id,
  version: version,
  type: PluginType.source,
);

/// 可记录的假 [PluginApi]，用来断言「激活了几次」「有没有被激活」。
class RecordingPluginApi implements PluginApi {
  /// 构造。[failActivate] 置 true 后 [onActivate] 会抛异常。
  RecordingPluginApi(this.manifest, {this.failActivate = false});

  @override
  final PluginManifest manifest;

  /// 是否让激活失败，模拟「新版本有问题」。
  bool failActivate;

  /// [onActivate] 被调用的次数。
  int activateCount = 0;

  /// [onDeactivate] 被调用的次数。
  int deactivateCount = 0;

  /// [onDispose] 被调用的次数。
  int disposeCount = 0;

  /// 每次 [onPermissionRevoked] 收到的撤销清单（按调用顺序）。
  final List<List<PluginPermission>> revocations = [];

  /// 置 `true` 后 [onPermissionRevoked] 抛异常，模拟「插件降级处理写崩了」。
  bool failRevokeHandler = false;

  @override
  Future<void> onActivate() async {
    activateCount++;
    if (failActivate) throw StateError('注入的激活失败');
  }

  @override
  Future<void> onDeactivate() async {
    deactivateCount++;
  }

  @override
  Future<void> onDispose() async {
    disposeCount++;
  }

  @override
  Future<void> onPermissionRevoked(List<PluginPermission> revoked) async {
    revocations.add(List.of(revoked));
    if (failRevokeHandler) throw StateError('注入的降级处理失败');
  }
}
