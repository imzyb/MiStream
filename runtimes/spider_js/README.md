# spider_js

QuickJS 运行时子进程 + drpy 宿主 API 兼容层。**项目关键路径。**

**状态**：占位，M4 落地。

接口见 [docs/05-Spider引擎](../../docs/05-Spider引擎.md)，
进程隔离理由见 [ADR-001](../../docs/adr/001-spider-独立子进程.md)。

兼容性测试集（`(HTML 快照, 规则, 期望输出)` 三元组）是本包的一等交付物，
不是附属品——`pdfh` 的语义只能靠对齐真实源行为来确定。
