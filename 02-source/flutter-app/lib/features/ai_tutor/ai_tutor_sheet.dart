import 'package:flutter/material.dart';

import '../../core/models/mochi_models.dart';
import 'ai_tutor_screen.dart';

/// Focus-session tutor uses the same conversation and renderer as the main tab.
class AITutorSheet extends StatelessWidget {
  final TaskModel? taskContext;

  /// Chuyển sang mục Tôi để đăng nhập khi sheet không có thanh tab.
  final VoidCallback? onRequestLogin;

  const AITutorSheet({super.key, this.taskContext, this.onRequestLogin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          // Sheet đã tự đẩy lên trên bàn phím; xoá inset ở đây để màn hình con
          // không cộng thêm một khoảng chừa thứ hai.
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: AITutorScreen(
              taskContext: taskContext,
              inSheet: true,
              onRequestLogin: onRequestLogin,
            ),
          ),
        ),
      ),
    );
  }
}
