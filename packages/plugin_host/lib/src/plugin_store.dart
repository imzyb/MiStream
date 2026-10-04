import 'dart:convert';
import 'dart:io';

import 'package:plugin_host/src/plugin_api.dart';
import 'package:plugin_host/src/plugin_manifest.dart';

/// 一个已经落到磁盘上的插件版本。
///
/// 与「被 [PluginManager] 激活过」是两回事：这个类只描述磁盘上的产物，
/// 不涉及任何运行态。同 id 可以有多个 [DownloadedPlugin] 共存。
class DownloadedPlugin {
  /// 构造。
  const DownloadedPlugin({required this.manifest, required this.versionDir});

  /// 该版本的 manifest。
  final PluginManifest manifest;

  /// 该版本产物的来源目录（[PluginStore.writeVersion] 会把它整个复制进版本库）。
  final String versionDir;
}

/// 某个插件当前发布出去的版本，以及它的上一个版本。
///
/// [previousVersion] 是 [PluginStore.rollback] 的唯一目标。它**不落盘**：
/// 内存里精确记录，重启后由 [PluginStore.init] 从磁盘尽力重建（取低于当前
/// 版本的最高版本）。之所以不落盘，是与 `sourceTearDownsPerProcess` 这类
/// 运行态计数保持一致 —— 磁盘上只留一个「当前版本」的事实，其余都可以推导。
class _Published {
  const _Published({required this.version, this.previousVersion});

  final String version;
  final String? previousVersion;
}

/// 插件的磁盘版本库：多版本共存 + 单次原子切换的「当前版本」指针。
///
/// 磁盘布局：
///
/// ```text
/// <pluginsDirectory>/
///   <pluginId>/
///     versions/
///       <version>/          # 每个版本一个目录，内含 manifest.json
///     files/
///       current             # 指针：内容就是当前发布的版本号
/// ```
///
/// 两个关键决策，都是实测逼出来的：
///
/// 1. **指针是文件不是目录**。本机实测 `Directory.renameSync` 覆盖已存在的
///    非空目录会抛 `PathExistsException`，而 `File.renameSync` 覆盖已存在的
///    文件是允许的。用文件做指针，切换就是**一次 rename**，天然原子：断电或
///    被杀进程只会看到「旧版本」或「新版本」，不存在中间态。
/// 2. **写入先落 staging 再换名**。同卷内 `renameSync` 是原子的，所以
///    [writeVersion] 不会留下「写了一半的版本目录」。
///
/// 升级与回滚的语义见 [upgrade] / [rollback]。
class PluginStore {
  /// 构造。
  ///
  /// [publishPointer] 是「指针已经切好了，请让运行时重新加载」的通知钩子。
  /// 默认什么都不做；装配层接上它就能让新版本立刻生效。它**失败不改回指针**
  /// —— 见 [upgrade] 的说明。
  PluginStore({
    required this.pluginsDirectory,
    Future<void> Function(String pluginId, String version)? publishPointer,
  }) : _publishPointer = publishPointer;

  /// 插件根目录，其下每个子目录是一个插件的版本库。
  final String pluginsDirectory;

  final Future<void> Function(String pluginId, String version)? _publishPointer;

  final Map<String, _Published> _published = <String, _Published>{};

  static final String _sep = Platform.pathSeparator;

