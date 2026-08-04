/// MiStream 桌面客户端的进程入口。
///
/// 这里只负责把根 widget 挂起来。启动流程（配置加载、数据库迁移、插件扫描）
/// 在 M5 落地时作为 [MiStreamApp] 之前的独立 bootstrap 阶段接入，而不是堆进
/// main —— 堆在这里的初始化没办法在 widget 测试里跳过。
library;

import 'package:flutter/widgets.dart';
import 'package:mistream/app/app.dart';

void main() {
  runApp(const MiStreamApp());
}
