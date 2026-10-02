/// [DownloadUseCase] 的单测。
///
/// 全程不碰网络与数据库：解析地址是注入的函数，落库走内存仓储。这里要钉住的是
/// 「在详情页点一次下载会发生什么」—— 解析、请求头透传、按集分目录、发车，
/// 以及**连点两次**这个最容易出错的路径。
library;

import 'package:core_domain/core_domain.dart';
import 'package:download/download.dart';
import 'package:mistream/application/download_use_case.dart';
import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryDownloadRepository repository;
  late _InstantRunner runner;
  late _FakeResolver resolver;
  late DownloadManager manager;
  late DownloadUseCase useCase;

  setUp(() {
    repository = InMemoryDownloadRepository();
    runner = _InstantRunner();
    resolver = _FakeResolver(
      Ok(
        MediaSource(
          uri: Uri.parse('https://cdn.example.com/v/index.m3u8'),
          headers: const {
            'Referer': 'https://example.com/',
            'User-Agent': 'Mozilla/5.0',
          },
        ),
      ),
    );
    manager = DownloadManager(repository: repository, runner: runner);
    useCase = DownloadUseCase(
      resolveSource: resolver.call,
      manager: manager,
      savePathFor: (vodName, episodeName) =>
          episodeName == null ? '/dl/$vodName' : '/dl/$vodName/$episodeName',
    );
    addTearDown(manager.dispose);
  });

  DownloadRequest request({
    String? episodeName = '第 03 集',
    String? episodeId = '2',
  }) => DownloadRequest(
    siteId: 9,
    vodId: '99887',
    flag: '量子',
    vodName: '庆余年',
    episodeId: episodeId,
    episodeName: episodeName,
  );

  test('解析成功后建任务、落库、并把来源与请求头一起记下', () async {
    final result = await useCase.addEpisode(request());

    expect(result.isErr, isFalse, reason: result.errorOrNull?.message);
    final task = result.valueOrNull!;
    expect(task.id, greaterThan(0));
    expect(task.title, '庆余年');
    expect(task.url, 'https://cdn.example.com/v/index.m3u8');
    expect(task.savePath, '/dl/庆余年/第 03 集');
    expect(task.siteId, 9);
    expect(task.vodId, '99887');
    expect(task.episodeName, '第 03 集');
    expect(task.displayName, '庆余年 · 第 03 集');

    // 反盗链头必须跟着走：播放有 mpv 帮忙设置，下载器没有，丢了就是一路 403。
    expect(task.headers['Referer'], 'https://example.com/');
    expect(task.headers['User-Agent'], 'Mozilla/5.0');

    // 落库：`download` 表的 site_id / vod_id / episode_name 三列此前零写入方。
    final stored = (await repository.listTasks()).single;
    expect(stored.id, task.id);
    expect(stored.siteId, 9);
    expect(stored.vodId, '99887');
    expect(stored.episodeName, '第 03 集');
  });

  test('点一次就发车，不用再点第二次「开始」', () async {
    final task = (await useCase.addEpisode(request())).valueOrNull!;
    expect(runner.started, contains(task.id));
  });

  test('解析失败时不建任务、不发车', () async {
    resolver.result = const Err(
      LocalError(code: ErrorCode.sniffNoMatch, message: '这条线路是网页播放页，没嗅到地址'),
    );

    final result = await useCase.addEpisode(request());

    expect(result.isErr, isTrue);
    expect(result.errorOrNull!.message, contains('没嗅到地址'));
    expect(manager.tasks, isEmpty, reason: '解析不出来就不该在列表里留一条空任务');
    expect(runner.started, isEmpty);
  });

  test('同一集连点两次只建一条，且第二次不再解析地址', () async {
    final first = (await useCase.addEpisode(request())).valueOrNull!;
    final second = (await useCase.addEpisode(request())).valueOrNull!;

    expect(second.id, first.id);
    expect(manager.tasks, hasLength(1));
    expect(
      resolver.calls,
      hasLength(1),
      reason: '已存在时不该再解析一遍地址 —— 那会白白起一次 Spider 运行时',
    );
  });

  test('失败的任务也算已存在（重试入口在下载列表，不在详情页）', () async {
    final task = (await useCase.addEpisode(request())).valueOrNull!;
    await repository.upsertTask(
      task.copyWith(status: DownloadStatus.failed, error: '断网'),
    );
    await manager.restore();

    final again = (await useCase.addEpisode(request())).valueOrNull!;

    expect(again.id, task.id);
    expect(manager.tasks, hasLength(1));
  });

  test('取消过的任务不算已存在，再点会重新解析并建一条新的', () async {
    // 取消的语义是「我不要了」。如果取消后点下载还是返回那条已取消的记录，
    // 用户会看到一个永远不动的条目，而下载根本没发生。
    final task = (await useCase.addEpisode(request())).valueOrNull!;
    await manager.cancelDownload(task.id);

    final again = (await useCase.addEpisode(request())).valueOrNull!;

    expect(again.id, isNot(task.id));
    expect(manager.tasks, hasLength(2));
    expect(resolver.calls, hasLength(2));
  });

  test('不同集各建一条，保存路径互不相同', () async {
    final ep3 = (await useCase.addEpisode(request())).valueOrNull!;
    final ep4 = (await useCase.addEpisode(
      request(episodeId: '3', episodeName: '第 04 集'),
    )).valueOrNull!;

    expect(ep4.id, isNot(ep3.id));
    expect(manager.tasks, hasLength(2));
    // HLS 分片文件名是固定的 `segment_000000.ts`，两集共用目录会互相覆盖。
    expect(ep4.savePath, isNot(ep3.savePath));
  });

  test('同一站点下的不同影片互不算已存在', () async {
    // 去重的键是「站点 + 影片 + 集」三件套。少比任何一件，都会让毫不相干的
    // 两部片互相顶掉 —— 用户点了《庆余年》，列表里却多出一条《狂飙》。
    final first = (await useCase.addEpisode(request())).valueOrNull!;
    final other = (await useCase.addEpisode(
      const DownloadRequest(
        siteId: 9,
        vodId: '11000',
        flag: '量子',
        vodName: '狂飙',
        episodeId: '2',
        episodeName: '第 03 集',
      ),
    )).valueOrNull!;

    expect(other.id, isNot(first.id));
    expect(manager.tasks, hasLength(2));
  });

  test('不同站点上的同名影片互不算已存在', () async {
    // 站点 ID 参与去重是因为「影片 ID」只在单个源内唯一：两个不同的采集站
    // 完全可能给同一部片分配同一个 `vod_id`。
    final first = (await useCase.addEpisode(request())).valueOrNull!;
    final other = (await useCase.addEpisode(
      const DownloadRequest(
        siteId: 77,
        vodId: '99887',
        flag: '量子',
        vodName: '庆余年',
        episodeId: '2',
        episodeName: '第 03 集',
      ),
    )).valueOrNull!;

    expect(other.id, isNot(first.id));
    expect(manager.tasks, hasLength(2));
  });

  test('findExisting 能在点下去之前先问', () async {
    expect(useCase.findExisting(request()), isNull);

    await useCase.addEpisode(request());

    expect(useCase.findExisting(request())?.episodeName, '第 03 集');
    // 别的集不算已存在，否则详情页会把整个剧集列表都标成「已下载」。
    expect(useCase.findExisting(request(episodeName: '第 09 集')), isNull);
  });
}

/// 记录调用参数的假解析器。
class _FakeResolver {
  _FakeResolver(this.result);

  Result<MediaSource, AppError> result;

  /// 每次调用的 `站点/影片/线路/集` 摘要。
  final List<String> calls = [];

  Future<Result<MediaSource, AppError>> call({
    required int siteId,
    required String vodId,
    required String flag,
    String? episodeId,
  }) async {
    calls.add('$siteId/$vodId/$flag/${episodeId ?? '-'}');
    return result;
  }
}

/// 立刻成功的假执行器：这里只关心「有没有被发出去」。
class _InstantRunner implements DownloadTaskRunner {
  final List<int> started = [];

  @override
  Future<DownloadResult> run(
    DownloadTask task, {
    void Function(DownloadProgress progress)? onProgress,
    HlsSegmentDone? onSegmentDone,
    Set<int> skipSegments = const {},
    CancelToken? cancelToken,
  }) async {
    started.add(task.id);
    return const DownloadResult(success: true);
  }

  @override
  void dispose() {}
}
