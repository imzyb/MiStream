/// 错误码定义。
///
/// 分两个区间，靠符号就能判断来源：
///
/// - **负数**：来自子进程或 RPC 层，取值与 `docs/08-RPC协议.md` §7 完全一致，
///   可直接当作 JSON-RPC `error.code` 收发。
/// - **正数**：宿主进程本地产生，永不出现在 RPC 报文里，见 §7.6。
///
/// 两边合用一张表，是为了让 [ErrorCode] 有唯一的取值空间——上层拿到一个码就
/// 能决定文案与重试策略，不必先问「这码是谁给的」。
library;

import 'package:meta/meta.dart';

/// 错误码所属区段。
///
/// 未知错误码按区段降级处理，这是 `docs/compatibility.md` §2 要求的向前兼容
/// 策略：对端新增错误码不升 `protocolVersion`，接收方必须能按段处理没见过的
/// 码，而不是直接崩掉或吞掉。
enum ErrorBand {
  /// JSON-RPC 2.0 标准保留码（`-32768` ~ `-32600`）。
  jsonRpc,

  /// 运行时层（`-32099` ~ `-32000`）。
  runtime,

  /// Spider 层（`-32199` ~ `-32100`）。
  spider,

  /// 权限与网络层（`-32299` ~ `-32200`）。
  permissionNetwork,

  /// 嗅探层（`-32399` ~ `-32300`）。
  sniffer,

  /// 本地：TVBox 配置抓取与解析（`1000` ~ `1099`）。
  config,

  /// 本地：数据库与备份（`1100` ~ `1199`）。
  storage,

  /// 本地：播放器（`1200` ~ `1299`）。
  player,

  /// 本地：插件系统（`1300` ~ `1399`）。
  plugin,

  /// 本地：自动更新（`1400` ~ `1499`）。
  update,

  /// 本地：通用（`1900` ~ `1999`）。
  general,

  /// 不属于任何已知区段。
  unknown;

  /// 判断 [value] 落在哪个区段。
  static ErrorBand of(int value) {
    if (value >= -32768 && value <= -32600) return ErrorBand.jsonRpc;
    if (value >= -32099 && value <= -32000) return ErrorBand.runtime;
    if (value >= -32199 && value <= -32100) return ErrorBand.spider;
    if (value >= -32299 && value <= -32200) return ErrorBand.permissionNetwork;
    if (value >= -32399 && value <= -32300) return ErrorBand.sniffer;
    if (value >= 1000 && value <= 1099) return ErrorBand.config;
    if (value >= 1100 && value <= 1199) return ErrorBand.storage;
    if (value >= 1200 && value <= 1299) return ErrorBand.player;
    if (value >= 1300 && value <= 1399) return ErrorBand.plugin;
    if (value >= 1400 && value <= 1499) return ErrorBand.update;
    if (value >= 1900 && value <= 1999) return ErrorBand.general;
    return ErrorBand.unknown;
  }
}

/// 一个错误码：数值 + 稳定的常量名 + 默认重试策略。
///
/// 常量名（如 `RUNTIME_BUSY`）是对外承诺的一部分：日志、诊断面板、issue 里
/// 贴出来的都是它。数值可以在文档里查，名字才是人读的。
@immutable
final class ErrorCode {
  /// 构造一个错误码。
  ///
  /// 业务代码不该直接调用——已知码用本类的静态常量，从 RPC 报文里读到的码用
  /// [ErrorCode.resolve]。这个构造函数公开只是为了让测试能造出任意码。
  const ErrorCode(this.value, this.name, {this.retryable = false});

  /// 按数值取错误码，未知的合成一个按区段命名的占位码。
  ///
  /// 这是解码 RPC 报文时的入口：对端可能比我们新，带来没见过的码。此时既不能
  /// 崩，也不能悄悄当成成功——合成一个保留原始数值的码，让它照常走错误路径。
  ///
  /// 合成码的 [retryable] 一律为 `false`：不认识的失败反复重试，只会把一次
  /// 报错放大成一串。真要重试，得等对端在 `data.retryable` 里明说。
  factory ErrorCode.resolve(int value) =>
      _byValue[value] ??
      ErrorCode(value, 'UNKNOWN_${ErrorBand.of(value).name.toUpperCase()}');

  /// 数值。负数来自 RPC 与子进程，正数是宿主本地。
  final int value;

