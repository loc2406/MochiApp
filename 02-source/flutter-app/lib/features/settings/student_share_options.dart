import 'package:flutter/material.dart';

import '../../core/models/student_share_sections.dart';

/// Presentation metadata for one checkbox in the sharing permissions screen.
class StudentShareOption {
  final String key;
  final String title;
  final String description;
  final IconData icon;

  const StudentShareOption({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
  });
}

const studentShareOptions = <StudentShareOption>[
  StudentShareOption(
    key: StudentShareSections.profile,
    title: 'Hồ sơ học sinh',
    description: 'Tên và lớp/khối của học sinh.',
    icon: Icons.badge_outlined,
  ),
  StudentShareOption(
    key: StudentShareSections.xp,
    title: 'Điểm XP',
    description: 'Điểm tích lũy từ hoạt động học tập.',
    icon: Icons.bolt_rounded,
  ),
  StudentShareOption(
    key: StudentShareSections.streak,
    title: 'Chuỗi ngày học',
    description: 'Số ngày học liên tiếp hiện tại.',
    icon: Icons.local_fire_department_rounded,
  ),
  StudentShareOption(
    key: StudentShareSections.studyMinutes,
    title: 'Thời gian học',
    description: 'Tổng số phút đã học.',
    icon: Icons.schedule_rounded,
  ),
  StudentShareOption(
    key: StudentShareSections.goals,
    title: 'Mục tiêu học tập',
    description: 'Danh sách mục tiêu và trạng thái hoàn thành.',
    icon: Icons.flag_outlined,
  ),
  StudentShareOption(
    key: StudentShareSections.courses,
    title: 'Môn học & chủ đề',
    description: 'Các môn đang học và số chủ đề của mỗi môn.',
    icon: Icons.menu_book_rounded,
  ),
  StudentShareOption(
    key: StudentShareSections.progress,
    title: 'Tiến độ chủ đề',
    description: 'Mức độ tự tin của từng chủ đề học tập.',
    icon: Icons.trending_up_rounded,
  ),
  StudentShareOption(
    key: StudentShareSections.recentStudy,
    title: 'Hoạt động gần đây',
    description: 'Các buổi học gần nhất và thời lượng.',
    icon: Icons.history_rounded,
  ),
];
