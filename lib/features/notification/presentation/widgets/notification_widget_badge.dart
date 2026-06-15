import 'package:flutter/material.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/notification/data/services/notification_service.dart';
 
class NotificationBadge extends StatelessWidget {
  final String uid;
  final Widget child;
  final double top;
  final double right;
 
  const NotificationBadge({
    super.key,
    required this.uid,
    required this.child,
    this.top  = 0,
    this.right = 0,
  });
 
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.streamUnreadCount(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(clipBehavior: Clip.none, children: [
          child,
          if (count > 0)
            Positioned(
              top: top, right: right,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: TClubColors.redPrincipal,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TClubColors.bg, width: 1.5),
                  boxShadow: [BoxShadow(
                    color: TClubColors.glow.withOpacity(0.5),
                    blurRadius: 6,
                  )],
                ),
                child: Center(child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 0.5,
                  ),
                )),
              ),
            ),
        ]);
      },
    );
  }
}

