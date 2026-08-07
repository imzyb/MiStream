/// drpy 宿主 API：local.* 存储函数。
///
/// 对齐 `docs/05-Spider引擎.md` §2.2 的存储 API：
/// `local.get(key)` / `local.set(key, value)` / `local.delete(key)`。
/// 按源隔离命名空间，走 `plugin_storage` 表（`docs/07 §3.7`）。
library;

import 'package:storage/src/dao/plugin_storage_dao.dart';

/// 按源隔离的本地存储。
class LocalStorage {
  final PluginStorageDao _dao;
  final String _owner;

  /// 构造本地存储。
  LocalStorage(this._dao, this._owner);

  /// 读取一项存储。
  Future<String?> get(String key) => _dao.get(_owner, key);

  /// 写入一项存储（覆盖），返回占用的字节数。
  Future<int> set(String key, String value) => _dao.set(_owner, key, value);

  /// 删除一项存储。
  Future<void> delete(String key) => _dao.delete(_owner, key);

  /// 查询当前 owner 的存储总字节数。
  Future<int> totalBytes() => _dao.totalBytes(_owner);
}