  /// 扫磁盘、读指针、把内存状态重建起来。
  ///
  /// 三件事：
  /// - 清掉上次没跑完留下的 `.staging_*` / `.backup_*` 残留目录；
  /// - 按 `files/current` 恢复「当前版本」；
  /// - 指针丢了、内容是垃圾、或指向一个已经不存在的版本目录时，回退到磁盘上
  ///   最高的版本，并把指针补回去（否则下次启动还会再回退一次，且发布态无从
  ///   判断）。
  Future<void> init() async {
    final root = Directory(pluginsDirectory);
    if (!root.existsSync()) return;

    for (final entity in root.listSync()) {
      if (entity is! Directory) continue;
      final pluginId = _basename(entity.path);
      _cleanupResidue(pluginId);

      final versions = _versionDirs(pluginId);
      if (versions.isEmpty) continue;

      final pointer = _readPointer(pluginId);
      if (pointer != null && versions.contains(pointer)) {
        _published[pluginId] = _Published(
          version: pointer,
          previousVersion: _highestBelow(pluginId, pointer),
        );
      } else {
        // 指针丢失或指向已删目录：磁盘上最高的版本就是事实。
        final highest = _sorted(versions).last;
        _published[pluginId] = _Published(
          version: highest,
          previousVersion: _highestBelow(pluginId, highest),
        );
        _writePointer(pluginId, highest);
      }
    }
  }

  /// 某个插件当前发布的版本号；从未发布过返回 `null`。
  String? currentVersionOf(String pluginId) => _published[pluginId]?.version;

  /// 某个插件可回滚到的版本号；没有可回滚目标时返回 `null`。
  String? previousVersionOf(String pluginId) =>
      _published[pluginId]?.previousVersion;

