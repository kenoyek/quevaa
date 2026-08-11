import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/notifications/notification_destination_resolver.dart';
import '../../../core/notifications/notification_payload.dart';
import '../application/notification_inbox_provider.dart';
import '../application/notification_preferences_provider.dart';
import '../domain/entities/app_notification.dart';
import '../domain/enums/notification_privacy_mode.dart';

class NotificationCenterPage extends ConsumerWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(notificationInboxProvider);
    final controller = ref.read(notificationInboxControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Notifications'),
        actions: [
          inboxAsync.maybeWhen(
            data: (items) => TextButton(
              onPressed: items.any((item) => item.isUnread)
                  ? controller.markAllRead
                  : null,
              child: const Text('Mark all read'),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => context.push('/notifications/settings'),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: inboxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _NotificationError(
          message: 'We could not load notifications.',
          onRetry: () => ref.invalidate(notificationInboxProvider),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyNotifications();
          final today = <AppNotification>[];
          final earlier = <AppNotification>[];
          final now = DateTime.now();
          for (final item in items) {
            if (_sameDate(item.scheduledFor, now)) {
              today.add(item);
            } else {
              earlier.add(item);
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              if (today.isNotEmpty) ...[
                const _NotificationSectionHeader('Today'),
                for (final item in today) _NotificationTile(item: item),
              ],
              if (earlier.isNotEmpty) ...[
                const _NotificationSectionHeader('Earlier'),
                for (final item in earlier) _NotificationTile(item: item),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider).valueOrNull;
    final body = item.bodyFor(
      preferences?.privacyMode ?? QuevaaNotificationPrivacyMode.discreet,
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final parsedPayload = QuevaaNotificationPayload.tryParse(item.payload);
    final destination = NotificationDestinationResolver.resolve(
      type: parsedPayload?.type,
      route: item.deepLink,
    );
    final date = DateFormat('d MMM, h:mm a').format(item.scheduledFor);

    return Semantics(
      button: true,
      label: item.isUnread
          ? '${item.title}, unread notification'
          : '${item.title}, read notification',
      child: Card(
        elevation: item.isUnread ? 1 : 0,
        color: item.isUnread
            ? (isDark
                  ? AppColors.cardSurfaceDark
                  : Colors.white.withValues(alpha: 0.94))
            : (isDark
                  ? AppColors.cardSurfaceDark.withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: 0.62)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          leading: _CategoryIcon(
            category: item.category,
            unread: item.isUnread,
          ),
          title: Text(
            item.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: item.isUnread ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: item.isUnread ? null : muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  date,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          trailing: item.isUnread
              ? const Icon(
                  Icons.circle,
                  size: 10,
                  color: AppColors.terracottaPrimary,
                )
              : null,
          onTap: () async {
            await ref
                .read(notificationInboxControllerProvider.notifier)
                .markRead(item.id);
            if (context.mounted) context.go(destination);
          },
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category, required this.unread});

  final String category;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final icon = switch (category) {
      'cycle' => Icons.calendar_month_rounded,
      'conception' => Icons.eco_rounded,
      'tasks' => Icons.task_alt_rounded,
      'meals' => Icons.restaurant_rounded,
      'workouts' => Icons.fitness_center_rounded,
      'journal' => Icons.edit_note_rounded,
      _ => Icons.notifications_rounded,
    };
    return CircleAvatar(
      radius: 21,
      backgroundColor: unread
          ? AppColors.terracottaContainer
          : AppColors.sageContainer.withValues(alpha: 0.7),
      child: Icon(
        icon,
        color: unread ? AppColors.terracottaPrimary : AppColors.sagePrimary,
      ),
    );
  }
}

class _NotificationSectionHeader extends StatelessWidget {
  const _NotificationSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 52,
              color: AppColors.sagePrimary,
            ),
            const SizedBox(height: 14),
            Text("You're all caught up.", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'New cycle, meal, movement and planning updates will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.terracottaPrimary,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
