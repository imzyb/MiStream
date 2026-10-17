/// 自动更新链的纯逻辑层。
///
/// 分工（每一层都能单独测，都不碰 UI）：
///
///   - [AppVersion]        版本号比较（忽略构建号，正式版 > 预发布）
///   - [UpdateManifest]    `latest.json` 解析（单渠道 / 多渠道路由）
///   - [UpdateChecker]     「要不要更新」的决策（纯函数）
///   - [UpdateFetcher]     取网络（可注入，测试不连网）
///   - [UpdateDownloader]  下载 + size/sha256 校验 + `.part` 原子落盘
///   - [UpdateService]     串起来，唯一知道 feed 地址的地方
///
/// **不包含**「替换正在运行的程序」。那件事必须在应用退出之后做，且要能
/// 回滚，单独一层实现 —— 混进来会让这里的每个用例都要造一个假的可执行文件。
library;

export 'src/update_checker.dart';
export 'src/update_downloader.dart';
export 'src/update_fetcher.dart';
export 'src/update_manifest.dart';
export 'src/update_service.dart';
export 'src/update_version.dart';
