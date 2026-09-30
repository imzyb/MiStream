import 'package:live/live.dart';
import 'package:test/test.dart';

/// 真实 txt 样本：原样抄自 `live.zbds.top/tv/iptv4.txt` 的前若干行，
/// 把各条边界行都留下（分组标记、同名多地址、尾随 `#`、尾随逗号、
/// `;` 歧义、HTML 实体）。
const _realTxt = '''
央视频道,#genre#
CCTV1,http://74.91.26.218:82/live/cctv1hd.m3u8
CCTV1,http://101.66.194.125:9901/tsfile/live/0001_1.m3u8?key=txiptv&playlive=0&authid=0
CCTV1,http://1.197.250.140:9901/tsfile/live/0001_1.m3u8?key=txiptv&playlive=1&authid=0
CCTV2,http://101.66.194.125:9901/tsfile/live/0002_1.m3u8?key=txiptv&playlive=0&authid=0
卫视频道,#genre#
新疆卫视,http://218.84.12.186:8001/hls/main/playlist.m3u8?zxinjd;http://218.84.12.186:8001/hls/main/playlist.m3u8zxinjd
云霄综合,http://live.zzyxxw.com:85/live/xwzh.m3u8?fujian,
延边卫视,http://l.cztvcloud.com/channels/lantian/SXxinchang2/720p.m3u8#
浙江经济生活,http://ali-m-l.cztv.com/channels/lantian/channel03/1080p.m3u8#https://ali-m-l.cztv.com/channels/lantian/channel003/1080p.m3u8
太谷新闻综合,https://p2.vzan.com/slowlive/596867413819827251/live.m3u8?zbid=1725814272&amp;amp;tpid=1516989100&amp;amp;type=0
''';

/// 标准 m3u 写法：频道名在 `#EXTINF` 行的**最后一个逗号之后**。
const _m3uStandard = '''
#EXTM3U
#EXTINF:-1 tvg-id="cctv1" tvg-logo="http://logo/1.png" group-title="央视",CCTV-1综合
http://a.example/cctv1.m3u8
#EXTINF:-1 group-title="央视",CCTV-2财经
http://a.example/cctv2.m3u8
#EXTINF:-1,无分组频道
http://a.example/nogroup.m3u8
''';

/// 变体 m3u 写法：频道名**独占一行**（`#EXTINF` 行末没有逗号）。
const _m3uVariant = '''
#EXTM3U
#EXTINF:-1 tvg-name="CCTV1" group-title="央视" tvg-logo="http://logo.png",
CCTV1
http://example.com/cctv1.m3u8
#EXTINF:-1 tvg-name="湖南卫视" group-title="卫视",
湖南卫视
http://example.com/hunan.m3u8
''';

