import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/notification_inbox_provider.dart';

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key, this.iconColor, this.onPressed});

  final Color? iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final badgeText = unread > 99 ? '99+' : '$unread';
    final label = unread == 0
        ? 'Notifications, no unread'
        : 'Notifications, $unread unread';

    return Semantics(
      label: label,
      button: true,
      child: Tooltip(
        message: unread == 0 ? 'Notifications' : '$unread unread',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap:
                onPressed ?? () => GoRouter.of(context).push('/notifications'),
            child: SizedBox.square(
              dimension: 56,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 26,
                    color: iconColor,
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: ExcludeSemantics(
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: AppColors.terracottaPrimary,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
