/// 设置页面：源管理、诊断、缓存、主题、关于。
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mistream/app/motion_controller.dart';
import 'package:mistream/app/router.dart' show globalRouterAssembly;
import 'package:mistream/app/theme_controller.dart';
import 'package:mistream/application/app_assembly.dart' show AppAssembly;
import 'package:mistream/features/settings/widgets/settings_section.dart';
import 'package:mistream/features/settings/widgets/settings_tile.dart';
import 'package:storage/storage.dart'; // ignore: layering -- 临时直连存储，M10后迁至 Application 层
import 'package:theme_engine/theme_engine.dart';

/// 全局装配实例，供设置页使用。
AppAssembly? _globalAssembly;

/// 获取全局装配实例。
AppAssembly? get globalAssembly => _globalAssembly;

/// 设置全局装配实例。
void setGlobalAssembly(AppAssembly? assembly) {
  _globalAssembly = assembly;
}

/// 设置页面。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  List<Site> _sites = [];
  List<ConfigSource> _sources = [];
  int _cacheSize = 0;
  int _historyCount = 0;
  int _favoriteCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    final assembly = globalAssembly ?? globalRouterAssembly;
    if (assembly == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final sites = await assembly.repositories.sites.enabled(
        searchable: false,
      );
      final sources = await assembly.repositories.configSources.all();
      final cacheSize = await _getCacheSize(assembly.database);
      final historyCount = await assembly.repositories.histories
          .recent(limit: 1000)
          .then((l) => l.length);
      final favoriteCount = await assembly.repositories.favorites
          .byFolder('')
          .then((l) => l.length);

      if (mounted) {
        setState(() {
          _sites = sites;
          _sources = sources;
          _cacheSize = cacheSize;
          _historyCount = historyCount;
          _favoriteCount = favoriteCount;
          _loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('加载失败: $e');
      }
    }
  }

  Future<int> _getCacheSize(AppDatabase db) async {
    try {
      final row = await db
          .customSelect(
            'SELECT COALESCE(SUM(bytes), 0) AS total FROM site_cache',
          )
          .getSingle();
      return (row.data['total'] as num).toInt();
    } catch (_) {
      return 0;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有源数据缓存吗？这不会删除收藏和历史。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final assembly = globalAssembly ?? globalRouterAssembly;
      if (assembly == null) return;
      await assembly.database.delete(assembly.database.siteCaches).go();

      setState(() => _cacheSize = 0);
      _showError('缓存已清除');
    } on Object catch (e) {
      _showError('清除失败: $e');
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除历史'),
        content: const Text('确定要清除所有播放历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final assembly = globalAssembly ?? globalRouterAssembly;
      if (assembly == null) return;
      await assembly.repositories.histories.clear();

      setState(() => _historyCount = 0);
      _showError('历史已清除');
    } on Object catch (e) {
      _showError('清除失败: $e');
    }
  }

  Future<void> _toggleSite(Site site) async {
    final assembly = globalAssembly ?? globalRouterAssembly;
    if (assembly == null) return;
    try {
      await assembly.repositories.sites.updateStatus(
        site.id,
        status: site.enabled ? 'disabled' : 'enabled',
      );

      unawaited(_loadData());
    } on Object catch (e) {
      _showError('切换失败: $e');
    }
  }

  Future<void> _showAddSubscription({bool replace = false}) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(replace ? '更换订阅' : '添加订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'https://example.com/config.json',
                labelText: '订阅 URL',
              ),
              autofocus: true,
            ),
            if (replace)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '将清空现有站点并导入新订阅',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(replace ? '更换' : '添加'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    final assembly = globalAssembly ?? globalRouterAssembly;
    if (assembly == null) return;
    // 简单校验
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _showError('URL 格式不正确');
      return;
    }
    _showError(replace ? '正在更换订阅...' : '正在添加订阅...');
    final result = await assembly.configInstaller.installFromUrl(
      url,
      replace: replace,
    );
    result.fold(
      (count) {
        _showError('成功导入 $count 个站点');
        unawaited(_loadData());
      },
      (err) => _showError('导入失败: ${err.message}'),
    );
  }

  Future<void> _refreshSubscription() async {
    if (_sources.isEmpty) return;
    final assembly = globalAssembly ?? globalRouterAssembly;
    if (assembly == null) return;
    final url = _sources.first.url;
    if (url == null || url.isEmpty) {
      _showError('当前订阅无 URL，无法刷新');
      return;
    }
    _showError('正在刷新订阅...');
    final result = await assembly.configInstaller.installFromUrl(
      url,
      replace: true,
    );
    result.fold(
      (count) {
        _showError('刷新成功 $count 个站点');
        unawaited(_loadData());
      },
      (err) => _showError('刷新失败: ${err.message}'),
    );
  }

  void _showThemeDialog() {
    final controller = ThemeScope.read(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ValueListenableBuilder<AppThemeChoice>(
        valueListenable: controller,
        builder: (dialogContext, current, _) => AlertDialog(
          title: const Text('外观'),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: RadioGroup<AppThemeChoice>(
            groupValue: current,
            onChanged: (v) => unawaited(_setTheme(v!)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final choice in AppThemeChoice.values)
                  RadioListTile<AppThemeChoice>(
                    title: Text(choice.label),
                    subtitle: Text(choice.description),
                    value: choice,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换外观。
  ///
  /// 只写控制器：它落库 + 通知树根重建主题。这里不再自己 setState，也不再
  /// 关对话框——对话框里的单选项跟着控制器重建，用户能连点几下对比效果，
  /// 看完自己关掉。
  Future<void> _setTheme(AppThemeChoice choice) async {
    await ThemeScope.read(context).set(choice);
  }

  /// 「减少动效」开关。
  ///
  /// docs/09-UI规范.md §2.4：开关开启后所有动效降为 0ms，同时也要响应系统的
  /// 无障碍设置。**这里只管用户开关**，与系统的合成在树根做（只有那里够得到
  /// `MediaQuery`），所以副标题要提醒用户「系统那边也可能已经在生效」。
  ///
  /// 和外观一样只写控制器：改动它要重建整棵树的 `MediaQuery`，自己 setState
  /// 只会让这一页的开关看起来变了。
  Widget _motionTile(BuildContext context) {
    final controller = MotionScope.of(context);
    final on = controller.value;

    return SettingsTile(
      title: '减少动效',
      subtitle: on ? '已关闭全部动效' : '打开后动效降为 0ms；系统无障碍设置同样生效',
      leading: const Icon(Icons.animation),
      trailing: Switch(
        value: on,
        onChanged: (value) => unawaited(controller.set(value)),
      ),
      onTap: () => unawaited(controller.set(!on)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 订阅
                SettingsSection(
                  title: '订阅',
                  subtitle: _sources.isEmpty
                      ? '未设置订阅'
                      : '${_sources.length} 个订阅 · ${_sites.length} 个站点',
                  children: [
                    if (_sources.isEmpty)
                      const SettingsTile(
                        title: '暂无订阅',
                        subtitle: '添加订阅 URL 以获取站点',
                        leading: Icon(Icons.link_off_outlined),
                      )
                    else
                      ..._sources.map(
                        (s) => SettingsTile(
                          title: s.name,
                          subtitle: s.url ?? '本地导入',
                          leading: const Icon(Icons.link_outlined),
                        ),
                      ),
                    SettingsTile(
                      title: '添加订阅',
                      subtitle: '输入 TVBox 配置 URL',
                      leading: const Icon(Icons.add_link_outlined),
                      onTap: _showAddSubscription,
                    ),
                    SettingsTile(
                      title: '更换订阅',
                      subtitle: '输入新 URL 并替换现有站点',
                      leading: const Icon(Icons.swap_horiz_outlined),
                      onTap: () => _showAddSubscription(replace: true),
                    ),
                    SettingsTile(
                      title: '刷新订阅',
                      subtitle: '重新拉取当前订阅',
                      leading: const Icon(Icons.refresh_outlined),
                      onTap: _sources.isEmpty ? null : _refreshSubscription,
                    ),
                  ],
                ),

                // 源管理
                SettingsSection(
                  title: '源管理',
                  subtitle:
                      '已启用 ${_sites.where((s) => s.enabled).length} / ${_sites.length} 个',
                  children: [
                    if (_sites.isEmpty)
                      const SettingsTile(
                        title: '暂无数据源',
                        subtitle: '请在引导页导入配置或前往设置添加',
                        leading: Icon(Icons.source_outlined),
                      )
                    else
                      ..._sites.map(
                        (site) => SettingsTile(
                          title: site.name,
                          subtitle: '${site.api} · 优先级 ${site.priority}',
                          leading: Icon(
                            site.enabled
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: site.enabled
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          trailing: Switch(
                            value: site.enabled,
                            onChanged: (_) => _toggleSite(site),
                          ),
                          onTap: () => _toggleSite(site),
                        ),
                      ),
                    SettingsTile(
                      title: '重新导入配置',
                      subtitle: '清除当前所有数据源',
                      leading: const Icon(Icons.download_outlined),
                      onTap: () => context.pushNamed('onboarding'),
                    ),
                  ],
                ),

                // 存储与缓存
                SettingsSection(
                  title: '存储与缓存',
                  children: [
                    SettingsTile(
                      title: '源数据缓存',
                      subtitle: _formatBytes(_cacheSize),
                      leading: const Icon(Icons.storage_outlined),
                      trailing: TextButton(
                        onPressed: _cacheSize > 0 ? _clearCache : null,
                        child: const Text('清除'),
                      ),
                    ),
                    SettingsTile(
                      title: '播放历史',
                      subtitle: '$_historyCount 条记录',
                      leading: const Icon(Icons.history_outlined),
                      trailing: TextButton(
                        onPressed: _historyCount > 0 ? _clearHistory : null,
                        child: const Text('清除'),
                      ),
                    ),
                    SettingsTile(
                      title: '收藏',
                      subtitle: '$_favoriteCount 个项目',
                      leading: const Icon(Icons.favorite_outline),
                      onTap: () => context.pushNamed('library'),
                    ),
                  ],
                ),

                // 诊断
                SettingsSection(
                  title: '诊断',
                  children: [
                    SettingsTile(
                      title: '查看诊断日志',
                      subtitle: '应用事件、错误、性能数据',
                      leading: const Icon(Icons.bug_report_outlined),
                      onTap: _showDiagnostics,
                    ),
                    SettingsTile(
                      title: '导出调试包',
                      subtitle: '包含数据库、日志、配置（用于反馈问题）',
                      leading: const Icon(Icons.file_download_outlined),
                      onTap: _exportDebugPackage,
                    ),
                  ],
                ),

                // 外观
                SettingsSection(
                  title: '外观',
                  children: [
                    SettingsTile(
                      title: '外观',
                      subtitle: ThemeScope.of(context).value.label,
                      leading: const Icon(Icons.palette_outlined),
                      onTap: _showThemeDialog,
                    ),
                    _motionTile(context),
                  ],
                ),

                // 嗅探
                SettingsSection(
                  title: '嗅探',
                  children: [
                    SettingsTile(
                      title: '嗅探设置',
                      subtitle: '管理嗅探规则和行为',
                      leading: const Icon(Icons.search),
                      onTap: () => context.pushNamed('sniffer_settings'),
                    ),
                  ],
                ),

                // 关于
                const SettingsSection(
                  title: '关于',
                  children: [
                    SettingsTile(
                      title: '版本',
                      subtitle: '0.1.0 (MVP)',
                      leading: Icon(Icons.info_outline),
                    ),
                    SettingsTile(
                      title: '开源协议',
                      subtitle: 'MIT License',
                      leading: Icon(Icons.gavel_outlined),
                    ),
                    SettingsTile(
                      title: '项目地址',
                      subtitle: 'github.com/.../mistream',
                      leading: Icon(Icons.code_outlined),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _showDiagnostics() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('诊断日志', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    const Text('最近事件将在此显示（需接入 AppEvents 模块）'),
                    const SizedBox(height: 8),
                    Text(
                      '缓存大小: ${_formatBytes(_cacheSize)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '历史条数: $_historyCount',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '收藏条数: $_favoriteCount',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '数据源数量: ${_sites.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportDebugPackage() {
    _showError('导出功能待实现（需接入 BackupExporter）');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
