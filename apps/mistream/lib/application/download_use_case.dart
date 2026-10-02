/// 把「某一集」加入下载的编排。
///
/// 下载功能此前只有**一个入口**：下载页手动粘贴 URL。这意味着 `download` 表的
/// `site_id` / `vod_id` / `episode_name` 三列没有任何写入方，下载列表也就无从
/// 显示「这是哪部片的第几集」—— 从影片页发起下载正是那三列的唯一写入方。
///
/// ## 为什么要有这一层，而不是让详情页自己拼
///
/// 三件事必须按固定顺序发生，且都有各自的失败模式：
///
/// 1. **解析真实地址**。详情页拿到的 `vod_play_url` 可能是**网页播放页**而不是
///    媒体流（名字形如 `share/xxx` 的线路全是这样），必须经 `PlayUseCase`
///    解析，否则下回来的是一个 HTML 文件。
/// 2. **带上反盗链头**。`MediaSource.headers` 里的 `Referer` / `User-Agent`
///    是源站判断盗链的依据，丢了它们下载器会一路 403 —— 而播放器有 mpv 帮忙
///    设置，下载器没有，只能靠这里透传。
/// 3. **按「影片 / 集」分目录**。保存路径不能只用影片名：同一部剧的每一集
///    都会往同一个目录写 `segment_000000.ts`，互相覆盖。
///
/// 把这三件事放在 UI 里做，等于让每个调用点各自记得一遍；收在这里，UI 只传
/// 「哪部片的哪一集」。
library;

import 'package:core_domain/core_domain.dart';
import 'package:download/download.dart';
import 'package:player_engine/player_engine.dart';

/// 「线路 + 集」→ 真实可下载的媒体源。
///
/// 收成函数类型而不是直接依赖 `PlayUseCase`：这个用例真正需要的只是「给我一个
/// 能下载的地址和它的请求头」，而 `PlayUseCase` 背后是 Spider 运行时、静态与
/// CDP 两级嗅探器一整套 —— 依赖它意味着「测去重和请求头透传」也得把那一整套
/// 起起来，于是这些分支最终不会有人测。装配层负责把两者接起来。
typedef PlayableSourceResolver =
    Future<Result<MediaSource, AppError>> Function({
      required int siteId,
      required String vodId,
      required String flag,
      String? episodeId,
    });

/// 一次「把这一集加入下载」的请求。
class DownloadRequest {
  /// 构造请求。
  const DownloadRequest({
    required this.siteId,
    required this.vodId,
    required this.flag,
    required this.vodName,
    this.episodeId,
    this.episodeName,
  });

  /// 站点 ID。
  final int siteId;

  /// 影片 ID。
  final String vodId;

  /// 线路名（对应 `vod_play_from` 里的一个通道）。
  final String flag;

  /// 影片名，用于保存路径与列表显示。
  final String vodName;

  /// 剧集序号（详情页的 `VodEpisode.id`）；`null` 按第一集。
  final String? episodeId;

  /// 剧集名（如「第 03 集」）；电影为 `null`。
  final String? episodeName;
}

/// 下载编排用例。
class DownloadUseCase {
  /// 构造。
  ///
  /// [savePathFor] 由应用层注入（`AppAssembly.downloadSavePathFor`）：保存路径
  /// 属于「这个应用把东西放哪」的策略，不是下载模块的职责 —— 下载模块只知道
  /// 自己拿到了一个目录。
  DownloadUseCase({
    required this.resolveSource,
    required this.manager,
    required this.savePathFor,
  });

  /// 解析真实地址（装配层接的是 `PlayUseCase`）。
  final PlayableSourceResolver resolveSource;

  /// 下载管理器。
  final DownloadManager manager;

  /// 保存路径拼装：`(影片名, 集名) -> 绝对路径`。
  final String Function(String vodName, String? episodeName) savePathFor;

  /// 把 [request] 指的那一集加入下载，并立即触发调度。
  ///
  /// **幂等**：同一 `(siteId, vodId, episodeName)` 只要还有一个未取消的任务，
  /// 就直接把它返回，不再解析地址、不再建任务。理由有两个：
  ///
  /// - 用户在详情页连点两次「下载」不该得到两条记录、两份流量；
  /// - 失败的任务也算「已存在」。重复点下载悄悄再建一条，会让人以为「第一次
  ///   失败了所以第二次是重试」，实际是两条独立记录各下一半 —— 重试的正确
  ///   入口是下载列表里的「继续」。
  ///
  /// `cancelled` 不算：取消的语义是「我不要了」，用户再点下载就是重新要。
  Future<Result<DownloadTask, AppError>> addEpisode(
    DownloadRequest request,
  ) async {
    final existing = findExisting(request);
    if (existing != null) return Ok(existing);

    final playResult = await resolveSource(
      siteId: request.siteId,
      vodId: request.vodId,
      flag: request.flag,
      episodeId: request.episodeId,
    );
    if (playResult.isErr) return Err(playResult.errorOrNull!);

    final source = playResult.valueOrNull!;
    final task = await manager.createTask(
      title: request.vodName,
      url: source.uri.toString(),
      savePath: savePathFor(request.vodName, request.episodeName),
      headers: source.headers,
      siteId: request.siteId,
      vodId: request.vodId,
      episodeName: request.episodeName,
    );
    // 建完就发车：用户点的是「下载」，不是「放进待办」。调度器仍可能因为
    // 并发上限把它排在队列里，那是另一回事。
    await manager.startDownload(task.id);
    return Ok(task);
  }

  /// 列表里已存在的同集任务；没有则 `null`。
  ///
  /// 单独抽出来是为了让 UI 能**先问再做**：详情页要在点下去之前就把「已加入
  /// 下载」的按钮状态画出来，而不是等用户点了才发现。
  DownloadTask? findExisting(DownloadRequest request) {
    for (final task in manager.tasks) {
      if (task.status == DownloadStatus.cancelled) continue;
      if (task.siteId != request.siteId) continue;
      if (task.vodId != request.vodId) continue;
      if (task.episodeName != request.episodeName) continue;
      return task;
    }
    return null;
  }
}
