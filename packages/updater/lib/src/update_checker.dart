/// 判断「要不要更新」。
///
/// 这一层刻意**不做网络、不碰文件**：输入是「当前版本 + 一份清单」，输出是
/// 一个决策。这样「强制更新」「本平台没有包」「已经是最新」这些分支都能用
/// 纯函数测，不必造 zip、不必连网。
library;

import 'package:updater/src/update_manifest.dart';
import 'package:updater/src/update_version.dart';

/// 检查结论。
enum UpdateStatus {
  /// 已经是最新（或比 feed 还新）。
  upToDate,

  /// 有新版本，且本平台有包。
  available,

  /// 有新版本，但 feed 里没有本平台的资产。
  ///
  /// 与「失败」区分开：这说明发布流水线漏了某个平台，属于**发布侧缺陷**，
  /// UI 该提示「暂无适用于本机的更新包」，而不是「检查更新失败」。
  noAsset,

  /// 当前版本比 feed 还新（用户装了 beta 或本地构建）。
  currentAhead,
}

/// 一次检查的结果。
final class UpdateCheckResult {
  /// 构造。
  const UpdateCheckResult({
    required this.status,
    required this.manifest,
    required this.current,
    this.asset,
    this.forced = false,
  });

  /// 结论。
  final UpdateStatus status;

  /// 用到的清单。
  final UpdateManifest manifest;

  /// 当前版本。
  final AppVersion current;

  /// 可下载的资产（[UpdateStatus.available] 时非空）。
  final UpdateAsset? asset;

  /// 是否**强制**更新（当前版本低于 `minimumVersion`）。
  final bool forced;

  /// 是否值得提示用户。
  bool get shouldPrompt => status == UpdateStatus.available;

  @override
  String toString() =>
      'UpdateCheckResult(${status.name}, current=$current, '
      'latest=${manifest.version}, forced=$forced)';
}

/// 版本检查器。
final class UpdateChecker {
  /// 构造。
  const UpdateChecker({this.assetKey = portableAssetKey});

  /// 本机需要的资产键。
  final String assetKey;

  /// 评估一份清单。
  ///
  /// 顺序很重要：
  ///   1. 先判「有没有更新」—— 版本没变就绝不该提示，哪怕 `minimumVersion`
  ///      写错了（写错是发布侧的事，不该变成用户侧的骚扰）；
  ///   2. 再看本平台有没有包；
  ///   3. 最后算是否强制。
  UpdateCheckResult evaluate({
    required AppVersion current,
    required UpdateManifest manifest,
  }) {
    final diff = manifest.version.compareTo(current);
    final min = manifest.minimumVersion;
    final forced = min != null && current.compareTo(min) < 0;

    if (diff == 0) {
      return UpdateCheckResult(
        status: UpdateStatus.upToDate,
        manifest: manifest,
        current: current,
      );
    }
    if (diff < 0) {
      return UpdateCheckResult(
        status: UpdateStatus.currentAhead,
        manifest: manifest,
        current: current,
        forced: forced,
      );
    }
    final asset = manifest.assetFor(assetKey);
    if (asset == null) {
      return UpdateCheckResult(
        status: UpdateStatus.noAsset,
        manifest: manifest,
        current: current,
        forced: forced,
      );
    }
    return UpdateCheckResult(
      status: UpdateStatus.available,
      manifest: manifest,
      current: current,
      asset: asset,
      forced: forced,
    );
  }
}