  /// 稳定的常量名，如 `RUNTIME_BUSY`。
  final String name;

  /// 默认是否值得重试。
  ///
  /// 只是默认值。`docs/08-RPC协议.md` §7 允许对端在 `data.retryable` 里覆盖
  /// 它，因此最终判据是 `AppError.retryable` 而不是这里。
  final bool retryable;

  /// 所属区段。
  ErrorBand get band => ErrorBand.of(value);

  /// 是否来自子进程或 RPC 层。
  bool get isRemote => value < 0;

  /// 是否由宿主进程本地产生。
  bool get isLocal => value > 0;

  // ---------------------------------------------------------------------
  // JSON-RPC 2.0 标准（docs/08 §7.1）
  // ---------------------------------------------------------------------

  /// 报文不是合法 JSON。
  static const parseError = ErrorCode(-32700, 'PARSE_ERROR');

  /// 报文是合法 JSON 但不是合法 JSON-RPC 请求。
  static const invalidRequest = ErrorCode(-32600, 'INVALID_REQUEST');

  /// 方法不存在。
  static const methodNotFound = ErrorCode(-32601, 'METHOD_NOT_FOUND');

  /// 参数非法。
  static const invalidParams = ErrorCode(-32602, 'INVALID_PARAMS');

  /// 对端内部错误。
  static const internalError = ErrorCode(-32603, 'INTERNAL_ERROR');

  // ---------------------------------------------------------------------
  // 运行时层（docs/08 §7.2）
  // ---------------------------------------------------------------------

  /// 握手尚未完成。
  static const runtimeNotReady = ErrorCode(
    -32000,
    'RUNTIME_NOT_READY',
    retryable: true,
  );

  /// 运行时请求队列已满，需要退避重试。
  static const runtimeBusy = ErrorCode(-32001, 'RUNTIME_BUSY', retryable: true);

  /// 子进程已退出，重启后可重试。
  static const runtimeCrashed = ErrorCode(
    -32002,
    'RUNTIME_CRASHED',
    retryable: true,
  );

  /// `instanceId` 无效，需要重新 `spider.create`。
  static const instanceNotFound = ErrorCode(-32003, 'INSTANCE_NOT_FOUND');

  /// 协议版本不兼容。按 `docs/compatibility.md` §2，此时直接失败，不降级。
  static const protocolVersionMismatch = ErrorCode(
    -32004,
    'PROTOCOL_VERSION_MISMATCH',
  );

  /// 单条消息超过 32MB 上限。
  static const messageTooLarge = ErrorCode(-32005, 'MESSAGE_TOO_LARGE');

  // ---------------------------------------------------------------------
  // Spider 层（docs/08 §7.3）
  // ---------------------------------------------------------------------

  /// 脚本加载失败或有语法错误。
  static const scriptLoadFailed = ErrorCode(-32100, 'SCRIPT_LOAD_FAILED');

  /// 脚本执行抛异常，`detail['stack']` 带堆栈。
  static const scriptRuntimeError = ErrorCode(-32101, 'SCRIPT_RUNTIME_ERROR');

  /// 脚本执行超时，被 interrupt 中断。
  static const scriptTimeout = ErrorCode(
    -32102,
    'SCRIPT_TIMEOUT',
    retryable: true,
  );

  /// 脚本内存超限。
  static const memoryLimitExceeded = ErrorCode(-32103, 'MEMORY_LIMIT_EXCEEDED');

  /// 该源未实现此方法（例如不支持搜索）。
  static const methodNotImplemented = ErrorCode(
    -32104,
    'METHOD_NOT_IMPLEMENTED',
  );

  /// 返回值不符合 schema，`detail['errors']` 列出字段。
  static const invalidResultSchema = ErrorCode(-32105, 'INVALID_RESULT_SCHEMA');

  /// Spider 返回的结果解析失败。
  static const spiderParseFailed = ErrorCode(-32108, 'SPIDER_PARSE_FAILED');

  /// 正常执行但无数据。不是错误，供 UI 区分「空」与「失败」。
  static const emptyResult = ErrorCode(-32106, 'EMPTY_RESULT');

  /// 请求被 `$/cancelRequest` 取消。
  static const requestCancelled = ErrorCode(-32107, 'REQUEST_CANCELLED');

  // ---------------------------------------------------------------------
  // 权限与网络层（docs/08 §7.4）
  // ---------------------------------------------------------------------

