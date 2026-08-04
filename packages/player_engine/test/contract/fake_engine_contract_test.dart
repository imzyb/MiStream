import 'package:player_engine/player_engine.dart';
import 'package:player_engine/testing.dart';

import 'player_engine_contract.dart';

void main() {
  runPlayerEngineContract(
    label: 'FakePlayerEngine',
    createEngine: FakePlayerEngine.new,
    createSource: () =>
        MediaSource(uri: Uri.parse('https://example.com/video.mp4')),
  );
}
