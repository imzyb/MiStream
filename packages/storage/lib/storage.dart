/// 本地存储：drift 数据库、迁移、DAO、备份。
///
/// **本包在 M2 落地**，当前只占位。
///
/// 计划中的公共 API（见 `docs/07-数据库设计.md`）：
///
/// - drift schema 与全部表、外键、索引
/// - DAO 层与 Domain 侧 Repository 接口的实现
/// - 迁移框架 + schema 快照 + 迁移测试工具链
/// - 迁移前自动备份与失败回滚（失败时**拒绝启动**，不带半迁移的库跑）
/// - 设置 KV 与类型安全的 `SettingKey<T>` 常量表
/// - 缓存表的过期清理与 LRU 淘汰
/// - 备份导出 / 导入（`.mistream-backup`）
///
/// `schemaVersion` 独立于 `appVersion` 演进，兼容规则见
/// `docs/compatibility.md` §4。
library;
