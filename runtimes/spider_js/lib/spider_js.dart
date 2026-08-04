/// QuickJS 运行时子进程与 drpy 宿主 API 兼容层。
///
/// **本运行时在 M4 落地**，当前只占位。**它是整个项目的关键路径**——
/// ROADMAP 里写明「任何资源都应优先保障它」。
///
/// 计划中的内容（见 `docs/05-Spider引擎.md` §2 与 ROADMAP M4）：
///
/// - QuickJS 嵌入，每个源一个独立 Context
/// - 资源限制：interrupt 超时、内存上限、栈深度
/// - drpy 宿主 API：`req` / `pdfh` / `pdfa` / `pd` / `pdfl` / `local.*` /
///   编码（base64、gbk、urlencode、md5、sha1、sha256）/ 加密（aes、rsa、hmac）
/// - type=0（XPath/CSP 网页解析）的内置通用脚本
///
/// 最大的不确定性在 `pdfh`：它的伪 XPath 语法（`a&&href`、`.class&&Text`）
/// 既不是标准 XPath 也不是标准 CSS，**没有权威规范**，只能对齐真实源的实际
/// 行为。对策是把兼容性测试集当作一等交付物——每报告一个源不兼容就补一条
/// 用例，只增不减。
///
/// 脚本执行的是**用户导入的、不受信任的第三方代码**，因此必须假设它会死循环、
/// 爆内存、崩溃、越权。这是它跑在独立子进程里的全部理由（[ADR-001]）。
///
/// [ADR-001]: ../../docs/adr/001-spider-独立子进程.md
library;