  /// 未授予该权限。
  static const permissionDenied = ErrorCode(-32200, 'PERMISSION_DENIED');

  /// 域名不在白名单，`detail['host']` 给出被拒的域名。
  static const hostNotAllowed = ErrorCode(-32201, 'HOST_NOT_ALLOWED');

  /// 私网、回环或链路本地地址被拦截（含重定向后的地址）。
  static const privateAddressBlocked = ErrorCode(
    -32202,
    'PRIVATE_ADDRESS_BLOCKED',
  );

  /// 非 http/https 协议。
  static const protocolNotAllowed = ErrorCode(-32203, 'PROTOCOL_NOT_ALLOWED');

  /// 存储配额超限。
  static const quotaExceeded = ErrorCode(-32204, 'QUOTA_EXCEEDED');

  /// 请求频率超限。
  static const rateLimited = ErrorCode(-32205, 'RATE_LIMITED', retryable: true);

  /// 网络超时。
  static const networkTimeout = ErrorCode(
    -32210,
    'NETWORK_TIMEOUT',
    retryable: true,
  );

  /// DNS 解析失败。
  static const networkDnsFailed = ErrorCode(
    -32211,
    'NETWORK_DNS_FAILED',
    retryable: true,
  );

  /// TLS 证书错误。证书问题重试无意义，且重试会掩盖中间人攻击。
  static const networkTlsError = ErrorCode(-32212, 'NETWORK_TLS_ERROR');

  /// 非 2xx 响应，`detail['status']` 给出状态码。
  ///
  /// 默认不可重试：4xx 重试无意义。5xx 的可重试性由网络层按实际状态码写进
  /// `data.retryable` 覆盖。
  static const httpError = ErrorCode(-32213, 'HTTP_ERROR');

  /// 响应体超过大小上限。
  static const responseTooLarge = ErrorCode(-32214, 'RESPONSE_TOO_LARGE');

  // ---------------------------------------------------------------------
  // 嗅探层（docs/08 §7.5）
  // ---------------------------------------------------------------------

  /// 嗅探组件缺失（例如 Linux 未安装 CEF）。
  static const snifferUnavailable = ErrorCode(-32300, 'SNIFFER_UNAVAILABLE');

  /// 嗅探超时未命中。
  static const sniffTimeout = ErrorCode(
    -32301,
    'SNIFF_TIMEOUT',
    retryable: true,
  );

  /// 页面加载完成但没有媒体流。
  static const sniffNoMatch = ErrorCode(-32302, 'SNIFF_NO_MATCH');

  /// 页面加载失败。
  static const sniffPageError = ErrorCode(
    -32303,
    'SNIFF_PAGE_ERROR',
    retryable: true,
  );

  // ---------------------------------------------------------------------
  // 本地：配置（docs/08 §7.6）
  // ---------------------------------------------------------------------

  /// 配置地址拉取失败。
  static const configFetchFailed = ErrorCode(
    1000,
    'CONFIG_FETCH_FAILED',
    retryable: true,
  );

  /// 明文、Base64、AES 三条解码路径全部失败。
  static const configDecodeFailed = ErrorCode(1001, 'CONFIG_DECODE_FAILED');

  /// 解码成功但 JSON 结构非法。
  static const configParseFailed = ErrorCode(1002, 'CONFIG_PARSE_FAILED');

  /// 结构合法但字段校验不过（必填缺失、type 非法、协议不在白名单）。
  static const configSchemaInvalid = ErrorCode(1003, 'CONFIG_SCHEMA_INVALID');

  /// 配置声明了本版本不支持的格式版本。
  static const configUnsupportedVersion = ErrorCode(
    1004,
    'CONFIG_UNSUPPORTED_VERSION',
  );

  /// 解析成功但没有任何可用站点。
  static const configEmpty = ErrorCode(1005, 'CONFIG_EMPTY');

  // ---------------------------------------------------------------------
  // 本地：存储
  // ---------------------------------------------------------------------

  /// 数据库打开失败。
  static const dbOpenFailed = ErrorCode(1100, 'DB_OPEN_FAILED');

  /// 迁移失败。按 `docs/compatibility.md` §4，此时必须回滚并拒绝启动。
  static const dbMigrationFailed = ErrorCode(1101, 'DB_MIGRATION_FAILED');

