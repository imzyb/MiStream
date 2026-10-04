/// `json_parser.dart` 的回归测试。
///
/// **期望值不是手写的**：用 Node 加载参考实现（drpynode）的
/// `libs_drpy/jsonpathplus.min.js`，逐字复刻 `htmlParser.js` 的
/// `jsonpath.query` 与 `Jsoup.pjfh / pj / pjfa` 后实测产出，再抄进来。
/// 下面每条断言后面的注释都是实测结果的直接记录，包括几条与直觉相反的：
///
///   - `[-1]` 负下标**不命中**（返回空集），不是"取最后一个"
///   - `pjfh('$.code')` 在 `code == 0` 时返回 `''`（假值被 `|| ''` 吞掉）
///   - `pjfh('$.data.total')` 返回**数字** `3`，不是字符串 `'3'`
///   - `$.data.list[?(@.tags)]` 里空数组 `[]` 也算命中（JS 里 `[]` 是真值）
///   - `$..*` 的遍历顺序是"先输出全部子值，再逐个下钻"，既不是纯 BFS 也不是纯 DFS
///   - `pj` 在空 base 下把相对路径拼成 `/a.jpg`（无 host 的伪绝对路径），
///     且命中数字时返回的是**字符串** `'/3'`
library;

import 'package:spider_js/src/drpy/json_parser.dart';
import 'package:test/test.dart';

/// 测试数据。与跑预言机时用的完全一致——口径不同期望值就不可比。
Map<String, Object?> doc() => <String, Object?>{
  'code': 0,
  'msg': 'ok',
  'data': <String, Object?>{
    'total': 3,
    'list': <Object?>[
      <String, Object?>{
        'vod_id': 1,
        'vod_name': '甲',
        'vod_pic': 'a.jpg',
        'tags': <Object?>['x', 'y'],
      },
      <String, Object?>{
        'vod_id': 2,
        'vod_name': '乙',
        'vod_pic': 'b.jpg',
        'tags': <Object?>['y'],
      },
      <String, Object?>{
        'vod_id': 3,
        'vod_name': '丙',
        'vod_pic': 'c.jpg',
        'tags': <Object?>[],
      },
    ],
    'nested': <String, Object?>{
      'deep': <String, Object?>{'name': '深处'},
    },
  },
};

/// 第 [i] 条站点。
Map<String, Object?> item(int i) =>
    ((doc()['data']! as Map<String, Object?>)['list']! as List<Object?>)[i]!
        as Map<String, Object?>;

