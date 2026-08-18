import 'package:flutter/material.dart';
import 'package:media_sniffer/media_sniffer.dart';

class SnifferSettingsPage extends StatefulWidget {
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
        title: const Text('Sniffer Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildGeneralSection(),
          const Divider(),
          _buildRulesSection(),
        ],
      ),
    );
  }

  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'General',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Auto Sniff'),
          subtitle: const Text('Automatically detect media on pages'),
          value: _autoSniff,
          onChanged: (value) {
            setState(() {
              _autoSniff = value;
            });
          },
        ),
        SwitchListTile(
          title: const Text('Sniff on Play'),
          subtitle: const Text('Detect media URLs when playing'),
          value: _sniffOnPlay,
          onChanged: (value) {
            setState(() {
              _sniffOnPlay = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sniffing Rules',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              TextButton.icon(
                onPressed: _addRule,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rules.length,
          itemBuilder: (context, index) {
            final rule = _rules[index];
            return _buildRuleTile(rule, index);
          },
        ),
      ],
    );
  }

  Widget _buildRuleTile(SnifferRule rule, int index) {
    return ListTile(
      leading: Icon(
        rule.enabled ? Icons.check_circle : Icons.circle,
        color: rule.enabled ? Colors.green : Colors.grey,
      ),
      title: Text(rule.name),
      subtitle: Text(
        rule.urlPattern,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: rule.enabled,
            onChanged: (value) {
              _toggleRule(index, value);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleRuleAction(action, index),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleRule(int index, bool enabled) {
    setState(() {
      final rule = _rules[index];
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
        break;
      case 'delete':
        _deleteRule(index);
        break;
    }
  }

  void _addRule() {
    _showRuleDialog();
  }

  void _editRule(int index) {
    final rule = _rules[index];
    _showRuleDialog(rule: rule, index: index);
  }

  void _deleteRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
  }

  void _showRuleDialog({SnifferRule? rule, int? index}) {
    final nameController = TextEditingController(text: rule?.name ?? '');
    final patternController = TextEditingController(
      text: rule?.urlPattern ?? '',
    );
    final contentPatternController = TextEditingController(
      text: rule?.contentPattern ?? '',
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rule == null ? 'Add Rule' : 'Edit Rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: patternController,
              decoration: const InputDecoration(
                labelText: 'URL Pattern (RegExp)',
                hintText: r'\.m3u8',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentPatternController,
              decoration: const InputDecoration(
                labelText: 'Content Pattern (Optional)',
                hintText: r'#EXTM3U',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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

                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _rules = List.of(SnifferRule.defaults);
    });
  }
}