  /// 迁移前的自动备份失败，迁移不得继续。
  static const dbBackupFailed = ErrorCode(1102, 'DB_BACKUP_FAILED');

  /// 库的 `schemaVersion` 高于本版本支持——用户从新版回退了。
  static const dbSchemaTooNew = ErrorCode(1103, 'DB_SCHEMA_TOO_NEW');

  /// 查询或写入失败。
  static const dbQueryFailed = ErrorCode(1104, 'DB_QUERY_FAILED');

  /// 备份导出失败。
  static const backupExportFailed = ErrorCode(1105, 'BACKUP_EXPORT_FAILED');

  /// 备份导入失败。
  static const backupImportFailed = ErrorCode(1106, 'BACKUP_IMPORT_FAILED');

  /// 备份文件版本高于本版本支持。
  static const backupVersionUnsupported = ErrorCode(
    1107,
    'BACKUP_VERSION_UNSUPPORTED',
  );

  // ---------------------------------------------------------------------
  // 本地：播放
  // ---------------------------------------------------------------------

  /// 播放引擎初始化失败。
  static const playerInitFailed = ErrorCode(1200, 'PLAYER_INIT_FAILED');

  /// 找不到 libmpv，或版本 / hash 校验不通过。
  static const playerLibmpvMissing = ErrorCode(1201, 'PLAYER_LIBMPV_MISSING');

  /// 打开媒体失败。
  static const playerOpenFailed = ErrorCode(
    1202,
    'PLAYER_OPEN_FAILED',
    retryable: true,
  );

  /// 容器或编码不受支持。
  static const playerUnsupportedFormat = ErrorCode(
    1203,
    'PLAYER_UNSUPPORTED_FORMAT',
  );

  /// 硬解不可用，已降级软解。不是失败，是需要告知用户的降级事件。
  static const playerHwdecFallback = ErrorCode(1204, 'PLAYER_HWDEC_FALLBACK');

  /// 外挂字幕加载失败。
  static const playerSubtitleLoadFailed = ErrorCode(
    1205,
    'PLAYER_SUBTITLE_LOAD_FAILED',
  );

  /// 解析器、嗅探、换线路的回退链全部走完，仍无可播地址。
  static const playerNoPlayableSource = ErrorCode(
    1206,
    'PLAYER_NO_PLAYABLE_SOURCE',
  );

  // ---------------------------------------------------------------------
  // 本地：插件
  // ---------------------------------------------------------------------

  /// manifest 缺字段、字段非法或版本不受支持。
  static const pluginManifestInvalid = ErrorCode(
    1300,
    'PLUGIN_MANIFEST_INVALID',
  );

  /// sha256 完整性校验不通过。
  static const pluginIntegrityFailed = ErrorCode(
    1301,
    'PLUGIN_INTEGRITY_FAILED',
  );

  /// 签名验证不通过。
  static const pluginSignatureInvalid = ErrorCode(
    1302,
    'PLUGIN_SIGNATURE_INVALID',
  );

  /// 插件与当前应用版本不兼容。
  static const pluginIncompatible = ErrorCode(1303, 'PLUGIN_INCOMPATIBLE');

  /// 安装失败。
  static const pluginInstallFailed = ErrorCode(1304, 'PLUGIN_INSTALL_FAILED');

  /// 回滚失败——这是最严重的一类，说明版本目录已经不一致。
  static const pluginRollbackFailed = ErrorCode(1305, 'PLUGIN_ROLLBACK_FAILED');

  /// 插件所需权限已被用户撤销。
  static const pluginPermissionRevoked = ErrorCode(
    1306,
    'PLUGIN_PERMISSION_REVOKED',
  );

  // ---------------------------------------------------------------------
  // 本地：更新
  // ---------------------------------------------------------------------

  /// 检查更新失败。
  static const updateCheckFailed = ErrorCode(
    1400,
    'UPDATE_CHECK_FAILED',
    retryable: true,
  );

  /// 下载更新包失败。
  static const updateDownloadFailed = ErrorCode(
    1401,
    'UPDATE_DOWNLOAD_FAILED',
    retryable: true,
  );

  /// SHA256 与 feed 中声明的不一致。
  static const updateChecksumMismatch = ErrorCode(
    1402,
    'UPDATE_CHECKSUM_MISMATCH',
  );

