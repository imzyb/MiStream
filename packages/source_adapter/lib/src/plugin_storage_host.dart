/// `host.storage.*` 的落库实现。
///
/// 按 ADR-001 与 `docs/08-RPC协议.md` §4，运行时子进程**不直接碰数据库**——
/// 脚本里的 `local.get/set/delete` 是一条发回宿主的 RPC，由这里落到
/// `plugin_storage` 表（`docs/07 §3.7`）。
///
/// 这个类原先叫 `LocalStorage`、住在 `runtimes/spider_js` 里直接吃
/// `PluginStorageDao`，那是把宿主的活干在了运行时侧：既违反上面那条分层，
/// 也让运行时包背上了 `storage` 依赖（进而拖进 sqlite3 的 build hook，
/// 子进程测试起 `dart run` 时会和已加载的 sqlite3.dll 抢文件）。
library;

import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';

/// 按源隔离的存储，供 `HostApi` 处理 `host.storage.*` 用。
///
/// owner 由宿主按 `site:<id>` 之类的形态给出，脚本无从伪造——命名空间隔离
/// 是在这一侧保证的，不能交给子进程自报。
class PluginStorageHost {
  /// 以 `dao` 构造。
  const PluginStorageHost(this._dao);

  final PluginStorageDao _dao;

  /// 读取一项存储。
  Future<String?> get(String owner, String key) => _dao.get(owner, key);

  /// 写入一项存储（覆盖），返回占用的字节数。
  Future<int> set(String owner, String key, String value) =>
      _dao.set(owner, key, value);

  /// 删除一项存储。
  Future<void> delete(String owner, String key) => _dao.delete(owner, key);

  /// 查询某个 owner 的存储总字节数，配额检查用。
  Future<int> totalBytes(String owner) => _dao.totalBytes(owner);

  /// 装配成 [HostApi] 要的回调三件套。
  HostStorage asHostStorage() =>
      HostStorage(get: get, set: set, delete: delete);
}
