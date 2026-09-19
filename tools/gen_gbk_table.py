"""离线生成 GBK 码表 Dart 源文件。

用途：`runtimes/spider_js/lib/src/drpy/gbk_table.dart`。

之所以用 Python 而不是 Dart 生成：Python 内置 `gbk` codec 基于 CPython 的
稳定映射表，与浏览器 / 服务端处理 GBK 的权威来源一致；Dart SDK 没有内置
GBK codec，靠第三方包会引入新的依赖与版本约束。生成物一次性入库，之后
不再需要 Python。

用法：
    python tools/gen_gbk_table.py

改动码表只在需要跟进 GB18030 扩展区时才发生。生成后请跑
`dart test runtimes/spider_js` 确认 gbk_test.dart 全绿。
"""

from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / (
    'runtimes/spider_js/lib/src/drpy/gbk_table.dart'
)

LEAD_MIN, LEAD_MAX = 0x81, 0xFE
TRAIL_MIN, TRAIL_MAX = 0x40, 0xFE
UNMAPPED = '\uFFFD'

HEADER = '''/// GBK / GB18030 双字节码表。
///
/// 由 `tools/gen_gbk_table.py` 离线生成，**不可手工编辑**。重新生成：
///
/// ```sh
/// python tools/gen_gbk_table.py
/// ```
///
/// ## 为什么是紧凑字符串而不是 Map
///
/// 码表共 23940 个双字节位置（`0x8140` ~ `0xFEFE`，跳过 `??7F`），逐条写成
/// `Map<int, String>` 会产生 2.4 万行常量，编译期与包体积都不划算。这里把
/// 字符按 (首字节, 尾字节) 字典序拼成单个字符串，解码时按线性下标查表——
/// 查表退化成一次 `String.codeUnitAt`，比哈希更快。
///
/// 之所以不按区间压缩：GBK 继承 GB2312 的区位排列，码位顺序是「拼音 + 部首」
/// 而非 Unicode 码点序，实测把 21791 个映射压成「基址 + 偏移」仍需 1 万余段，
/// 反而不如线性表直观。
///
/// ## 空洞
///
/// 该编码空间内有 {holes} 个未定义位置，用 U+FFFD 占位以保持下标算术成立。
/// 解码遇到占位符按「无法映射」处理，见 `gbk.dart`。
library;

/// 双字节区首字节下限（含）。
const int gbkLeadMin = 0x{lead_min:02X};

/// 双字节区首字节上限（含）。
const int gbkLeadMax = 0x{lead_max:02X};

/// 双字节区尾字节下限（含）。
const int gbkTrailMin = 0x{trail_min:02X};

/// 双字节区尾字节上限（含）。
const int gbkTrailMax = 0x{trail_max:02X};

/// 未映射位置占位符。
const String gbkUnmapped = '\\uFFFD';

/// 每行（同一首字节）的有效尾字节个数：`0x40` ~ `0xFE` 去掉 `0x7F`。
const int gbkRowWidth = {row_width};

/// 按 (首字节, 尾字节) 字典序排列的映射表。
///
/// 下标 = `(首字节 - gbkLeadMin) * gbkRowWidth + (尾字节 - 尾部起始)`，
/// 其中 `尾字节 >= 0x80` 时需再减 1（跳过 `0x7F`）。
const String gbkTable =
'''


def build_row_offset_table():
    """生成尾字节 → 行内列下标的查找表常量。"""
    cols = []
    for b2 in range(TRAIL_MIN, TRAIL_MAX + 1):
        if b2 == 0x7F:
            continue
        cols.append(b2 - TRAIL_MIN)
    return cols


def main():
    chars = []
    holes = 0
    for b1 in range(LEAD_MIN, LEAD_MAX + 1):
        for b2 in range(TRAIL_MIN, TRAIL_MAX + 1):
            if b2 == 0x7F:
                continue
            try:
                chars.append(bytes([b1, b2]).decode('gbk'))
            except UnicodeDecodeError:
                chars.append(UNMAPPED)
                holes += 1

    row_width = TRAIL_MAX - TRAIL_MIN + 1 - 1
    header = HEADER.format(
        holes=holes,
        lead_min=LEAD_MIN,
        lead_max=LEAD_MAX,
        trail_min=TRAIL_MIN,
        trail_max=TRAIL_MAX,
        row_width=row_width,
    )

    chunks = [chars[i:i + 100] for i in range(0, len(chars), 100)]
    body = "''\n" + "\n".join("    '" + ''.join(c) + "'" for c in chunks) + ';\n'

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(header + body, encoding='utf-8')

    print(f'写出 {OUT}')
    print(f'  映射数 {len(chars)}，空洞 {holes}，行宽 {row_width}')
    print(f'  文件大小 {OUT.stat().st_size} 字节')


if __name__ == '__main__':
    main()
