import 'package:live/live.dart';
import 'package:test/test.dart';

/// 实测抓下来的 51zmt / 112114 JSON 响应（字段与真实一致）。
const _realJson = '''
{
  "channel_name": "CCTV-1综合",
  "date": "2026-10-01",
  "epg_data": [
    {"start": "01:03", "end": "01:47",
     "title": "生活早参考-特别节目(生活圈)2026-268 --免费使用"},
    {"start": "23:32", "end": "01:11", "title": "午夜剧场--免费使用"}
  ]
}
''';

/// XMLTV：两个频道，节目时间带 `+0800`，简介含实体。
const _xmltv = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="cctv1">
    <display-name>CCTV-1</display-name>
    <display-name lang="zh">CCTV-1综合</display-name>
  </channel>
  <channel id="cctv2"><display-name>CCTV-2</display-name></channel>
  <programme channel="cctv1" start="20260101120000 +0800"
             stop="20260101130000 +0800">
    <title lang="zh">新闻30分</title>
    <desc>午间新闻 &amp; 天气</desc>
  </programme>
  <programme channel="cctv2" start="20260101120000 +0800"
             stop="20260101130000 +0800">
    <title>经济半小时</title>
  </programme>
</tv>
''';

/// 只有单个频道的 XMLTV（用于「没有歧义就直接采用」那条兜底）。
const _xmltvSingle = '''
<tv>
  <channel id="cctv1"><display-name>CCTV-1</display-name></channel>
  <programme channel="cctv1" start="20260101120000 +0800"
             stop="20260101130000 +0800"><title>新闻30分</title></programme>
</tv>
''';

/// 可控传输层：记录请求地址，按地址返回内容或抛错。
class _FakeFetcher {
  _FakeFetcher(this.bodies);

  final Map<String, String> bodies;
  final List<String> requested = [];

  Future<String> call(String url) async {
    requested.add(url);
    final body = bodies[url];
    if (body == null) throw StateError('未配置的地址: $url');
    return body;
  }
}

void main() {
  group('expandEpgUrl', () {
    test('替换 {name} 与 {date}，频道名做 URL 编码', () {
      final url = expandEpgUrl(
        'http://epg.example/?ch={name}&date={date}',
        channelName: 'CCTV-1综合',
        date: DateTime(2026, 10, 1),
      );
      expect(
        url,
        'http://epg.example/?ch=CCTV-1%E7%BB%BC%E5%90%88&date=2026-10-01',
      );
      // 中文没编码的话请求行里会出现非 ASCII 字节。
      expect(url.contains('综合'), isFalse);
    });

    test('月份与日期补零', () {
      expect(
        expandEpgUrl('x{date}', channelName: 'a', date: DateTime(2026, 1, 5)),
        'x2026-01-05',
      );
    });
  });

  group('EpgJsonParser', () {
    const parser = EpgJsonParser();

    test('解析真实样本：标题剥后缀、跨天节目 end > start', () {
      final epg = parser.parse(_realJson, channelId: 'ch1')!;
      expect(epg.channelId, 'ch1');
      expect(epg.channelName, 'CCTV-1综合');
      expect(epg.programs, hasLength(2));

      expect(epg.programs[0].title, '生活早参考-特别节目(生活圈)2026-268');
      expect(epg.programs[0].endTime - epg.programs[0].startTime, 44 * 60);

      // 末条 23:32 -> 01:11 是次日；不处理的话时长是负数。
      final crossDay = epg.programs[1];
      expect(crossDay.title, '午夜剧场');
      expect(crossDay.duration, greaterThan(0));
      expect(crossDay.endTime, greaterThan(crossDay.startTime));
    });

    test('时刻按顶层 date 拼成当天时间', () {
      final epg = parser.parse(_realJson, channelId: 'ch1')!;
      final start = DateTime.fromMillisecondsSinceEpoch(
        epg.programs[0].startTime * 1000,
      );
      expect([start.year, start.month, start.day], [2026, 10, 1]);
      expect([start.hour, start.minute], [1, 3]);
    });

    test('响应不可用时返回 null（与「解析成功但没节目」区分）', () {
      expect(parser.parse('<html>502</html>', channelId: 'c'), isNull);
      expect(parser.parse('{"epg_data":[]}', channelId: 'c'), isNull);
      expect(
        parser.parse('{"date":"2026-10-01","epg_data":{}}', channelId: 'c'),
        isNull,
      );
    });

    test('当天确实没节目时返回空列表而不是 null', () {
      final epg = parser.parse(
        '{"date":"2026-10-01","epg_data":[]}',
        channelId: 'c',
      )!;
      expect(epg.programs, isEmpty);
    });

    test('缺 channel_name 时用兜底名', () {
      final epg = parser.parse(
        '{"date":"2026-10-01","epg_data":[]}',
        channelId: 'c',
        fallbackName: 'CCTV3',
      )!;
      expect(epg.channelName, 'CCTV3');
    });

    test('坏时刻的节目被丢弃，不污染整张表', () {
      final epg = parser.parse(
        '{"date":"2026-10-01","epg_data":['
        '{"start":"xx","end":"01:00","title":"坏"},'
        '{"start":"02:00","end":"03:00","title":"好"}]}',
        channelId: 'c',
      )!;
      expect(epg.programs, hasLength(1));
      expect(epg.programs.single.title, '好');
    });
  });

  group('cleanEpgTitle', () {
    test('只剥白名单后缀', () {
      expect(cleanEpgTitle('午夜剧场--免费使用'), '午夜剧场');
      expect(cleanEpgTitle('午夜剧场 -- 免费'), '午夜剧场');
    });

    test('正常标题里的 -- 不动', () {
      expect(cleanEpgTitle('XX--特别篇'), 'XX--特别篇');
    });
  });

  group('parseXmltvTime', () {
    test('带时区后缀按 UTC 换算', () {
      expect(
        parseXmltvTime('20260101120000 +0800'),
        DateTime.utc(2026, 1, 1, 4).millisecondsSinceEpoch ~/ 1000,
      );
      expect(
        parseXmltvTime('20260101120000 -0500'),
        DateTime.utc(2026, 1, 1, 17).millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('无时区后缀按本地时间解释', () {
      expect(
        parseXmltvTime('20260101120000'),
        DateTime(2026, 1, 1, 12).millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('解析不出来返回 null 而不是 0', () {
      // 0 是 1970-01-01，会让 isAiring / progress 算出莫名其妙的结果。
      expect(parseXmltvTime(''), isNull);
      expect(parseXmltvTime('garbage'), isNull);
      expect(parseXmltvTime('2026010112000'), isNull);
      expect(parseXmltvTime('20261301120000'), isNull);
      expect(parseXmltvTime('20260101120000 +99'), isNull);
    });
  });

  group('XmltvParser', () {
    const parser = XmltvParser();

    test('按 programme@channel 分组，不混在一起', () {
      final grouped = parser.parse(_xmltv);
      expect(grouped.keys.toSet(), {'cctv1', 'cctv2'});
      expect(grouped['cctv1']!.single.title, '新闻30分');
      expect(grouped['cctv2']!.single.title, '经济半小时');
    });

    test('还原 XML 实体', () {
      final grouped = parser.parse(_xmltv);
      expect(grouped['cctv1']!.single.description, '午间新闻 & 天气');
    });

    test('缺 channel / 坏时间 / 空标题的 programme 被丢弃', () {
      final grouped = parser.parse('''
