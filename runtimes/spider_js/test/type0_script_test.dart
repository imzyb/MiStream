import 'package:spider_js/src/drpy/type0_script.dart';
import 'package:test/test.dart';

/// 静态契约守卫。**执行行为**由 `type0_end_to_end_test.dart` 覆盖，这里只钉住
/// 那些「写错了不会报错、只会安静地渲染出空白」的名字。
///
/// 之所以专门守这两类名字，是因为它们真的错过：脚本一度只有 `homeContent` /
/// `vodId` / `classes`，而宿主取的是 `home` / `vod_id` / `class`。两边都不报错，
/// 结果是源能加载、能调用、首页永远空白。这类字符串检查很便宜，值得留着。
void main() {
  group('type=0 内置通用脚本', () {
    test('暴露宿主会去取的入口函数', () {
      for (final name in const <String>[
        'init',
        'home',
        'category',
        'detail',
        'search',
        'play',
      ]) {
        expect(
          type0Script,
          contains('function $name('),
          reason: '缺少入口 $name()，宿主派发时会当作该源没有这个能力',
        );
      }
    });

    test('刻意不定义 homeVod', () {
      // 宿主的 spider.home 把 home() 与 homeVod() 的结果合并且后者覆盖前者，
      // 两个都定义会让首页抓两次、列表还被后一次覆盖。要加回 homeVod 就得同时
      // 改 runtime_child 的合并顺序。
      expect(type0Script, isNot(contains('function homeVod(')));
    });

    test('输出字段是宿主解析器认得的 snake_case', () {
      for (final key in const <String>[
        'vod_id:',
        'vod_name:',
        'vod_pic:',
        'vod_remarks:',
        'vod_content:',
        'vod_play_from:',
        'vod_play_url:',
        'type_id:',
        'type_name:',
        'class:',
        'list:',
      ]) {
        expect(
          type0Script,
          contains(key),
          reason: '缺少 $key —— 解析方（home_use_case / detail_use_case）按它取值',
        );
      }
    });

    test('用 drpy 宿主 API 取页面', () {
      expect(type0Script, contains('req('));
      expect(type0Script, contains('pdfh('));
      expect(type0Script, contains('pdfa('));
      expect(type0Script, contains('joinUrl('));
      expect(type0Script, contains('encodeURIComponent'));
    });

    test('req 的返回值按对象取 content，不是当字符串用', () {
      // req 返回 {content, headers, code, url}。把它整个喂给 pdfh，跨到宿主那边
      // 会被 toString() 成 Dart Map 的 `{content: …}`，页面一条都抽不出来。
      expect(type0Script, contains('resp.content'));
    });

    test('由 ext 配置驱动', () {
      expect(type0Script, contains('__ext'));
      expect(type0Script, contains('homeUrl'));
      expect(type0Script, contains('categoryUrl'));
      expect(type0Script, contains('searchUrl'));
      expect(type0Script, contains('detailRule'));
    });
  });
}