void main() {
  late LiveParser parser;

  setUp(() => parser = LiveParser());

  group('txt：分组标记行', () {
    test('`分组名,#genre#` 不产生假频道', () {
      final result = parser.parse(_realTxt);
      final bogus = result.channels.where((c) => c.url.contains('genre'));

      expect(bogus, isEmpty, reason: '#genre# 是分组声明，不是频道地址');
    });

    test('分组被识别出来，频道归到正确的组', () {
      final result = parser.parse(_realTxt);

      expect(result.groups.map((g) => g.name), ['央视频道', '卫视频道']);
      final cctv1 = result.channels.firstWhere((c) => c.name == 'CCTV1');
      expect(cctv1.groupId, '央视频道');
    });

    test('分组顺序按出现顺序', () {
      final result = parser.parse(_realTxt);

      expect(result.groups.map((g) => g.order), [0, 1]);
    });
  });

  group('txt：多地址', () {
    test('同名多行合并成一个频道 + 备用地址', () {
      final result = parser.parse(_realTxt);
      final cctv1 = result.channels.firstWhere((c) => c.name == 'CCTV1');

      expect(cctv1.allUrls.length, 3);
      expect(cctv1.url, 'http://74.91.26.218:82/live/cctv1hd.m3u8');
      expect(cctv1.extraUrls.length, 2);
    });

    test('同名频道只出现一次', () {
      final result = parser.parse(_realTxt);

      expect(result.channels.where((c) => c.name == 'CCTV1').length, 1);
    });

    test('`url1#url2` 按 `#` 拆成两条', () {
      final result = parser.parse(_realTxt);
      final zj = result.channels.firstWhere((c) => c.name == '浙江经济生活');

      expect(zj.allUrls, [
        'http://ali-m-l.cztv.com/channels/lantian/channel03/1080p.m3u8',
        'https://ali-m-l.cztv.com/channels/lantian/channel003/1080p.m3u8',
      ]);
    });

    test('尾随 `#` 不产生空地址', () {
      final result = parser.parse(_realTxt);
      final yb = result.channels.firstWhere((c) => c.name == '延边卫视');

      expect(yb.allUrls.length, 1);
      expect(yb.url, endsWith('.m3u8'));
    });

    test('尾随逗号不产生空地址', () {
      final result = parser.parse(_realTxt);
      final yx = result.channels.firstWhere((c) => c.name == '云霄综合');

      expect(yx.allUrls, ['http://live.zzyxxw.com:85/live/xwzh.m3u8?fujian']);
    });

    test('URL 里的 `&amp;` 不被 `;` 拆开', () {
      final result = parser.parse(_realTxt);
      final tg = result.channels.firstWhere((c) => c.name == '太谷新闻综合');

      expect(tg.allUrls.length, 1);
      expect(tg.url, contains('&amp;amp;tpid=1516989100&amp;amp;type=0'));
    });

    test('`url1;url2` 两条都像地址时才按 `;` 拆', () {
      final result = parser.parse(_realTxt);
      final xj = result.channels.firstWhere((c) => c.name == '新疆卫视');

      expect(xj.allUrls.length, 2);
    });
  });

  group('m3u：两种写法', () {
    test('标准写法（名字在行末逗号之后）', () {
      final result = parser.parse(_m3uStandard);

      expect(result.channels.length, 3);
      expect(result.channels[0].name, 'CCTV-1综合');
      expect(result.channels[0].url, 'http://a.example/cctv1.m3u8');
      expect(result.channels[0].logo, 'http://logo/1.png');
      expect(result.groups.map((g) => g.name), ['央视']);
    });

    test('变体写法（名字独占一行）', () {
      final result = parser.parse(_m3uVariant);

      expect(result.channels.length, 2);
      expect(result.channels.map((c) => c.name), ['CCTV1', '湖南卫视']);
    });

    test('跳过 #EXTVLCOPT / #EXTGRP 这类附加指令', () {
      final result = parser.parse('''
#EXTM3U
#EXTINF:-1 group-title="央视",CCTV1
#EXTVLCOPT:http-user-agent=okhttp/3.15
#EXTGRP:央视
http://a.example/cctv1.m3u8
''');

      expect(result.channels.length, 1);
      expect(result.channels.single.url, 'http://a.example/cctv1.m3u8');
    });

    test('tvg-name 只在行末没名字时兜底', () {
      final result = parser.parse('''
#EXTM3U
#EXTINF:-1 tvg-name="备用名",
http://a.example/x.m3u8
''');

      // 行末逗号后为空 → 读下一条内容行当名字，那条是 URL，所以名字落到 tvg-name。
      expect(result.channels.single.name, '备用名');
    });
  });

  group('分组视图', () {
    test('无分组频道归入「未分组」桶，不丢', () {
      final result = parser.parse(
        'CCTV1,http://a/1.m3u8\nCCTV2,http://a/2.m3u8\n',
      );

      expect(result.ungroupedChannels.length, 2);
      expect(result.channelsByGroup.length, 1);
      expect(
        result.channelsByGroup.keys.single,
        LiveParseResult.ungroupedGroup,
      );
    });

    test('各桶之和等于全部频道数', () {
      final result = parser.parse(_realTxt);
      final total = result.channelsByGroup.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );

      expect(total, result.channels.length);
    });

    test('未分组桶永远排在最后', () {
      // 未分组频道必须在**任何分组标记之前**：分组标记行之后的所有频道都
      // 归属该组，写在后面就不是未分组了。
      final result = parser.parse('''
孤零零,http://a/2.m3u8
央视频道,#genre#
CCTV1,http://a/1.m3u8
''');

      final keys = result.channelsByGroup.keys.toList();
      expect(keys.map((g) => g.name), ['央视频道', '未分组']);
      expect(keys.last, LiveParseResult.ungroupedGroup);
    });
  });

  group('splitUrls', () {
    test('硬分隔符 `|` 与空白也生效', () {
      expect(splitUrls('http://a/1.m3u8|http://b/2.m3u8').length, 2);
      expect(splitUrls('http://a/1.m3u8 http://b/2.m3u8').length, 2);
    });

    test('不是地址的片段被丢弃', () {
      expect(splitUrls('#genre#'), isEmpty);
      expect(splitUrls('   '), isEmpty);
    });

    test('单个地址原样返回', () {
      expect(splitUrls('http://a/1.m3u8'), ['http://a/1.m3u8']);
    });
  });

  group('hasUrlScheme', () {
    test('认常见 scheme', () {
      for (final url in [
        'http://a/x',
        'https://a/x',
        'rtmp://a/x',
        'rtsp://a/x',
        'udp://@239.1.1.1:1234',
        'file:///x',
      ]) {
        expect(hasUrlScheme(url), isTrue, reason: url);
      }
    });

    test('相对路径与裸字符串不算', () {
      expect(hasUrlScheme('./list.txt'), isFalse);
      expect(hasUrlScheme('list.txt'), isFalse);
      expect(hasUrlScheme('/abs/x.m3u8'), isFalse);
      expect(hasUrlScheme(''), isFalse);
    });
  });

  group('LiveParseResult.merge', () {
    test('两个源的同名频道合并地址', () {
      final a = parser.parse('CCTV1,http://a/1.m3u8\n');
      final b = parser.parse('CCTV1,http://b/1.m3u8\n');

      final merged = LiveParseResult.merge([a, b]);

      expect(merged.channels.length, 1);
      expect(merged.channels.single.allUrls, [
        'http://a/1.m3u8',
        'http://b/1.m3u8',
      ]);
    });

    test('同地址去重', () {
      final a = parser.parse('CCTV1,http://a/1.m3u8\n');
      final b = parser.parse('CCTV1,http://a/1.m3u8\n');

      expect(LiveParseResult.merge([a, b]).channels.single.allUrls.length, 1);
    });

    test('分组按名字去重，顺序按首次出现', () {
      final a = parser.parse('''
甲组,#genre#
A,http://a/1.m3u8
乙组,#genre#
B,http://a/2.m3u8
''');
      final b = parser.parse('''
乙组,#genre#
C,http://b/1.m3u8
丙组,#genre#
D,http://b/2.m3u8
''');

      final merged = LiveParseResult.merge([a, b]);

      expect(merged.groups.map((g) => g.name), ['甲组', '乙组', '丙组']);
      expect(merged.groups.map((g) => g.order), [0, 1, 2]);
    });

    test('合并后各桶之和仍等于全部频道数', () {
      final merged = LiveParseResult.merge([
        parser.parse(_realTxt),
        parser.parse(_m3uStandard),
      ]);
      final total = merged.channelsByGroup.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );

      expect(total, merged.channels.length);
    });

    test('空列表合并得到空结果', () {
      final merged = LiveParseResult.merge([]);

      expect(merged.channels, isEmpty);
      expect(merged.groups, isEmpty);
    });
  });

  group('真实样本回归', () {
    test('iptv4.txt 片段：频道数与分组数稳定', () {
      final result = parser.parse(_realTxt);

      // 11 行里 2 行是分组标记、CCTV1 占 3 行 → 10 条频道记录合并成 7 个频道。
      expect(result.channels.length, 7);
      expect(result.groups.length, 2);
      expect(
        result.channels.map((c) => c.name),
        ['CCTV1', 'CCTV2', '新疆卫视', '云霄综合', '延边卫视', '浙江经济生活', '太谷新闻综合'],
        reason: '顺序应与文件出现顺序一致',
      );
    });

    test('真实样本每个频道都至少有一条地址', () {
      final result = parser.parse(_realTxt);

      for (final channel in result.channels) {
        expect(channel.url, isNotEmpty, reason: channel.name);
      }
    });
  });
}
