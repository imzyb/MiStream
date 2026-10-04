import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

import 'support/plugin_fixture.dart';

/// ROADMAP M9 出口标准：**权限撤销后插件优雅降级，不崩溃**。
///
/// 这条标准的落点有三处，缺一条都不算过：
/// 1. **通知**：撤销运行中插件的权限时，插件**确实收到**通知（不是只改账本）。
/// 2. **不崩溃**：插件处理通知时抛异常，宿主把它**隔离**在返回值里 ——
///    不向上传播、不影响其它插件、不改变插件状态。
/// 3. **调用侧**：撤销后再去调需要该权限的能力，得到的是**可捕获的干净错误**
///    （`PluginPermissionDenied`），而不是插件内部炸出来的异常。
///
/// 另外明确记下**有意不做**的事：宿主不自动停用插件、不把它标成 `error`。
/// 撤销一项权限不等于插件废了，它可能优雅降级（用缓存、用本地数据）。
void main() {
  PluginManifest manifestWith(
    String id, {
    List<PluginPermission> permissions = const [PluginPermission.network],
  }) => PluginManifest(
    id: id,
    name: id,
    version: '1.0.0',
    type: PluginType.source,
    permissions: permissions,
  );

  /// 装一个已启用的插件，返回 (manager, api)。
  Future<(PluginManager, RecordingPluginApi)> installed(
    String id, {
    List<PluginPermission> required = const [PluginPermission.network],
    Map<String, List<PluginPermission>> granted = const {},
  }) async {
    final manifest = manifestWith(id, permissions: required);
    final api = RecordingPluginApi(manifest);
    final manager = PluginManager(permissions: PermissionChecker(granted));
    await manager.install(manifest, api);
    return (manager, api);
  }

  group('撤销运行中的插件：通知到位', () {
    test('已授予的权限被撤销：插件收到通知，且清单只含真正撤掉的那项', () async {
      final (manager, api) = await installed(
        'p',
        granted: {
          'p': [PluginPermission.network, PluginPermission.storage],
        },
      );

      final result = await manager.revokePermissions('p', [
        PluginPermission.network,
        PluginPermission.clipboard, // 本来就没授予
      ]);

      expect(result.outcome, PermissionRevocationOutcome.notified);
      expect(result.revoked, [PluginPermission.network]);
      expect(result.error, isNull);
      // 只通知「真正少了的那项」，不是把请求清单原样转过去
      expect(api.revocations, [
        [PluginPermission.network],
      ]);
    });

    test('账目确实变了：撤销后不再完整授权，缺的项查得出来', () async {
      final (manager, api) = await installed(
        'p',
        required: [PluginPermission.network, PluginPermission.storage],
        granted: {
          'p': [PluginPermission.network, PluginPermission.storage],
        },
      );
      expect(manager.isFullyPermitted('p'), isTrue);

      await manager.revokePermissions('p', [PluginPermission.storage]);

      expect(manager.isFullyPermitted('p'), isFalse);
      expect(
        manager.permissions.getMissingPermissions(api.manifest),
        [PluginPermission.storage],
      );
      expect(
        manager.permissions.getGranted('p'),
        [PluginPermission.network],
      );
    });

    test('撤销后插件仍在运行：状态不变、也没被踢出管理器', () async {
      final (manager, api) = await installed(
        'p',
        granted: {
          'p': [PluginPermission.network],
        },
      );

      await manager.revokePermissions('p', [PluginPermission.network]);

      // 「不崩溃」也包括「不因为撤销就把插件搞成故障态」
      expect(manager.getState('p'), PluginState.enabled);
      expect(manager.getApi('p'), same(api));
      expect(manager.getEnabled().map((m) => m.id), contains('p'));
    });

    test('通知清单是不可变列表：插件改不动宿主的状态', () async {
      final (manager, _) = await installed(
        'p',
        granted: {
          'p': [PluginPermission.network, PluginPermission.storage],
        },
      );

      final result = await manager.revokePermissions('p', [
        PluginPermission.network,
      ]);

      expect(
        () => result.revoked.add(PluginPermission.webview),
        throwsUnsupportedError,
      );
    });

    test('一次撤销多项：全部收到，账目一次清干净', () async {
      final (manager, api) = await installed(
        'p',
        required: [PluginPermission.network, PluginPermission.storage],
        granted: {
          'p': [PluginPermission.network, PluginPermission.storage],
        },
      );

      final result = await manager.revokePermissions('p', [
        PluginPermission.network,
        PluginPermission.storage,
      ]);

      expect(result.outcome, PermissionRevocationOutcome.notified);
      expect(result.revoked, hasLength(2));
      expect(api.revocations.single, hasLength(2));
      expect(manager.permissions.getGranted('p'), isEmpty);
    });
  });

  group('插件处理撤销时抛异常：宿主隔离，不崩溃', () {
    test('异常不向上传播，被装进返回值', () async {
      final (manager, api) = await installed(
        'p',
        granted: {
          'p': [PluginPermission.network],
        },
      );
      api.failRevokeHandler = true;

      // 关键：这里**不能**抛。撤销权限的动作必须总能走完。
      final result = await manager.revokePermissions('p', [
        PluginPermission.network,
      ]);

      expect(result.outcome, PermissionRevocationOutcome.handlerFailed);
      expect(result.error, isA<StateError>());
      expect(result.stackTrace, isNotNull);
      expect(result.revoked, [PluginPermission.network]);
      // 通知发出去了（插件收到了，只是处理失败）
      expect(result.outcome.notifiedPlugin, isTrue);
    });

    test('处理失败不回滚账目 —— 用户点了撤销，权限就不能还在', () async {
      final (manager, api) = await installed(
        'p',
        granted: {
          'p': [PluginPermission.network],
        },
      );
      api.failRevokeHandler = true;

      await manager.revokePermissions('p', [PluginPermission.network]);

      expect(manager.permissions.getGranted('p'), isEmpty);
      expect(manager.isFullyPermitted('p'), isFalse);
    });

    test('处理失败不改插件状态，也不影响其它插件', () async {
      final (manager, bad) = await installed(
        'bad',
        granted: {
          'bad': [PluginPermission.network],
        },
      );
      final goodManifest = manifestWith('good');
      final goodApi = RecordingPluginApi(goodManifest);
      await manager.install(goodManifest, goodApi);

      bad.failRevokeHandler = true;
      await manager.revokePermissions('bad', [PluginPermission.network]);

      expect(manager.getState('bad'), PluginState.enabled);
      expect(manager.getState('good'), PluginState.enabled);
      expect(manager.getEnabled(), hasLength(2));
      expect(goodApi.revocations, isEmpty);
    });
  });

  group('不需要通知的情形：只改账，不发通知', () {
    test('插件已停用：撤销成功但不通知（下次启用会重新读账本）', () async {
      final (manager, api) = await installed(
        'p',
        granted: {
          'p': [PluginPermission.network],
        },
      );
      await manager.disable('p');

      final result = await manager.revokePermissions('p', [
        PluginPermission.network,
      ]);

      expect(result.outcome, PermissionRevocationOutcome.notRunning);
      expect(result.revoked, [PluginPermission.network]);
      expect(api.revocations, isEmpty);
      expect(manager.permissions.getGranted('p'), isEmpty);
    });

    test('插件处于激活失败态：同样不通知，账照改', () async {
      final manifest = manifestWith('p');
      final api = RecordingPluginApi(manifest, failActivate: true);
      final manager = PluginManager(
        permissions: PermissionChecker({
          'p': [PluginPermission.network],
        }),
      );
      await expectLater(manager.install(manifest, api), throwsStateError);
      expect(manager.getState('p'), PluginState.error);

      final result = await manager.revokePermissions('p', [
        PluginPermission.network,
      ]);

      expect(result.outcome, PermissionRevocationOutcome.notRunning);
      expect(api.revocations, isEmpty);
      expect(manager.permissions.getGranted('p'), isEmpty);
    });

    test('撤销本来就没授予的权限：幂等，账目未变也不通知', () async {
      final (manager, api) = await installed('p', granted: const {});

      final result = await manager.revokePermissions('p', [
        PluginPermission.network,
      ]);

      expect(result.outcome, PermissionRevocationOutcome.notGranted);
      expect(result.revoked, isEmpty);
      expect(result.outcome.changedAccount, isFalse);
      expect(api.revocations, isEmpty);
    });

    test('插件未安装：什么都不做', () async {
      final manager = PluginManager();

      final result = await manager.revokePermissions('nope', [
        PluginPermission.network,
      ]);

      expect(result.outcome, PermissionRevocationOutcome.notInstalled);
      expect(result.revoked, isEmpty);
      expect(result.outcome.changedAccount, isFalse);
    });
  });

  group('撤销全部权限', () {
    test('账本里的全部权限被撤掉并通知插件', () async {
      final (manager, api) = await installed(
        'p',
        required: [
          PluginPermission.network,
          PluginPermission.storage,
          PluginPermission.clipboard,
        ],
        granted: {
          'p': [PluginPermission.network, PluginPermission.storage],
        },
      );

      final result = await manager.revokeAllPermissions('p');

      expect(result.outcome, PermissionRevocationOutcome.notified);
      expect(result.revoked, hasLength(2));
      expect(api.revocations.single, hasLength(2));
      expect(manager.permissions.getGranted('p'), isEmpty);
    });

    test('未安装的插件撤销全部：notInstalled', () async {
      final manager = PluginManager();
      final result = await manager.revokeAllPermissions('nope');
      expect(result.outcome, PermissionRevocationOutcome.notInstalled);
    });
  });

  group('调用侧闸门：撤销后给的是干净错误，不是内部异常', () {
    test('权限齐备时闸门放行并返回结果', () async {
      final (manager, _) = await installed(
        'p',
        granted: {
          'p': [PluginPermission.network],
        },
      );

      final value = await manager.requirePermission(
        'p',
        PluginPermission.network,
        () async => 'ok',
      );

      expect(value, 'ok');
    });

    test('缺权限时抛 PluginPermissionDenied，且 body 一次都没执行', () async {
      final (manager, _) = await installed('p', granted: const {});
      var called = 0;

      await expectLater(
        manager.requirePermission('p', PluginPermission.network, () async {
          called++;
          return 'never';
        }),
        throwsA(
          isA<PluginPermissionDenied>()
              .having((e) => e.pluginId, 'pluginId', 'p')
              .having(
                (e) => e.permission,
                'permission',
                PluginPermission.network,
              ),
        ),
      );
      expect(called, 0);
    });

    test('撤销之后同一调用变成干净错误 —— 这就是「降级不崩溃」', () async {
      final (manager, _) = await installed(
        'p',
        granted: {
          'p': [PluginPermission.network],
        },
      );

      // 撤销前：正常
      expect(
        await manager.requirePermission(
          'p',
          PluginPermission.network,
          () async => 'ok',
        ),
        'ok',
      );

      await manager.revokePermissions('p', [PluginPermission.network]);

      // 撤销后：明确、可捕获的错误，而不是让插件内部炸
      await expectLater(
        manager.requirePermission(
          'p',
          PluginPermission.network,
          () async => 'ok',
        ),
        throwsA(isA<PluginPermissionDenied>()),
      );
    });
  });

  group('账本 API 的返回值语义（通知决策的依据）', () {
    test('revoke 返回账目是否真的变了', () {
      final checker = PermissionChecker({
        'p': [PluginPermission.network],
      });

      expect(checker.revoke('p', PluginPermission.network), isTrue);
      // 第二次是幂等的「没变」，不是错误
      expect(checker.revoke('p', PluginPermission.network), isFalse);
      expect(checker.revoke('nope', PluginPermission.network), isFalse);
    });

    test('revokeAll 返回被撤掉的清单', () {
      final checker = PermissionChecker({
        'p': [PluginPermission.network, PluginPermission.storage],
      });

      expect(
        checker.revokeAll('p'),
        containsAll([PluginPermission.network, PluginPermission.storage]),
      );
      expect(checker.getGranted('p'), isEmpty);
      // 已经空了再撤一次：空列表，不是异常
      expect(checker.revokeAll('p'), isEmpty);
    });
  });

  group('isFullyPermitted', () {
    test('未安装返回 false', () {
      expect(PluginManager().isFullyPermitted('nope'), isFalse);
    });

    test('声明了权限但未授予：安装后即为降级运行', () async {
      final (manager, _) = await installed(
        'p',
        required: [PluginPermission.network],
        granted: const {},
      );

      expect(manager.isFullyPermitted('p'), isFalse);
    });

    test('无权限声明的插件恒为完整可用', () async {
      final manifest = manifestWith('p', permissions: const []);
      final manager = PluginManager();
      await manager.install(manifest, RecordingPluginApi(manifest));

      expect(manager.isFullyPermitted('p'), isTrue);
    });
  });
}