  /// 读某个已落盘版本的 manifest；版本不存在或 manifest 坏了返回 `null`。
  PluginManifest? installed(String pluginId, String version) {
    final file = File('${_versionDir(pluginId, version)}${_sep}manifest.json');
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return PluginManifest.fromJson(json);
    } on Object {
      return null;
    }
  }

  /// 当前发布版本的 manifest；没发布过返回 `null`。
  PluginManifest? activeVersionOf(String pluginId) {
    final published = _published[pluginId];
    if (published == null) return null;
    return installed(pluginId, published.version);
  }

  /// 磁盘上已有的版本号，从低到高。
  List<String> availableVersionsOf(String pluginId) =>
      _sorted(_versionDirs(pluginId));

  /// 指针是否已经指向 [version]。
  ///
  /// 用来区分「升级失败」与「本来就没事」：[upgrade] 两者都返回 `null`，
  /// 但前者需要提示用户，后者只需静默跳过（回滚后重放同一个升级包就走这里）。
  bool alreadyCurrent(String pluginId, String version) =>
      _published[pluginId]?.version == version;

  /// 把一个版本的产物写进版本库。
  ///
  /// 先复制到同目录下的 `.staging_<ver>`，再换名进来 —— 同卷 rename 是原子的，
  /// 所以任何时刻磁盘上要么是完整的旧版本、要么是完整的新版本。目标版本已存在
  /// 时先把旧目录移成 `.backup_<ver>`，换名失败就放回去，绝不出现「版本凭空
  /// 消失」。
  Future<void> writeVersion(DownloadedPlugin plugin) async {
    final pluginId = plugin.manifest.id;
    final version = plugin.manifest.version;
    final versionsDir = Directory(_versionsDir(pluginId));
    versionsDir.createSync(recursive: true);

    final staging = Directory('${versionsDir.path}$_sep.staging_$version');
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync(recursive: true);
    await _copyDir(Directory(plugin.versionDir), staging);

    final target = Directory(_versionDir(pluginId, version));
    if (!target.existsSync()) {
      staging.renameSync(target.path);
      return;
    }

    final backup = Directory('${versionsDir.path}$_sep.backup_$version');
    if (backup.existsSync()) backup.deleteSync(recursive: true);
    target.renameSync(backup.path);
    try {
      staging.renameSync(target.path);
    } on Object {
      backup.renameSync(target.path);
      rethrow;
    }
    backup.deleteSync(recursive: true);
  }

  /// 升级到 [manifest] 的版本。
  ///
  /// 顺序是刻意的：**新版本先在旧版本仍运行时激活**，激活成功了才动指针。
  /// 于是激活失败时旧版本**原样继续服务** —— 指针、旧版本目录一个字节都没动，
  /// 用户不会因为一次失败的升级而失去能用的版本。
  ///
  /// 返回新版本的 manifest 表示升级成功；返回 `null` 表示没升级（原因可能是
  /// 已经是指针指向的版本、目标版本不在磁盘上、激活失败，或发布通知失败）。
  ///
  /// 不设「拒绝降级」闸门：降级在语义上就是「升级到一个更低的版本号」，
  /// 拦它只会让用户没法用升级通道修一个坏版本。
  ///
  /// **发布通知失败时保留新指针**，不回写旧版本。理由：磁盘上新版本才是真的，
  /// 把指针写回旧版本会让它指向一个可能已经被清理掉的目录，制造出比「没通知
  /// 成功」严重得多的问题。返回 `null` 是告诉调用方「需要你自己重试通知」。
  Future<PluginManifest?> upgrade(
    PluginManifest manifest,
    PluginApi api,
  ) async {
    final pluginId = manifest.id;
    final version = manifest.version;

    if (alreadyCurrent(pluginId, version)) return null;

    final target = installed(pluginId, version);
    if (target == null) return null;

    try {
      await api.onActivate();
    } on Object {
      return null;
    }

    final old = _published[pluginId]?.version;
    try {
      _writePointer(pluginId, version);
    } on Object {
      return null;
    }
    _published[pluginId] = _Published(
      version: version,
      previousVersion: old,
    );

    try {
      await _publishPointer?.call(pluginId, version);
    } on Object {
      return null;
    }

    return target;
  }

  /// 回滚到上一个版本。
  ///
  /// 只回到 [previousVersionOf] 记录的那个版本 —— 回滚一步，不是一路退回去。
  /// 旧版本目录已经被清理时返回 `null`：回不去就如实说回不去，而不是假装
  /// 成功再让调用方去加载一个不存在的目录。
  ///
  /// 与 [upgrade] 一样先激活再切指针，激活失败时当前版本继续服务。
  Future<PluginManifest?> rollback(
    PluginManifest manifest,
    PluginApi api,
  ) async {
    final pluginId = manifest.id;
    final published = _published[pluginId];
    final target = published?.previousVersion;
    if (target == null) return null;

    final old = installed(pluginId, target);
    if (old == null) return null;

    try {
      await api.onActivate();
    } on Object {
      return null;
    }

    try {
      _writePointer(pluginId, target);
    } on Object {
      return null;
    }
    // 回滚后「上一个版本」变成刚被换下来的那个，语义上与 upgrade 对称。
    _published[pluginId] = _Published(
      version: target,
      previousVersion: published!.version,
    );

    try {
      await _publishPointer?.call(pluginId, target);
    } on Object {
      return null;
    }

    return old;
  }

  /// 清掉既不是当前版本、也不是可回滚版本的版本目录。
  ///
  /// 从未发布过任何版本时**直接跳过**：那时「哪个是垃圾」无从判断，动手只会把
  /// 用户刚下载好的版本一起删掉。
  void pruneBrokenVersions(PluginManifest manifest) {
    final pluginId = manifest.id;
    final published = _published[pluginId];
    if (published == null) return;

    final keep = <String>{
      published.version,
      if (published.previousVersion != null) published.previousVersion!,
    };
    for (final version in _versionDirs(pluginId)) {
      if (keep.contains(version)) continue;
      _deleteQuietly(Directory(_versionDir(pluginId, version)));
    }
  }

  /// 删掉一个插件的整个版本库（含指针）。
  ///
  /// **幂等**：目录已经不在、或还有文件被占着，都只是静默略过。它跑在
  /// `uninstall` 里，而每个测试的 `tearDown` 也会走这条路 —— 一条删除失败就
  /// 会让整个测试套件变红，而失败原因（文件被占）与被测行为无关。
  void remove(String pluginId) {
    _published.remove(pluginId);
    _deleteQuietly(Directory(_pluginDir(pluginId)));
  }

  // ---- 路径 ----

  String _pluginDir(String pluginId) => '$pluginsDirectory$_sep$pluginId';

  String _versionsDir(String pluginId) =>
      '${_pluginDir(pluginId)}${_sep}versions';

  String _versionDir(String pluginId, String version) =>
      '${_versionsDir(pluginId)}$_sep$version';

  String _pointerPath(String pluginId) =>
      '${_pluginDir(pluginId)}${_sep}files${_sep}current';

  // ---- 指针 ----

  String? _readPointer(String pluginId) {
    final file = File(_pointerPath(pluginId));
    if (!file.existsSync()) return null;
    try {
      final text = file.readAsStringSync().trim();
      return text.isEmpty ? null : text;
    } on Object {
      return null;
    }
  }

  /// 原子地写指针：先写 `current.tmp`，再 rename 覆盖 `current`。
  void _writePointer(String pluginId, String version) {
    final filesDir = Directory(
      '${_pluginDir(pluginId)}${_sep}files',
    );
    filesDir.createSync(recursive: true);
    final tmp = File('${filesDir.path}${_sep}current.tmp');
    tmp.writeAsStringSync(version, flush: true);
    tmp.renameSync(_pointerPath(pluginId));
  }

  // ---- 版本目录 ----

  /// 版本库里的版本目录名。`.staging_*` / `.backup_*` 这类残留不算版本。
  List<String> _versionDirs(String pluginId) {
    final dir = Directory(_versionsDir(pluginId));
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<Directory>()
        .map((d) => _basename(d.path))
        .where((name) => !name.startsWith('.'))
        .toList();
  }

  /// 低于 [version] 的最高版本，没有则 `null`。
  String? _highestBelow(String pluginId, String version) {
    final below = _versionDirs(
      pluginId,
    ).where((v) => _compareVersions(v, version) < 0).toList();
    if (below.isEmpty) return null;
    return _sorted(below).last;
  }

  void _cleanupResidue(String pluginId) {
    final dir = Directory(_versionsDir(pluginId));
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final name = _basename(entity.path);
      if (name.startsWith('.staging_') || name.startsWith('.backup_')) {
        _deleteQuietly(entity);
      }
    }
  }

  // ---- 工具 ----

  List<String> _sorted(List<String> versions) {
    final copy = List<String>.of(versions);
    copy.sort(_compareVersions);
    return copy;
  }

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final index = normalized.lastIndexOf('/');
    return index < 0 ? normalized : normalized.substring(index + 1);
  }

  static void _deleteQuietly(FileSystemEntity entity) {
    try {
      if (entity.existsSync()) entity.deleteSync(recursive: true);
    } on FileSystemException {
      // 幂等：目录可能已被删，或仍有文件被占着。清理失败不该让调用方失败。
    }
  }

  static Future<void> _copyDir(Directory from, Directory to) async {
    if (!from.existsSync()) return;
    await for (final entity in from.list(recursive: true, followLinks: false)) {
      final relative = entity.path.substring(from.path.length);
      final targetPath = '${to.path}$relative';
      if (entity is Directory) {
        Directory(targetPath).createSync(recursive: true);
      } else if (entity is File) {
        final target = File(targetPath);
        target.parent.createSync(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }
}

/// 比较两个 `x.y.z` 形式的版本号。
///
/// 只按数字段比，段数不足的补 0；数字段完全相同再按字符串兜底（预发布标识、
/// 构建号这类非数字尾巴）。不引第三方 semver 包：这里只需要「排序 + 比大小」，
/// 完整的 semver 规则（预发布版本低于正式版等）用不上，引进来反而多一层
/// 需要验证的行为。
int _compareVersions(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  final length = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < length; i++) {
    final na = i < pa.length ? int.tryParse(pa[i]) ?? 0 : 0;
    final nb = i < pb.length ? int.tryParse(pb[i]) ?? 0 : 0;
    if (na != nb) return na.compareTo(nb);
  }
  return a.compareTo(b);
}