void main() {
  group('jsonPathQuery：基础取值', () {
    test('根、成员、嵌套成员', () {
      expect(jsonPathQuery(doc(), r'$.code'), <Object?>[0]);
      expect(jsonPathQuery(doc(), r'$.msg'), <Object?>['ok']);
      expect(jsonPathQuery(doc(), r'$.data.total'), <Object?>[3]);
      expect(jsonPathQuery(doc(), r'$.data.list[0]'), <Object?>[item(0)]);
      expect(jsonPathQuery(doc(), r'$.data.list[1].vod_name'), <Object?>['乙']);
      expect(jsonPathQuery(doc(), r'$.data.nested.deep.name'), <Object?>['深处']);
    });

    test('根路径返回根自身', () {
      expect(jsonPathQuery(doc(), r'$'), <Object?>[doc()]);
    });

    test('引号成员名', () {
      expect(jsonPathQuery(doc(), r"$['data']['total']"), <Object?>[3]);
      expect(
        jsonPathQuery(doc(), r"$['data']['list'][0]['vod_name']"),
        <Object?>['甲'],
      );
    });

    test('命不中一律给空集，不抛错', () {
      expect(jsonPathQuery(doc(), r'$.missing'), isEmpty);
      expect(jsonPathQuery(doc(), r'$.missing.deep'), isEmpty);
      expect(jsonPathQuery(doc(), r'$.data.list[*].missing'), isEmpty);
      // 取数字的方法名也不命中（参考实现里函数属性不返回）
      expect(jsonPathQuery(doc(), r'$.data.total.toFixed'), isEmpty);
    });
  });

  group('jsonPathQuery：下标与切片', () {
    test('正下标', () {
      expect(jsonPathQuery(doc(), r'$.data.list[0].tags[0]'), <Object?>['x']);
    });

    test('负下标不命中——参考实现不支持，不是「取最后一个」', () {
      expect(jsonPathQuery(doc(), r'$.data.list[-1].vod_name'), isEmpty);
    });

    test('越界下标不命中', () {
      expect(jsonPathQuery(doc(), r'$.data.list[10]'), isEmpty);
    });

    test('并集', () {
      expect(jsonPathQuery(doc(), r'$.data.list[0,2].vod_id'), <Object?>[1, 3]);
    });

    test('切片左闭右开', () {
      expect(jsonPathQuery(doc(), r'$.data.list[0:2].vod_id'), <Object?>[1, 2]);
    });
  });

  group('jsonPathQuery：通配与递归下降', () {
    test('通配', () {
      expect(
        jsonPathQuery(doc(), r'$.data.list[*].vod_name'),
        <Object?>['甲', '乙', '丙'],
      );
      expect(
        jsonPathQuery(doc(), r'$.data.list[*].tags[*]'),
        <Object?>['x', 'y', 'y'],
      );
    });

    test('对象的通配按插入顺序给全部值', () {
      expect(jsonPathQuery(doc(), r'$.*'), <Object?>[
        0,
        'ok',
        doc()['data'],
      ]);
      expect(jsonPathQuery(doc(), r'$.data.*'), <Object?>[
        3,
        (doc()['data']! as Map<String, Object?>)['list'],
        <String, Object?>{
          'deep': <String, Object?>{'name': '深处'},
        },
      ]);
    });

    test('数组根上的通配', () {
      final arr = <Object?>[
        <String, Object?>{'a': 1},
        <String, Object?>{'a': 2},
      ];
      expect(jsonPathQuery(arr, r'$[0].a'), <Object?>[1]);
      expect(jsonPathQuery(arr, r'$[*].a'), <Object?>[1, 2]);
      expect(jsonPathQuery(doc(), r'$.a'), isEmpty);
    });

    test('递归下降取成员', () {
      expect(jsonPathQuery(doc(), r'$..name'), <Object?>['深处']);
      expect(jsonPathQuery(doc(), r'$..vod_name'), <Object?>['甲', '乙', '丙']);
      expect(jsonPathQuery(doc(), r'$..tags'), <Object?>[
        <Object?>['x', 'y'],
        <Object?>['y'],
        <Object?>[],
      ]);
    });

    test('`..*` 的顺序：先输出全部子值，再逐个下钻', () {
      // 这条断言锁的是遍历顺序本身。参考实现既不是纯 BFS 也不是纯 DFS，
      // 是「一个节点的全部子值先出，再依次下钻」。
      expect(jsonPathQuery(doc(), r'$..*'), <Object?>[
        0,
        'ok',
        doc()['data'],
        3,
        (doc()['data']! as Map<String, Object?>)['list'],
        <String, Object?>{
          'deep': <String, Object?>{'name': '深处'},
        },
        item(0),
        item(1),
        item(2),
        1,
        '甲',
        'a.jpg',
        <Object?>['x', 'y'],
        'x',
        'y',
        2,
        '乙',
        'b.jpg',
        <Object?>['y'],
        'y',
        3,
        '丙',
        'c.jpg',
        <Object?>[],
        <String, Object?>{'name': '深处'},
        '深处',
      ]);
    });

    test('.length 按 JS 属性语义取字符串长度', () {
      expect(
        jsonPathQuery(doc(), r'$.data.list[0].vod_name.length'),
        <Object?>[1],
      );
    });
  });

  group('jsonPathQuery：过滤', () {
    test('相等与不等', () {
      expect(
        jsonPathQuery(doc(), r'$.data.list[?(@.vod_id==2)].vod_name'),
        <Object?>['乙'],
      );
      expect(
        jsonPathQuery(doc(), r'$.data.list[?(@.vod_name=="甲")].vod_id'),
        <Object?>[1],
      );
    });

    test('大小比较', () {
      expect(
        jsonPathQuery(doc(), r'$.data.list[?(@.vod_id>1)].vod_name'),
        <Object?>['乙', '丙'],
      );
      expect(
        jsonPathQuery(doc(), r'$.data.list[?(@.vod_id>=2)].vod_id'),
        <Object?>[2, 3],
      );
    });

    test('存在性判断：空数组也算命中（JS 里 [] 是真值）', () {
      expect(
        jsonPathQuery(doc(), r'$.data.list[?(@.tags)].vod_id'),
        <Object?>[1, 2, 3],
      );
    });

    test('支持逻辑运算', () {
      expect(
        jsonPathQuery(doc(), r'$.data.list[?(@.vod_id>1&&@.vod_id<3)].vod_id'),
        <Object?>[2],
      );
      expect(
        jsonPathQuery(
          doc(),
          r'$.data.list[?(@.vod_id==1||@.vod_id==3)].vod_id',
        ),
        <Object?>[1, 3],
      );
    });
  });

  group('jsonPathQuery：不支持的写法要报错，不能静默给空集', () {
    test(r'不以 $ 开头', () {
      expect(() => jsonPathQuery(doc(), 'data.total'), throwsFormatException);
    });

    test('递归过滤 `..[`', () {
      expect(
        () => jsonPathQuery(doc(), r'$..[?(@.a)]'),
        throwsFormatException,
      );
    });

    test('下标不是整数', () {
      expect(
        () => jsonPathQuery(doc(), r'$.data.list[abc]'),
        throwsFormatException,
      );
    });

    test('括号不配对', () {
      expect(
        () => jsonPathQuery(doc(), r'$.data.list[0'),
        throwsFormatException,
      );
    });
  });

  group('pjfh：取单值（含 `||` 回退）', () {
    test('普通取值', () {
      expect(pjfh(doc(), r'$.msg'), 'ok');
      expect(pjfh(doc(), r'$.data.list[0].vod_name'), '甲');
      expect(pjfh(doc(), r'$.data.nested.deep.name'), '深处');
    });

    test("假值被吞成空串——`0` 取出来是 `''`", () {
      expect(pjfh(doc(), r'$.code'), '');
    });

    test('返回类型不一定是字符串：命中数字就是数字，命中数组就是数组', () {
      expect(pjfh(doc(), r'$.data.total'), 3);
      expect(pjfh(doc(), r'$.data.list[0].tags'), <Object?>['x', 'y']);
      // 空数组在 JS 里是**真值**，所以 pjfh 会原样返回 `[]`；只有走 urljoin
      // 强转的 `pj` 才会把它变成空串（见下面的用例）。
      expect(pjfh(doc(), r'$.data.list[2].tags'), <Object?>[]);
    });

    test('多条路径命中时取第一条', () {
      expect(pjfh(doc(), r'$.data.list[*].vod_name'), '甲');
    });

    test(r'规则不以 $. 开头时会自动补上', () {
      expect(pjfh(doc(), 'data.total'), 3);
    });

    test('`||` 回退取第一个非假值', () {
      expect(pjfh(doc(), r'$.missing'), '');
      expect(pjfh(doc(), r'$.missing||$.msg'), 'ok');
      // 注意 `$.code` 命中的 0 是假值，所以回退到了 `$.msg`
      expect(pjfh(doc(), r'$.code||$.msg'), 'ok');
    });

    test('入参可以是 JSON 字符串', () {
      expect(pjfh('{"a":{"b":"嵌套"}}', r'$.a.b'), '嵌套');
    });

    test('JSON 解析失败、空入参、空规则都给空串', () {
      expect(pjfh('not json', r'$.a'), '');
      expect(pjfh('', r'$.a'), '');
      expect(pjfh(doc(), ''), '');
    });

    test('addUrl 在空 base 下给出根相对路径——参考实现的行为，照搬不修', () {
      // 全局 `pj` 用的是空 base，urljoin 会把 `a.jpg` 拼成 `/a.jpg`，制造出
      // 没有 host 的伪绝对路径。这是参考实现的既有行为，兼容层照搬。
      expect(pjfh(doc(), r'$.data.list[0].vod_pic', addUrl: true), '/a.jpg');
      expect(pj(doc(), r'$.data.list[0].vod_pic'), '/a.jpg');
    });

    test('addUrl 会把非字符串入参转成字符串', () {
      // `urljoin` 内部经 `new URL()` 强转：数字 3 出来是字符串 '/3'。
      expect(pj(doc(), r'$.data.total'), '/3');
      expect(pj(doc(), r'$.data.total'), isA<String>());
      // 数组走 JS `String([])`：`[]` -> ''（假值，最后落到空串）、
      // `['x','y']` -> 'x,y'。
      expect(pj(doc(), r'$.data.list[2].tags'), '');
      expect(pj(doc(), r'$.data.list[0].tags'), '/x,y');
    });

    test('addUrl 在有 base 时按 base 解析', () {
      expect(
        pj(doc(), r'$.data.list[0].vod_pic', baseUrl: 'http://a.com/x/'),
        'http://a.com/x/a.jpg',
      );
      expect(
        pj(doc(), r'$.data.list[1].vod_pic', baseUrl: 'http://a.com/x/'),
        'http://a.com/x/b.jpg',
      );
    });

    test('已是绝对地址的不会被 base 改写', () {
      expect(
        pjfh(
          <String, Object?>{'u': 'https://cdn.example.com/v.mp4'},
          r'$.u',
          addUrl: true,
          baseUrl: 'http://a.com/x/',
        ),
        'https://cdn.example.com/v.mp4',
      );
    });
  });

  group('pjfa：取数组', () {
    test('多项命中直接给命中集合', () {
      expect(
        pjfa(doc(), r'$.data.list[*].vod_name'),
        <Object?>['甲', '乙', '丙'],
      );
      expect(pjfa(doc(), r'$.data.list[*].tags[*]'), <Object?>['x', 'y', 'y']);
      expect(
        pjfa(doc(), r'$.data.list[?(@.vod_id>1)].vod_name'),
        <Object?>['乙', '丙'],
      );
    });

    test('单次命中且本身是数组时展开该项', () {
      expect(
        pjfa(doc(), r'$.data.list'),
        <Object?>[item(0), item(1), item(2)],
      );
      expect(pjfa(doc(), r'$.data.list[0].tags'), <Object?>['x', 'y']);
    });

    test('单次命中但不是数组时不展开', () {
      expect(pjfa(doc(), r'$.msg'), <Object?>['ok']);
    });

    test('没有命中、空入参、空规则都给空列表', () {
      expect(pjfa(doc(), r'$.missing'), isEmpty);
      expect(pjfa('not json', r'$.a'), isEmpty);
      expect(pjfa(doc(), ''), isEmpty);
    });
  });
}
