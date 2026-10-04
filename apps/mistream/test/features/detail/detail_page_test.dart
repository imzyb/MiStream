/// [DetailPage] 渲染测试：封面、标签、线路、剧集与简介。
library;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/app/app.dart';
import 'package:mistream/application/app_assembly.dart';
import 'package:mistream/application/detail_use_case.dart';
import 'package:mistream/features/common/widgets/poster_image.dart';
import 'package:mistream/features/detail/detail_page.dart';
import 'package:storage/storage.dart';

class _FakeDetailUseCase extends DetailUseCase {
  // 父类构造参数是库私有 `_sites`，跨库无法用 super 参数，只能显式转发。
  // ignore: use_super_parameters -- 父类私有字段无法用 super
  _FakeDetailUseCase(SiteRepository sites) : super(sites);

  @override
  Future<Result<VodDetail, AppError>> load({
    required int siteId,
    required String vodId,
  }) async {
    return const Ok(
      VodDetail(
        name: '测试影片',
        pic: 'https://img.example/poster.jpg',
        year: '2024',
        area: '中国大陆',
        genre: '剧情,悬疑',
        remarks: '更新至 8 集',
        description: '这是一部测试影片的简介。',
        flags: ['量子m3u8', '无尽'],
        episodes: {
          '量子m3u8': [
            VodEpisode(name: '第1集', id: '0'),
            VodEpisode(name: '第2集', id: '1'),
          ],
          '无尽': [
            VodEpisode(name: '第1集', id: '0'),
            VodEpisode(name: '第2集', id: '1'),
          ],
        },
      ),
    );
  }
}

void main() {
  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final assembly = AppAssembly(db, Repositories(db));

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          assembly: assembly,
          child: DetailPage(
            siteId: 1,
            vodId: '42',
            useCase: _FakeDetailUseCase(SiteRepository(db)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('详情页展示封面、标签、线路与剧集', (tester) async {
    await pumpDetail(tester);

    // 标题
    expect(find.text('测试影片'), findsWidgets);

    // 信息标签
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('中国大陆'), findsOneWidget);
    expect(find.text('剧情,悬疑'), findsOneWidget);
    expect(find.text('更新至 8 集'), findsOneWidget);

    // 简介
    expect(find.text('这是一部测试影片的简介。'), findsOneWidget);

    // 封面（PosterImage；测试环境网络图走 error 占位）
    expect(find.byType(PosterImage), findsOneWidget);

    // 线路
    expect(find.text('量子m3u8'), findsOneWidget);
    expect(find.text('无尽'), findsOneWidget);

    // 剧集：默认只渲染选中线路（m3u8 优先）的剧集
    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('第2集'), findsOneWidget);

    // 切换线路后仍渲染新线路的剧集
    await tester.tap(find.text('无尽'));
    await tester.pumpAndSettle();
    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('第2集'), findsOneWidget);
  });

  testWidgets('详情页加载失败展示错误与重试', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final assembly = AppAssembly(db, Repositories(db));

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          assembly: assembly,
          child: DetailPage(
            siteId: 1,
            vodId: '42',
            useCase: _FailingDetailUseCase(SiteRepository(db)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('加载详情失败'), findsOneWidget);
  });
}

class _FailingDetailUseCase extends DetailUseCase {
  // 父类构造参数是库私有 `_sites`，跨库无法用 super 参数，只能显式转发。
  // ignore: use_super_parameters -- 父类私有字段无法用 super
  _FailingDetailUseCase(SiteRepository sites) : super(sites);

  @override
  Future<Result<VodDetail, AppError>> load({
    required int siteId,
    required String vodId,
  }) async {
    return const Err(
      LocalError(code: ErrorCode.networkTimeout, message: '加载详情失败'),
    );
  }
}
