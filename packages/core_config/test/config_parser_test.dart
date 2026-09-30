import 'package:core_config/core_config.dart';
import 'package:test/test.dart';

void main() {
  group('parseSpiderField：`<url>;md5;<hash>` 内联形态', () {
    test('拆出 URL 与 md5（真实源的实际写法）', () {
      final parsed = parseSpiderField(
        './spider.jar;md5;af187c2a2be1bcbb5e183d77e740b21b',
      );

      expect(parsed.url, './spider.jar');
      expect(parsed.md5, 'af187c2a2be1bcbb5e183d77e740b21b');
    });

    test('http URL 同样能拆', () {
      final parsed = parseSpiderField(
        'https://cdn.example.com/spider.jar;md5;ABCDEF0123456789',
      );

      expect(parsed.url, 'https://cdn.example.com/spider.jar');
      // 大小写原样保留——校验方自己 toLowerCase，改这里会让报错信息失真。
      expect(parsed.md5, 'ABCDEF0123456789');
    });

    test('没有 ;md5; 时整串都是 URL，md5 为 null', () {
      final parsed = parseSpiderField('https://cdn.example.com/spider.jar');

      expect(parsed.url, 'https://cdn.example.com/spider.jar');
      expect(parsed.md5, isNull);
    });

    test('分隔符后的 md5 为空串时视为没有 md5', () {
      final parsed = parseSpiderField('https://x/spider.jar;md5;');

      expect(parsed.url, 'https://x/spider.jar');
      expect(parsed.md5, isNull);
    });

    test('分隔符前为空串时视为没有 URL', () {
      final parsed = parseSpiderField(';md5;abc123');

      expect(parsed.url, isNull);
      expect(parsed.md5, 'abc123');
    });

    test('null / 空串 / 纯空白都得到全 null，不抛异常', () {
      for (final input in <String?>[null, '', '   ']) {
        final parsed = parseSpiderField(input);
        expect(parsed.url, isNull, reason: '输入=$input');
        expect(parsed.md5, isNull, reason: '输入=$input');
      }
    });

    test('首尾空白会被去掉', () {
      final parsed = parseSpiderField('  https://x/a.jar ;md5; deadbeef  ');

      expect(parsed.url, 'https://x/a.jar');
      expect(parsed.md5, 'deadbeef');
    });

    test('explicitMd5 仅在内联缺失时兜底', () {
      final withInline = parseSpiderField(
        'https://x/a.jar;md5;inline',
        explicitMd5: 'explicit',
      );
      expect(withInline.md5, 'inline');

      final withoutInline = parseSpiderField(
        'https://x/a.jar',
        explicitMd5: 'explicit',
      );
      expect(withoutInline.md5, 'explicit');
    });
  });

  group('ConfigParser.parse 接上 spider 拆分', () {
    test('真实源形态：spider 带 ;md5; 时 spiderMd5 不再为 null', () {
      final config = ConfigParser.parse('''
{
  "spider": "./spider.jar;md5;af187c2a2be1bcbb5e183d77e740b21b",
  "sites": []
}
''');

      expect(config, isNotNull);
      expect(config!.spider, './spider.jar');
      expect(config.spiderMd5, 'af187c2a2be1bcbb5e183d77e740b21b');
    });

    test('只有裸 URL 时 spiderMd5 为 null', () {
      final config = ConfigParser.parse('''
{"spider": "https://x/spider.jar", "sites": []}
''');

      expect(config!.spider, 'https://x/spider.jar');
      expect(config.spiderMd5, isNull);
    });

    test('非标准的独立 spider_md5 键仍被尊重', () {
      final config = ConfigParser.parse('''
{"spider": "https://x/spider.jar", "spider_md5": "cafebabe", "sites": []}
''');

      expect(config!.spider, 'https://x/spider.jar');
      expect(config.spiderMd5, 'cafebabe');
    });

    test('没有 spider 字段时两者都是 null', () {
      final config = ConfigParser.parse('{"sites": []}');

      expect(config!.spider, isNull);
      expect(config.spiderMd5, isNull);
    });
  });

  group('ConfigParser.parse lives 字段', () {
    test('真实配置形态：数字 type + epg/logo/ua 一并解析', () {
      // 取自实测的 `gaotianliuyun/gao` 0821.json，字段名与取值原样保留。
      final config = ConfigParser.parse('''
{"sites": [], "lives": [
  {
    "name": "初秋语•ipv4",
    "type": 0,
    "url": "./list.txt",
    "playerType": 2,
    "epg": "http://epg.112114.xyz/?ch={name}&date={date}",
    "logo": "https://live.fanmingming.com/tv/{name}.png"
  },
  {
    "name": "YanG•综合",
    "type": 0,
    "url": "https://tv.iill.top/m3u/Gather",
    "ua": "okhttp/3.15"
  }
]}
''');

      final lives = config!.lives;
      expect(lives.length, 2);

      expect(lives[0].name, '初秋语•ipv4');
      expect(lives[0].type, 0, reason: 'type 是数字，不能丢');
      expect(lives[0].url, './list.txt');
      expect(lives[0].epg, contains('{name}'));
      expect(lives[0].logo, contains('{name}'));

      expect(lives[1].ua, 'okhttp/3.15');
      expect(lives[1].epg, isNull);
    });

    test('type 缺省是 null，不是 0', () {
      // 0 是有效值（约定 0=M3U），用 0 兜缺省就分不出「没写」与「写了 0」。
      final config = ConfigParser.parse(
        '{"sites": [], "lives": [{"name": "x", "url": "http://x"}]}',
      );

      expect(config!.lives.single.type, isNull);
    });

    test('type 写成字符串也能解析', () {
      final config = ConfigParser.parse(
        '{"sites": [], "lives": [{"name": "x", "url": "http://x", "type": "1"}]}',
      );

      expect(config!.lives.single.type, 1);
    });

    test('lives 不是数组时不抛异常', () {
      final config = ConfigParser.parse('{"sites": [], "lives": "oops"}');

      expect(config!.lives, isEmpty);
    });
  });
}
