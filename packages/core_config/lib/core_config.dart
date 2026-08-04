/// TVBox 配置的抓取、解码、解析、映射与校验。
///
/// **本包在 M3 落地**，当前只占位。
///
/// 计划中的公共 API（见 `docs/02-系统架构.md` §3.3 与
/// `docs/05-Spider引擎.md` §5）：
///
/// - `ConfigFetcher`：按 URL 或本地文件取回原始字节
/// - `ConfigDecoder`：依次尝试 明文 JSON → Base64 → AES 加密体
/// - `TvBoxConfigParser`：宽松 JSON 解析（容忍注释与尾逗号）
/// - `ConfigMapper`：中间模型 → `SourceSite` / `LiveGroup` / `ParseRule`
/// - `ConfigValidator`：必填字段、type 合法性、URL 协议白名单
///
/// 解码链是自研清单里的第 3 项（`docs/03-技术选型.md` §3）：各家 TVBox 分支
/// 的加密实现互不一致，只能逐个对齐。
library;
