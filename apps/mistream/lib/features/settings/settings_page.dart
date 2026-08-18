/// 设置页面：源管理、诊断、缓存、主题、关于。
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:storage/storage.dart';

import 'package:mistream/app/router.dart' show globalRouterAssembly;
import 'package:mistream/application/app_assembly.dart' show AppAssembly;
import 'package:mistream/features/settings/widgets/settings_section.dart';
import 'package:mistream/features/settings/widgets/settings_tile.dart';

/// 全局装配实例，供设置页使用。
AppAssembly? _globalAssembly;

/// 获取全局装配实例。
AppAssembly? get globalAssembly => _globalAssembly;

/// 设置全局装配实例。
void setGlobalAssembly(AppAssembly? assembly) {
  _globalAssembly = assembly;
}

/// 主题模式设置项：存储 ThemeMode.index (0=system, 1=light, 2=dark)。
final _themeModeKey = SettingKey<int>(
  'theme_mode',
  (json) => (json as num).toInt(),
  (value) => value,
);

/// 设置页面。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  List<Site> _sites = [];
  int _cacheSize = 0;
  int _historyCount = 0;
  int _favoriteCount = 0;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
    unawaited(_loadThemeMode());
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

  Future<void> _loadThemeMode() async {
    final assembly = globalAssembly ?? globalRouterAssembly;
    if (assembly == null) return;
    final themeIndex = await assembly.repositories.settings.read(
      _themeModeKey,
      0,
    );
    if (mounted) {
      setState(() => _themeMode = ThemeMode.values[themeIndex.clamp(0, 2)]);
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

  void _showThemeDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('跟随系统'),
              value: ThemeMode.system,
              groupValue: _themeMode,
              onChanged: (v) => _setThemeMode(v!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('亮色'),
              value: ThemeMode.light,
              groupValue: _themeMode,
              onChanged: (v) => _setThemeMode(v!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('深色'),
              value: ThemeMode.dark,
              groupValue: _themeMode,
              onChanged: (v) => _setThemeMode(v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final assembly = globalAssembly ?? globalRouterAssembly;
    if (assembly == null) return;
    await assembly.repositories.settings.write(_themeModeKey, mode.index);
    setState(() => _themeMode = mode);
    if (mounted) Navigator.pop(context);
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
                      onTap: () => _showDiagnostics(),
                    ),
                    SettingsTile(
                      title: '导出调试包',
                      subtitle: '包含数据库、日志、配置（用于反馈问题）',
                      leading: const Icon(Icons.file_download_outlined),
                      onTap: () => _exportDebugPackage(),
                    ),
                  ],
                ),

                // 外观
                SettingsSection(
                  title: '外观',
                  children: [
                    SettingsTile(
                      title: '主题模式',
                      subtitle: _themeMode == ThemeMode.system
                          ? '跟随系统'
                          : _themeMode == ThemeMode.light
                          ? '亮色'
                          : '深色',
                      leading: const Icon(Icons.palette_outlined),
                      onTap: _showThemeDialog,
                    ),
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
                SettingsSection(
                  title: '关于',
                  children: [
                    SettingsTile(
                      title: '版本',
                      subtitle: '0.1.0 (MVP)',
                      leading: const Icon(Icons.info_outline),
                    ),
                    SettingsTile(
                      title: '开源协议',
                      subtitle: 'MIT License',
                      leading: const Icon(Icons.gavel_outlined),
                    ),
                    SettingsTile(
                      title: '项目地址',
                      subtitle: 'github.com/.../mistream',
                      leading: const Icon(Icons.code_outlined),
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
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
