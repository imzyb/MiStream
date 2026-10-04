/// 一个持有当前值的多订阅广播流。
///
/// 订阅时先补发当前值，再接后续变化——这正是 `PlayerEngine` 文档里钉死的流
/// 语义（`docs/04-播放器设计.md` §3.2：迟到的订阅者立即收到当前值）。用
/// `Stream.multi` 而不是 `StreamController.broadcast`：后者对迟到的订阅者不会
/// 补发任何东西，而播放页的组件本来就是陆续挂载的。
///
/// 在 `FakePlayerEngine` 与 `MediaKitEngine` 之间共享：两处都需要同一种
/// 「快照 + 广播」语义，各写一份会在将来换实现时发现两者的行为漂移。
library;

import 'dart:async';

/// 一个持有当前值的广播流。
///
/// 泛型参数 `T` 的相等性由调用方决定：需要「值变化才推送」时用
/// [emitIfChanged]，否则用 [emit] 无条件推送。
final class ValueStream<T> {
  /// 以 [initial] 作为初值构造一条流。
  ValueStream(T initial) : _value = initial;

  final StreamController<T> _controller = StreamController<T>.broadcast();
  T _value;
  var _closed = false;

  /// 当前值。
  T get value => _value;

  /// 无条件推送，即便值没变。
  void emit(T next) {
    if (_closed) return;
    _value = next;
    _controller.add(next);
  }

  /// 值变化时才推送。
  void emitIfChanged(T next) {
    if (_value == next) return;
    emit(next);
  }

  /// 可多路订阅的广播流，迟到订阅者先收到当前值。
  Stream<T> get stream => Stream<T>.multi((controller) {
    controller.add(_value);
    if (_closed) {
      unawaited(controller.close());
      return;
    }
    final subscription = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);

  /// 关闭流。幂等。
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _controller.close();
  }
}
