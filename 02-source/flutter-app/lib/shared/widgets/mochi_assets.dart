import '../../design/mochi_design.dart';

import 'package:flutter/material.dart';

class MochiShopAsset extends StatelessWidget {
  final String itemId;
  final double size;

  const MochiShopAsset({super.key, required this.itemId, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/item_$itemId.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.shopping_bag_outlined,
            size: size * 0.7,
            color: MochiPalette.of(context).action,
          );
        },
      ),
    );
  }
}

class MochiRobotImageAsset extends StatelessWidget {
  final String emotion;
  final double size;

  const MochiRobotImageAsset({
    super.key,
    required this.emotion,
    this.size = 130,
  });

  @override
  Widget build(BuildContext context) {
    String file = 'robot_idle.png';
    if (emotion == 'happy')
      file = 'robot_happy.png';
    else if (emotion == 'focus')
      file = 'robot_focus.png';
    else if (emotion == 'thinking')
      file = 'robot_thinking.png';
    else if (emotion == 'celebrate')
      file = 'robot_celebrate.png';

    return Image.asset(
      'assets/images/$file',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.smart_toy_rounded,
          size: size * 0.8,
          color: MochiPalette.of(context).success,
        );
      },
    );
  }
}

class MochiBadge extends StatelessWidget {
  final String type; // star, streak, xp, time
  final String label;
  final Color? color;

  const MochiBadge({
    super.key,
    required this.type,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'star':
        icon = Icons.star_rounded;
        iconColor = MochiPalette.of(context).warning;
        break;
      case 'streak':
        icon = Icons.local_fire_department_rounded;
        iconColor = MochiPalette.of(context).warning;
        break;
      case 'xp':
        icon = Icons.bolt_rounded;
        iconColor = MochiPalette.of(context).warning;
        break;
      case 'time':
        icon = Icons.schedule_rounded;
        iconColor = MochiPalette.of(context).action;
        break;
      default:
        icon = Icons.check_circle_rounded;
        iconColor = MochiPalette.of(context).success;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
