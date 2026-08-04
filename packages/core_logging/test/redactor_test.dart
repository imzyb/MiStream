import 'package:core_logging/core_logging.dart';
import 'package:test/test.dart';

void main() {
  const redactor = Redactor();

  group('URL query', () {
    // ROADMAP M0 出口标准 ④。
    test('打掉 token，其余参数原样保留', () {
      expect(
        redactor.redactUrl('https://api.example.com/v/x?id=7&token=abc123'),
        'https://api.example.com/v/x?id=7&token=***',
      );
    });

    test('键名大小写与分隔符的各种写法都能命中', () {
      const url =
          'https://a.example.com/p'
          '?Access_Token=x&API-KEY=y&apiKey=z&PWD=w';

      expect(
        redactor.redactUrl(url),
        'https://a.example.com/p'
        '?Access_Token=***&API-KEY=***&apiKey=***&PWD=***',
      );
    });

    test('不含敏感参数的 URL 原样返回，不重新编码', () {
      const url = 'https://a.example.com/p?id=7&q=%E4%B8%AD%E6%96%87#frag';

      expect(redactor.redactUrl(url), url);
    });

    test('重复出现的敏感参数全部打掉', () {
      expect(
        redactor.redactUrl('https://a.example.com/?token=a&token=b'),
        'https://a.example.com/?token=***',
      );
    });

    test('打掉 userInfo 里的账号密码', () {
      expect(
        redactor.redactUrl('https://user:secret@a.example.com/p'),
        'https://***@a.example.com/p',
      );
    });

    test('打掉 fragment 里的 access_token（OAuth 隐式流）', () {
      expect(
        redactor.redactUrl('https://a.example.com/cb#access_token=xyz&s=1'),
        contains('access_token=***'),
      );
    });

    test('幂等：重复脱敏结果不变', () {
      const url = 'https://a.example.com/?id=1&token=abc';
      final once = redactor.redactUrl(url);

      expect(redactor.redactUrl(once), once);
    });

    test('非法 URL 不抛异常，退化为键值对扫描', () {
      expect(
        redactor.redactUrl('http://[bad::uri token=abc'),
        contains('token=***'),
      );
    });
  });

  group('自由文本', () {
    test('打掉正文里 URL 的 token', () {
      expect(
        redactor.redactText('起播 https://cdn.example.com/a.m3u8?token=zzz 成功'),
        '起播 https://cdn.example.com/a.m3u8?token=*** 成功',
      );
    });

    test('打掉裸露的键值对', () {
      expect(
        redactor.redactText('登录参数 password=hunter2, user=amy'),
        '登录参数 password=***, user=amy',
      );
    });

    test('打掉整个 Authorization 头，含值里的空格', () {
      expect(
        redactor.redactText('Authorization: Bearer eyJhbGciOi.J9.abc'),
        'Authorization: ***',
      );
    });

    test('打掉 Cookie 头', () {
      expect(
        redactor.redactText('Cookie: sid=1; theme=dark'),
        'Cookie: ***',
      );
    });

    test('不碰无关内容', () {
      const text = '解析耗时 340ms，code=1900，共 12 条';

      expect(redactor.redactText(text), text);
    });

    test('空字符串直接返回', () {
      expect(redactor.redactText(''), '');
    });
  });

  group('结构化字段', () {
    test('敏感键整值打掉', () {
      expect(
        redactor.redactMap(const {
          'token': 'abc',
          'authorization': 'Bearer x',
          'cookie': 'sid=1',
          'id': 7,
        }),
        {
          'token': '***',
          'authorization': '***',
          'cookie': '***',
          'id': 7,
        },
      );
    });

    test('TVBox 的站点 key 不能被打掉', () {
      // URL query 里的 key 几乎一定是 API key，但配置里的 key 是站点标识，
      // 打掉它诊断信息就没法看了。两张词表分开正是为了这个。
      expect(
        redactor.redactMap(const {'key': 'csp_Bili', 'name': '哔哩'}),
        {'key': 'csp_Bili', 'name': '哔哩'},
      );
      expect(
        redactor.redactUrl('https://a.example.com/?key=SECRET'),
        'https://a.example.com/?key=***',
      );
    });

    test('递归处理嵌套 map 与 list', () {
      expect(
        redactor.redactMap(const {
          'request': {
            'url': 'https://a.example.com/?token=t',
            'headers': {'authorization': 'Bearer x'},
          },
          'candidates': [
            'https://b.example.com/?apikey=k',
            'https://c.example.com/?id=1',
          ],
        }),
        {
          'request': {
            'url': 'https://a.example.com/?token=***',
            'headers': {'authorization': '***'},
          },
          'candidates': [
            'https://b.example.com/?apikey=***',
            'https://c.example.com/?id=1',
          ],
        },
      );
    });

    test('Uri 值也会被脱敏', () {
      expect(
        redactor.redactValue(Uri.parse('https://a.example.com/?token=x')),
        'https://a.example.com/?token=***',
      );
    });

    test('不认识的类型原样返回，不悄悄 toString', () {
      final value = DateTime.utc(2026);

      expect(redactor.redactValue(value), same(value));
    });
  });

  group('normalizeKey', () {
    test('转小写并去掉 - _ 与空格', () {
      expect(Redactor.normalizeKey('API_KEY'), 'apikey');
      expect(Redactor.normalizeKey('X-Api-Key'), 'xapikey');
      expect(Redactor.normalizeKey('Access Token'), 'accesstoken');
    });
  });

  group('自定义词表', () {
    test('可以换掉默认词表与掩码', () {
      const custom = Redactor(
        urlSensitiveKeys: {'nonce'},
        fieldSensitiveKeys: {'nonce'},
        mask: '<hidden>',
      );

      expect(
        custom.redactUrl('https://a.example.com/?nonce=1&token=2'),
        'https://a.example.com/?nonce=%3Chidden%3E&token=2',
      );
      expect(custom.redactMap(const {'nonce': 1}), {'nonce': '<hidden>'});
    });
  });
}
