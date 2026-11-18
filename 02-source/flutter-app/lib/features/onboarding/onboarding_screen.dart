import '../robot/robot_art_palette.dart';
import '../../design/mochi_design.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../robot/robot_mascot_widget.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _robotNameController = TextEditingController(
    text: 'Mochi',
  );
  final TextEditingController _goalController = TextEditingController();

  String _gradeBand = 'THCS';
  String _selectedSubject = 'Toán';
  int _selectedColorHex = 0xFF50C9A7;

  final List<String> _gradeBands = [
    'Tiểu học',
    'THCS',
    'THPT',
    'Đại học',
    'Tự học',
  ];
  final List<String> _subjects = [
    'Toán',
    'Vật lý',
    'Hóa học',
    'Tiếng Anh',
    'Ngữ văn',
    'Tin học',
    'Sinh học',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _robotNameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentStep == 0 && _nameController.text.trim().isEmpty) {
      _nameController.text = 'Bạn nhỏ';
    }
    if (_currentStep == 1 && _goalController.text.trim().isEmpty) {
      _goalController.text = 'Chinh phục kỳ thi học kỳ';
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    HapticFeedback.selectionClick();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishOnboarding() async {
    final store = context.read<MochiStore>();
    store.changeRobotColor(_selectedColorHex);
    await store.completeOnboarding(
      learnerName: _nameController.text.trim(),
      gradeBand: _gradeBand,
      robotName: _robotNameController.text.trim().isEmpty
          ? 'Mochi'
          : _robotNameController.text.trim(),
      primaryGoal: _goalController.text.trim(),
      targetSubject: _selectedSubject,
    );
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return MochiScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Apple OS27 Segmented Dynamic Step Pill
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: List.generate(3, (index) {
                  final isPassed = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: isPassed
                            ? LinearGradient(
                                colors: [
                                  MochiPalette.of(context).action,
                                  MochiPalette.of(context).accent,
                                ],
                              )
                            : null,
                        color: isPassed
                            ? null
                            : MochiPalette.of(context).cardBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1LearnerInfo(),
                  _buildStep2GoalSetup(),
                  _buildStep3RobotCustomization(),
                ],
              ),
            ),

            // Bottom Floating Controls
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    MochiButton(
                      label: 'Quay lại',
                      icon: Icons.arrow_back_rounded,
                      variant: MochiButtonVariant.secondary,
                      onPressed: _prevPage,
                    ),
                  if (_currentStep > 0) SizedBox(width: 12),
                  Expanded(
                    child: MochiButton(
                      label: _currentStep == 2
                          ? 'Bắt đầu'
                          : 'Tiếp tục',
                      icon: _currentStep == 2
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _nextPage,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1LearnerInfo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mascotSize = (constraints.maxHeight * 0.22).clamp(70.0, 130.0);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),
              Center(
                child: RobotMascotWidget(
                  size: mascotSize,
                  primaryColor: Color(_selectedColorHex),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Chào mừng bạn đến với Mochi!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: MochiPalette.of(context).ink,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Người bạn robot AI thông minh đồng hành cùng việc học mỗi ngày.',
                style: TextStyle(
                  fontSize: 13,
                  color: MochiPalette.of(context).muted,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Tên hoặc biệt danh của bạn:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MochiPalette.of(context).ink,
                  fontSize: 13.5,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Minh Khang, Lan Anh...',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: MochiPalette.of(context).muted,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Cấp học hiện tại:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MochiPalette.of(context).ink,
                  fontSize: 13.5,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _gradeBands.map((grade) {
                  final isSelected = _gradeBand == grade;
                  return MochiFilterChip(
                    label: grade,
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _gradeBand = grade);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep2GoalSetup() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            'Mục tiêu học tập lớn của bạn',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: MochiPalette.of(context).ink,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Mochi AI sẽ phân rã mục tiêu này thành những bước nhỏ khả thi.',
            style: TextStyle(
              fontSize: 13,
              color: MochiPalette.of(context).muted,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Môn học bạn muốn tập trung nhất:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: MochiPalette.of(context).ink,
              fontSize: 13.5,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _subjects.map((subj) {
              final isSelected = _selectedSubject == subj;
                return MochiFilterChip(
                  label: subj,
                selected: isSelected,
                onSelected: (val) {
                  if (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSubject = subj);
                  }
                },
              );
            }).toList(),
          ),
          SizedBox(height: 20),
          Text(
            'Mục tiêu cụ thể:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: MochiPalette.of(context).ink,
              fontSize: 13.5,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _goalController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Ví dụ: Đạt điểm 9 môn Toán học kỳ này, Thuộc 300 từ vựng IELTS...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3RobotCustomization() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mascotSize = (constraints.maxHeight * 0.24).clamp(80.0, 140.0);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),
              Center(
                child: RobotMascotWidget(
                  size: mascotSize,
                  primaryColor: Color(_selectedColorHex),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Tùy chỉnh người bạn Robot',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: MochiPalette.of(context).ink,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Đặt tên và chọn sắc màu đồng hành cùng bạn.',
                style: TextStyle(
                  fontSize: 13,
                  color: MochiPalette.of(context).muted,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Tên Robot:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MochiPalette.of(context).ink,
                  fontSize: 13.5,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _robotNameController,
                decoration: InputDecoration(
                  hintText: 'Mochi, Pi, Bobo, Astra...',
                  prefixIcon: Icon(
                    Icons.smart_toy_outlined,
                    color: MochiPalette.of(context).muted,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Sắc màu chủ đạo:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MochiPalette.of(context).ink,
                  fontSize: 13.5,
                ),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: RobotArtPalette.colors.map((c) {
                  final isSelected = _selectedColorHex == c.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedColorHex = c.toARGB32());
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? MochiPalette.of(context).accent
                              : MochiPalette.of(context).cardBorder,
                          width: isSelected ? 3.5 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
