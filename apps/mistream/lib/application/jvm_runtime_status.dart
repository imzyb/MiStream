/// JVM 运行时（实验性可选组件）的可用性快照与安装引导。
///
/// 为什么需要这个类：站点在界面上只表现为「不可用」，但不可用有**三种互不相同**
/// 的成因，修法也各不相同 ——
///
///   1. **没装 JRE** —— 用户自己装 JRE 17+。ADR-006 明确要求用户自装，
///      MiStream 不随包分发 JRE（体积 +150MB 以上，已否决）
///   2. **运行时不随包** —— 装到的是残缺的包，要换完整包
///   3. **缺 Python3** —— dex→jar 转换器（enjarify）跑不起来
///
/// 把这三件事压成一个 bool 交给 UI，等于让用户去猜。ADR-006 的「后果」一节明确
/// 要求「运行时缺失时源灰显 **+ 安装引导**，否则用户只会看到一堆报错的源」——
/// 这个类就是那句引导的数据来源。
library;

/// JVM 运行时的可用性快照。
///
/// 纯数据，不含任何 IO：解析由 `AppAssembly` 完成，这里只负责把结果整理成
/// 「缺什么、该怎么办」。
class JvmRuntimeStatus {
  /// 构造快照。
  const JvmRuntimeStatus({
    required this.javaPath,
    required this.pythonPath,
    required this.runtimeDirPath,
  });

  /// `java` 可执行文件的绝对路径；未找到为 `null`。
  final String? javaPath;

  /// Python3 可执行文件的绝对路径；未找到为 `null`。
  ///
  /// dex→jar 转换（enjarify）需要它。这里**只判断「有没有解释器」**：是否装了
  /// `enjarify-adapter` 得真跑一次才知道，本快照不下这个结论，避免给出
  /// 「Python 就绪」的假保证。
  final String? pythonPath;

  /// 实际命中的 `runtimes/spider_jvm/` 目录；未找到为 `null`。
  final String? runtimeDirPath;

  /// 是否找到了 JRE。
  bool get hasJava => javaPath != null;

  /// 是否找到了随包的运行时（jar + libs）。
  bool get hasRuntime => runtimeDirPath != null;

  /// 是否找到了 Python3。
  bool get hasPython => pythonPath != null;

  /// jar 源当前能否工作。
  ///
  /// 只看前两项：缺 Python 只影响需要 dex 转换的 jar，不影响纯 Java 字节码的
  /// jar，所以它不进这个判据（会误报「全不可用」）。
  bool get available => hasJava && hasRuntime;

  /// 缺失项清单（面向用户的中文短句）；全部就绪时为空。
  List<String> get missingItems => [
    if (!hasJava) '未找到 Java —— 需自行安装 JRE 17+ 并加入 PATH',
    if (!hasRuntime) '缺少 MiStream 的 JVM 运行时（runtimes/spider_jvm）—— 当前装包不完整',
    if (!hasPython) '未找到 Python3 —— 部分 jar 源的字节码转换需要它',
  ];

  /// 横幅标题。
  String get headline => available ? 'JVM 运行时可用' : 'JVM 运行时未就绪（实验性可选组件）';

  /// 说明文案：可用时讲清能力边界，不可用时逐条列出缺什么。
  ///
  /// 「可用」时也要给文案，是因为 ADR-006 要求 jar 源始终带
  /// 「实验性 · 二进制不可审计」的定性 —— 能用不等于承诺任意 jar 都能跑。
  String get detail {
    if (available) {
      return '仅支持「纯 Java 逻辑 + 已 shim 的 android API 子集」，不承诺任意 jar 可用。';
    }
    return missingItems.join('\n');
  }
}
