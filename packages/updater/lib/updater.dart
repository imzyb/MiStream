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
///   - [UpdateInstaller]   解压 → 写计划 → 退出后替换 → 下次启动回滚
///
/// 最后一层之所以存在：Windows 上正在运行的 exe 不能被覆盖，替换必须发生在
/// 应用退出之后（由生成的 PowerShell 脚本做），而**回滚**放在 Dart 侧、下次
/// 启动时做 —— 脚本里的回滚分支在本机没法测，Dart 里的能。
library;

export 'src/update_checker.dart';
export 'src/update_downloader.dart';
export 'src/update_fetcher.dart';
export 'src/update_installer.dart';
export 'src/update_manifest.dart';
export 'src/update_service.dart';
export 'src/update_version.dart';
