/// 测试替身，与生产 API 分开导出。
///
/// 单独一个入口而不是并进 `player_engine.dart`：测试替身进了主入口，
/// 生产代码 `import 'package:player_engine/player_engine.dart'` 之后就能顺手
/// `FakePlayerEngine()`，而这种事一旦发生没人会注意到。分开导出让它在 review
/// 时是一行显眼的 import。
library;

export 'package:player_engine/src/testing/fake_player_engine.dart';
