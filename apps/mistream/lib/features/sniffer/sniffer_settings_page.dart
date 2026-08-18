/// 嗅探设置页：通用开关 + 规则管理。
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:media_sniffer/media_sniffer.dart';

import 'package:mistream/features/common/common.dart' show EmptyView;

/// 嗅探设置页。
///
/// 管理嗅探引擎的通用开关（自动嗅探、播放时嗅探）与规则列表
/// （正则匹配媒体地址，见 `packages/media_sniffer`）。
class SnifferSettingsPage extends StatefulWidget {
  /// 构造嗅探设置页。
  const SnifferSettingsPage({super.key});

  @override
  State<SnifferSettingsPage> createState() => _SnifferSettingsPageState();
}

class _SnifferSettingsPageState extends State<SnifferSettingsPage> {
  final SnifferEngine _engine = SnifferEngine();
  List<SnifferRule> _rules = [];
  bool _autoSniff = true;
  bool _sniffOnPlay = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    setState(() {
      _rules = List.from(_engine.rules);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('嗅探设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: '恢复默认规则',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildSectionTitle('通用'),
          SwitchListTile(
            title: const Text('自动嗅探'),
            subtitle: const Text('浏览页面时自动识别媒体地址'),
            value: _autoSniff,
            onChanged: (value) => setState(() => _autoSniff = value),
          ),
          SwitchListTile(
            title: const Text('播放时嗅探'),
            subtitle: const Text('起播失败时自动嗅探可播放地址'),
            value: _sniffOnPlay,
            onChanged: (value) => setState(() => _sniffOnPlay = value),
          ),
          const Divider(),
          _buildSectionTitle(
            '嗅探规则',
            action: TextButton.icon(
              onPressed: _addRule,
              icon: const Icon(Icons.add),
              label: const Text('新增规则'),
            ),
          ),
          if (_rules.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: EmptyView(
                icon: Icons.rule_outlined,
                title: '暂无规则',
                subtitle: '点击「新增规则」添加自定义嗅探规则',
              ),
            )
          else
            for (final (index, rule) in _rules.indexed)
              _buildRuleTile(rule, index),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Widget _buildRuleTile(SnifferRule rule, int index) {
    return ListTile(
      leading: Icon(
        rule.enabled ? Icons.check_circle : Icons.radio_button_unchecked,
        color: rule.enabled ? Colors.green : Colors.grey,
      ),
      title: Text(rule.name),
      subtitle: Text(
        rule.urlPattern,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: rule.enabled,
            onChanged: (value) => _toggleRule(index, value),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleRuleAction(action, index),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('编辑'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleRule(int index, bool enabled) {
    final rule = _rules[index];
    setState(() {
      _rules[index] = SnifferRule(
        name: rule.name,
        urlPattern: rule.urlPattern,
        contentPattern: rule.contentPattern,
        headers: rule.headers,
        enabled: enabled,
        priority: rule.priority,
      );
    });
  }

  void _handleRuleAction(String action, int index) {
    switch (action) {
      case 'edit':
        _editRule(index);
      case 'delete':
        unawaited(_deleteRule(index));
    }
  }

  void _addRule() {
    _showRuleDialog();
  }

  void _editRule(int index) {
    final rule = _rules[index];
    _showRuleDialog(rule: rule, index: index);
  }

  Future<void> _deleteRule(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定要删除规则「${_rules[index].name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _rules.removeAt(index));
  }

  void _showRuleDialog({SnifferRule? rule, int? index}) {
    final nameController = TextEditingController(text: rule?.name ?? '');
    final patternController = TextEditingController(
      text: rule?.urlPattern ?? '',
    );
    final contentPatternController = TextEditingController(
      text: rule?.contentPattern ?? '',
    );

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(rule == null ? '新增规则' : '编辑规则'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: rule == null,
                decoration: const InputDecoration(
                  labelText: '规则名称',
                  hintText: '例如 HLS 直链',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'URL 匹配 (正则)',
                  hintText: r'\.m3u8',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentPatternController,
                decoration: const InputDecoration(
                  labelText: '内容匹配 (可选)',
                  hintText: '#EXTM3U',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    patternController.text.isNotEmpty) {
                  final newRule = SnifferRule(
                    name: nameController.text,
                    urlPattern: patternController.text,
                    contentPattern: contentPatternController.text.isNotEmpty
                        ? contentPatternController.text
                        : null,
                    enabled: rule?.enabled ?? true,
                    priority: rule?.priority ?? 100,
                  );

                  setState(() {
                    if (index != null) {
                      _rules[index] = newRule;
                    } else {
                      _rules.add(newRule);
                    }
                  });

                  Navigator.pop(ctx);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认规则'),
        content: const Text('将用内置默认规则替换当前所有规则，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _rules = List.of(SnifferRule.defaults);
    });
  }
}
