import 'package:spider_js/src/drpy/gbk.dart';
import 'package:test/test.dart';

/// `gbkDecode` 的回归测试。
///
/// 测试向量由 CPython 的 `gbk` codec 生成（见 `tools/gen_gbk_table.py` 同源），
/// 不是手算的——手算的 GBK 字节串无法作为权威期望值。
void main() {
  group('gbkDecode 基本解码', () {
    test('纯 ASCII 透传', () {
      expect(gbkDecode(<int>[0x68, 0x65, 0x6C, 0x6C, 0x6F]), 'hello');
    });

    test('常见中文短语', () {
      // '中文字符测试'
      const bytes = <int>[
        214, 208, 206, 196, 215, 214, 183, 251, 178, 226, 202, 212, //
      ];
      expect(gbkDecode(bytes), '中文字符测试');
    });

    test('中文标题（真实源里最常见的形态）', () {
      // '庆余年 第二季'，含 ASCII 空格
      const bytes = <int>[
        199, 236, 211, 224, 196, 234, 32, 181, 218, 182, 254, 188, 190, //
      ];
      expect(gbkDecode(bytes), '庆余年 第二季');
    });

    test('中英混排', () {
      // 'abc中文123'
      const bytes = <int>[
        97, 98, 99, 214, 208, 206, 196, 49, 50, 51, //
      ];
      expect(gbkDecode(bytes), 'abc中文123');
    });

    test('全角标点', () {
      // '《流浪地球》导演：郭帆'
      const bytes = <int>[
        161, 182, 193, 247, 192, 203, 181, 216, 199, 242, 161, 183, //
        181, 188, 209, 221, 163, 186, 185, 249, 183, 171, //
      ];
      expect(gbkDecode(bytes), '《流浪地球》导演：郭帆');
    });

    test('空输入', () {
      expect(gbkDecode(<int>[]), '');
      expect(gbkDecode(null), '');
    });
  });

  group('gbkDecode 输入归一', () {
    test('接受字符串形态的字节串（码位全 <= 0xFF）', () {
      // drpy 里 req(buffer: true) 拿到裸字节后常被当 latin1 字符串传下来。
      final asString = String.fromCharCodes(<int>[214, 208, 206, 196]);
      expect(gbkDecode(asString), '中文');
    });

    test('已经是文本的字符串原样返回，不被二次解码', () {
      // 含 > 0xFF 的码位，说明调用方给的是已解码文本。
      // 若错误地再按 GBK 解一次，'中文' 会变成别的东西。
      expect(gbkDecode('中文'), '中文');
      expect(gbkDecode('庆余年 第二季'), '庆余年 第二季');
    });

    test('负数字节按 8 位截断', () {
      // QuickJS 侧 Int8Array 取值可能带符号。
      expect(gbkDecode(<int>[-42, -48, -50, -60]), '中文');
    });
  });

  group('gbkDecode 容错', () {
    test('孤立的首字节输出替换字符', () {
      // 0xD6 是双字节首字节，后无尾字节。
      final result = gbkDecodeWithReport(<int>[0xD6]);
      expect(result.text, '\uFFFD');
      expect(result.report.unmapped, 1);
    });

    test('非法尾字节不越过边界消费后续字符', () {
      // 0xD6 后跟 0x20（空格，非法尾字节）。应该只脏掉 0xD6，
      // 后面的 ASCII 必须原样保留——错位连锁是这类解码器的经典 bug。
      final result = gbkDecodeWithReport(<int>[0xD6, 0x20, 0x41]);
      expect(result.text, '\uFFFD A');
      expect(result.report.unmapped, 1);
      expect(result.report.mapped, 2);
    });

    test('0x7F 作为尾字节被拒绝，且自身作为 ASCII 透传', () {
      // 0x81 是双字节首字节，0x7F 不是合法尾字节（GBK 尾字节从 0x40 起，
      // 但跳过 0x7F）。按「只脏首字节、不连环错位」的策略，0x81 输出替换
      // 字符，0x7F 作为 ASCII DEL 原样保留。
      final result = gbkDecodeWithReport(<int>[0x81, 0x7F]);
      expect(result.text, '\uFFFD\u007F');
      expect(result.report.unmapped, 1);
    });

    test('0x80 单独出现按未映射处理', () {
      final result = gbkDecodeWithReport(<int>[0x80]);
      expect(result.text, '\uFFFD');
    });

    test('未定义码位输出替换字符', () {
      // 0xA1 0xA0 在 GBK 里是未定义位置（空洞之一）。
      final result = gbkDecodeWithReport(<int>[0xA1, 0xA0]);
      expect(result.text, '\uFFFD');
      expect(result.report.unmapped, 1);
    });

    test('解码过程绝不抛异常', () {
      // 0x00 ~ 0xFF 全字节范围喂一遍，任何输入都应产出结果而非异常。
      final all = List<int>.generate(256, (i) => i);
      expect(() => gbkDecodeWithReport(all), returnsNormally);
    });
  });

  group('gbkDecode 统计', () {
    test('成功映射按字节计（双字节记 2）', () {
      final result = gbkDecodeWithReport(<int>[0xD6, 0xD0, 0x41]);
      expect(result.report.total, 3);
      expect(result.report.mapped, 3);
      expect(result.report.unmapped, 0);
      expect(result.report.unmappedRatio, 0);
    });

    test('未映射占比可用于判断「这页不是 GBK」', () {
      // 一段 UTF-8 中文按 GBK 解时会产生大量未映射字节。
      final utf8Bytes = <int>[0xE4, 0xB8, 0xAD, 0xE6, 0x96, 0x87];
      final result = gbkDecodeWithReport(utf8Bytes);
      expect(result.report.unmappedRatio, greaterThan(0));
    });

    test('空输入占比为 0，不除零', () {
      final result = gbkDecodeWithReport(<int>[]);
      expect(result.report.total, 0);
      expect(result.report.unmappedRatio, 0);
    });
  });

  group('gbkDecode 码表覆盖', () {
    test('GB2312 一级汉字区可解', () {
      // '啊' 是 GB2312 区位第一字，0xB0A1。
      expect(gbkDecode(<int>[0xB0, 0xA1]), '啊');
    });

    test('GBK 扩展区（0x81 起）可解', () {
      // 0x8140 是 GBK 扩展区首字 '丂'。
      expect(gbkDecode(<int>[0x81, 0x40]), '丂');
    });

    test('码表末尾 0xFEFE 未定义，输出替换字符', () {
      // 0xFEFE 在 GBK 标准里是**未定义**位置（已由 CPython gbk codec 交叉
      // 验证），属码表空洞。GB18030 才把它填上，本实现只做纯 GBK。
      final result = gbkDecodeWithReport(<int>[0xFE, 0xFE]);
      expect(result.text, '\uFFFD');
      expect(result.report.unmapped, 1);
    });

    test('长文本（40 字 / 80 字节）整段还原', () {
      // 向量的期望值由 Python gbk codec 生成，覆盖简体常用字与数字混排。
      const expected =
          '庆余年第二季全集中文字符测试长文本往返验证'
          '流浪地球导演郭帆演员吴京刘德华科幻电影';
      const bytes = <int>[
        199, 236, 211, 224, 196, 234, 181, 218, 182, 254, 188, 190, //
        200, 171, 188, 175, 214, 208, 206, 196, 215, 214, 183, 251, //
        178, 226, 202, 212, 179, 164, 206, 196, 177, 190, 205, 249, //
        183, 181, 209, 233, 214, 164, 193, 247, 192, 203, 181, 216, //
        199, 242, 181, 188, 209, 221, 185, 249, 183, 171, 209, 221, //
        212, 177, 206, 226, 190, 169, 193, 245, 181, 194, 187, 170, //
        191, 198, 187, 195, 181, 231, 211, 176, //
      ];
      final result = gbkDecodeWithReport(bytes);
      expect(result.text, expected);
      expect(result.report.unmapped, 0);
      expect(result.report.mapped, 80);
    });
  });
}