  /// 更新包签名验证不通过。
  static const updateSignatureInvalid = ErrorCode(
    1403,
    'UPDATE_SIGNATURE_INVALID',
  );

  /// 原子替换失败。
  static const updateApplyFailed = ErrorCode(1404, 'UPDATE_APPLY_FAILED');

  /// 更新失败后的回滚也失败了。
  static const updateRollbackFailed = ErrorCode(1405, 'UPDATE_ROLLBACK_FAILED');

  // ---------------------------------------------------------------------
  // 本地：通用
  // ---------------------------------------------------------------------

  /// 兜底：没有更具体的码可用。出现在日志里就说明该补一个专用码了。
  static const unknown = ErrorCode(1900, 'UNKNOWN');

  /// 非法状态：调用顺序不对，或对象已被释放。
  static const invalidState = ErrorCode(1901, 'INVALID_STATE');

  /// 参数非法。
  static const invalidArgument = ErrorCode(1902, 'INVALID_ARGUMENT');

  /// 目标不存在。
  static const notFound = ErrorCode(1903, 'NOT_FOUND');

  /// 操作被主动取消。
  static const cancelled = ErrorCode(1904, 'CANCELLED');

  /// 本地操作超时。
  static const timeout = ErrorCode(1905, 'TIMEOUT', retryable: true);

  /// 当前平台不支持该能力。
  static const unsupportedPlatform = ErrorCode(1906, 'UNSUPPORTED_PLATFORM');

  /// 文件系统读写失败。
  static const ioFailed = ErrorCode(1907, 'IO_FAILED');

  /// 本地文件或目录权限不足。
  static const localPermissionDenied = ErrorCode(
    1908,
    'LOCAL_PERMISSION_DENIED',
  );

  /// 全部已知错误码。
  ///
  /// 顺序与 `docs/08-RPC协议.md` §7 的表格一致，改动时两边要一起改。
  static const List<ErrorCode> known = [
    parseError,
    invalidRequest,
    methodNotFound,
    invalidParams,
    internalError,
    runtimeNotReady,
    runtimeBusy,
    runtimeCrashed,
    instanceNotFound,
    protocolVersionMismatch,
    messageTooLarge,
    scriptLoadFailed,
    scriptRuntimeError,
    scriptTimeout,
    memoryLimitExceeded,
    methodNotImplemented,
    invalidResultSchema,
    spiderParseFailed,
    emptyResult,
    requestCancelled,
    permissionDenied,
    hostNotAllowed,
    privateAddressBlocked,
    protocolNotAllowed,
    quotaExceeded,
    rateLimited,
    networkTimeout,
    networkDnsFailed,
    networkTlsError,
    httpError,
    responseTooLarge,
    snifferUnavailable,
    sniffTimeout,
    sniffNoMatch,
    sniffPageError,
    configFetchFailed,
    configDecodeFailed,
    configParseFailed,
    configSchemaInvalid,
    configUnsupportedVersion,
    configEmpty,
    dbOpenFailed,
    dbMigrationFailed,
    dbBackupFailed,
    dbSchemaTooNew,
    dbQueryFailed,
    backupExportFailed,
    backupImportFailed,
    backupVersionUnsupported,
    playerInitFailed,
    playerLibmpvMissing,
    playerOpenFailed,
    playerUnsupportedFormat,
    playerHwdecFallback,
    playerSubtitleLoadFailed,
    playerNoPlayableSource,
    pluginManifestInvalid,
    pluginIntegrityFailed,
    pluginSignatureInvalid,
    pluginIncompatible,
    pluginInstallFailed,
    pluginRollbackFailed,
    pluginPermissionRevoked,
    updateCheckFailed,
    updateDownloadFailed,
    updateChecksumMismatch,
    updateSignatureInvalid,
    updateApplyFailed,
    updateRollbackFailed,
    unknown,
    invalidState,
    invalidArgument,
    notFound,
    cancelled,
    timeout,
    unsupportedPlatform,
    ioFailed,
    localPermissionDenied,
  ];

  static final Map<int, ErrorCode> _byValue = {
    for (final code in known) code.value: code,
  };

  /// 按数值查已知错误码，没有就返回 `null`。
  ///
  /// 需要「查不到就合成占位码」的那套语义，用 [ErrorCode.resolve]。
  static ErrorCode? lookup(int value) => _byValue[value];

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ErrorCode && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$name($value)';
}
