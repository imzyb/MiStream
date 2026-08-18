/// 统一的状态视图组件：Loading / Empty / Error / Success。
library;

import 'package:flutter/material.dart';

/// 状态视图类型。
enum StateViewType { loading, empty, error }

/// 加载视图。
class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.message,
    this.size = 32,
  });

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 空状态视图。
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 错误视图。
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
            ],
          ],
        ),
      ),
    );
  }
}

/// 成功视图（用于操作完成提示）。
class SuccessView extends StatelessWidget {
  const SuccessView({
    super.key,
    required this.message,
    this.icon = Icons.check_circle_outline,
    this.onDismiss,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onDismiss != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onDismiss, child: const Text('关闭')),
            ],
          ],
        ),
      ),
    );
  }
}

/// 带状态的 Sliver 视图（用于 CustomScrollView）。
class SliverStateView extends StatelessWidget {
  const SliverStateView({
    super.key,
    required this.state,
    this.onRetry,
    this.message,
    this.icon,
  });

  final StateViewType state;
  final VoidCallback? onRetry;
  final String? message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: switch (state) {
          StateViewType.loading => LoadingView(message: message),
          StateViewType.empty => EmptyView(
            icon: icon ?? Icons.inbox_outlined,
            title: message ?? '暂无内容',
          ),
          StateViewType.error => ErrorView(
            message: message ?? '加载失败',
            onRetry: onRetry,
            icon: icon ?? Icons.error_outline,
          ),
        },
      ),
    );
  }
}