<tv>
  <programme start="20260101120000 +0800" stop="20260101130000 +0800">
    <title>没有 channel</title></programme>
  <programme channel="a" start="nope" stop="20260101130000 +0800">
    <title>坏时间</title></programme>
  <programme channel="a" start="20260101120000 +0800"
             stop="20260101130000 +0800"><title>   </title></programme>
</tv>
''');
      expect(grouped, isEmpty);
    });

    test('组内按开始时间升序', () {
      final grouped = parser.parse('''
<tv>
  <programme channel="a" start="20260101180000 +0800"
             stop="20260101190000 +0800"><title>晚</title></programme>
  <programme channel="a" start="20260101060000 +0800"
             stop="20260101070000 +0800"><title>早</title></programme>
</tv>
''');
      expect(grouped['a']!.map((p) => p.title).toList(), ['早', '晚']);
    });

    test('解析 <channel> 的 id → display-name', () {
      expect(parser.parseDisplayNames(_xmltv), {
        'cctv1': 'CCTV-1',
        'cctv2': 'CCTV-2',
      });
    });
  });

  group('LiveEpg.fromXmltv', () {
    test('按 display-name 把频道名对到 XMLTV 频道', () {
      // 配置里的 channelId 是本项目自己生成的哈希，几乎不可能等于源站 id，
      // 所以必须靠频道名这一档兜底。
      final epg = LiveEpg.fromXmltv('a1b2c3', 'CCTV-2', _xmltv);
      expect(epg.programs.single.title, '经济半小时');
    });

    test('channelId 直接命中时优先', () {
      final epg = LiveEpg.fromXmltv('cctv1', '对不上任何名字', _xmltv);
      expect(epg.programs.single.title, '新闻30分');
    });

    test('只有单个频道时没有歧义，直接采用', () {
      final epg = LiveEpg.fromXmltv('hash', '完全对不上', _xmltvSingle);
      expect(epg.programs.single.title, '新闻30分');
    });

    test('多频道且对不上时返回空，不猜', () {
      final epg = LiveEpg.fromXmltv('hash', '对不上', _xmltv);
      expect(epg.programs, isEmpty);
    });
  });

  group('EpgFetcher', () {
    test('没有模板时不发请求', () async {
      final fetcher = _FakeFetcher({});
      final epg = EpgFetcher(fetcher: fetcher.call);
      expect(epg.hasTemplates, isFalse);
      expect(await epg.loadFor('ch1', 'CCTV1'), isNull);
      expect(fetcher.requested, isEmpty);
    });

    test('按顺序试模板，取第一个拿到节目的', () async {
      final fetcher = _FakeFetcher({
        'http://a/?ch=CCTV1&date=2026-10-01': '<html>502</html>',
        'http://b/?ch=CCTV1': _realJson,
      });
      final epg = EpgFetcher(
        fetcher: fetcher.call,
        templates: ['http://a/?ch={name}&date={date}', 'http://b/?ch={name}'],
      );
      final result = await epg.loadFor(
        'ch1',
        'CCTV1',
        date: DateTime(2026, 10, 1),
      );
      expect(result!.programs, hasLength(2));
      expect(fetcher.requested, hasLength(2));
      // 结果对回请求的频道 id（源站返回的 channel_name 是另一回事）。
      expect(result.channelId, 'ch1');
    });

    test('结果进缓存，重复调用不再打网络', () async {
      final fetcher = _FakeFetcher({'http://b/?ch=CCTV1': _realJson});
      final epg = EpgFetcher(
        fetcher: fetcher.call,
        templates: ['http://b/?ch={name}'],
      );
      await epg.loadFor('ch1', 'CCTV1');
      await epg.loadFor('ch1', 'CCTV1');
      expect(fetcher.requested, hasLength(1));
      expect(epg.getEpg('ch1'), isNotNull);
    });

    test('空节目单不进缓存（源站补数据是常态）', () async {
      final fetcher = _FakeFetcher({
        'http://b/?ch=CCTV1': '{"date":"2026-10-01","epg_data":[]}',
      });
      final epg = EpgFetcher(
        fetcher: fetcher.call,
        templates: ['http://b/?ch={name}'],
      );
      final first = await epg.loadFor('ch1', 'CCTV1');
      expect(first, isNotNull);
      expect(first!.programs, isEmpty);
      await epg.loadFor('ch1', 'CCTV1');
      expect(fetcher.requested, hasLength(2));
    });

    test('单个模板抛错不冒泡，继续试下一个', () async {
      final fetcher = _FakeFetcher({'http://b/?ch=CCTV1': _realJson});
      final epg = EpgFetcher(
        fetcher: fetcher.call,
        templates: ['http://a/?ch={name}', 'http://b/?ch={name}'],
      );
      final result = await epg.loadFor('ch1', 'CCTV1');
      expect(result!.programs, hasLength(2));
    });

    test('内容嗅探：模板直接给 XMLTV 文件也能解析', () async {
      final fetcher = _FakeFetcher({'http://x/CCTV-2.xml': _xmltv});
      final epg = EpgFetcher(
        fetcher: fetcher.call,
        templates: ['http://x/{name}.xml'],
      );
      final result = await epg.loadFor('ch1', 'CCTV-2');
      expect(result!.programs.single.title, '经济半小时');
    });

    test('模板去重，避免同一地址重复请求', () {
      final epg = EpgFetcher(
        fetcher: _FakeFetcher({}).call,
        templates: ['http://a/{name}', ' http://a/{name} ', ''],
      );
      expect(epg.templates, ['http://a/{name}']);
    });

    test('updateTemplates 替换模板（配置重新导入时）', () {
      final epg = EpgFetcher(
        fetcher: _FakeFetcher({}).call,
        templates: ['http://old/{name}'],
      );
      epg.updateTemplates(['http://new/{name}']);
      expect(epg.templates, ['http://new/{name}']);
      epg.updateTemplates([]);
      expect(epg.hasTemplates, isFalse);
    });

    test('clearCache 后重新拉取', () async {
      final fetcher = _FakeFetcher({'http://b/?ch=CCTV1': _realJson});
      final epg = EpgFetcher(
        fetcher: fetcher.call,
        templates: ['http://b/?ch={name}'],
      );
      await epg.loadFor('ch1', 'CCTV1');
      epg.clearCache();
      expect(epg.getEpg('ch1'), isNull);
      await epg.loadFor('ch1', 'CCTV1');
      expect(fetcher.requested, hasLength(2));
    });

    test('fetchAll 批量拉取已展开的地址', () async {
      final fetcher = _FakeFetcher({
        'http://a/CCTV1': _realJson,
        'http://a/CCTV2': _xmltv,
      });
      final epg = EpgFetcher(fetcher: fetcher.call);
      final result = await epg.fetchAll(const [
        EpgRequest(
          channelId: 'c1',
          channelName: 'CCTV1',
          url: 'http://a/CCTV1',
        ),
        EpgRequest(
          channelId: 'c2',
          channelName: 'CCTV-2',
          url: 'http://a/CCTV2',
        ),
        EpgRequest(
          channelId: 'c3',
          channelName: 'CCTV3',
          url: 'http://a/CCTV3',
        ),
      ]);
      // c3 没配置 → 抛错 → 跳过，不影响其他两个。
      expect(result.keys.toSet(), {'c1', 'c2'});
      expect(result['c1']!.programs, hasLength(2));
      expect(result['c2']!.programs.single.title, '经济半小时');
    });
  });
}
