import '../../design/mochi_design.dart';
import '../../core/models/mochi_models.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/services/cloud_sync_service.dart';
import '../robot/robot_mascot_widget.dart';
import 'student_overview_screen.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final bool isSkippable;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    this.isSkippable = true,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isViewer = false;
  bool _awaitingConfirmation = false;
  bool _completed = false;
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _inviteCodeCtrl = TextEditingController();
  String? _errorMessage;
  String? _infoMessage;
  late final MochiStore _store;

  @override
  void initState() {
    super.initState();
    _store = context.read<MochiStore>();
    // The confirmation link signs the learner in through Supabase's own deep
    // link handler; this listener closes the auth screen when that happens.
    _store.cloudService.activeUserId.addListener(_onActiveUserChanged);
  }

  @override
  void dispose() {
    _store.cloudService.activeUserId.removeListener(_onActiveUserChanged);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  void _onActiveUserChanged() {
    if (!mounted || _completed) return;
    if (!_store.cloudService.hasActiveUser) return;
    unawaited(_finishAuthentication());
  }

  Future<void> _finishAuthentication() async {
    if (!mounted || _completed) return;
    _completed = true;
    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _infoMessage = null;
    });
    await _store.refreshCloudAuth();
    if (!mounted) return;
    if (_store.syncError != null) {
      _completed = false;
      setState(() {
        _errorMessage = _store.syncError;
      });
      return;
    }
    widget.onAuthenticated();
  }

  bool _isUnconfirmedEmail(String message) {
    final lower = message.toLowerCase();
    return lower.contains('email not confirmed') ||
        lower.contains('not confirmed') ||
        lower.contains('chưa được xác nhận');
  }

  Future<void> _handleViewerSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _emailCtrl.text.trim();
    final code = _inviteCodeCtrl.text.trim();
    if (!email.contains('@') || code.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập email và mã mời hợp lệ.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await context.read<MochiStore>().cloudService.redeemStudentInvite(
        email: email,
        code: code,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StudentOverviewScreen()),
      );
    } on StudentInviteExpired {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Mã mời đã hết hạn sau 5 phút. Hãy nhờ học sinh tạo và gửi mã mới.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Email hoặc mã mời không đúng, mã đã được sử dụng, hoặc quyền truy cập đã bị thu hồi.';
      });
    }
  }

  void _handleSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Vui lòng nhập địa chỉ email hợp lệ.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu phải từ 6 ký tự trở lên.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    String? err;
    if (_isSignUp) {
      err = await _store.cloudService.signUp(email: email, password: pass);
    } else {
      err = await _store.cloudService.signIn(email: email, password: pass);
    }

    if (!mounted) return;

    // Sign-up with "Confirm email" enabled returns no session yet.
    if (err == null && !_store.cloudService.hasActiveUser) {
      setState(() {
        _isLoading = false;
        _awaitingConfirmation = true;
        _errorMessage =
            'Đã gửi email xác nhận tới $email. Mở email trên chính điện thoại này và chạm vào liên kết để kích hoạt tài khoản.';
      });
      return;
    }

    if (err == null) {
      await _finishAuthentication();
      return;
    }

    // Promote to a non-nullable local: `err` cannot be promoted inside the
    // closure because it is assigned in both branches above.
    final failure = err;
    final needsConfirmation = _isUnconfirmedEmail(failure);
    setState(() {
      _isLoading = false;
      _awaitingConfirmation = needsConfirmation;
      _errorMessage = needsConfirmation
          ? 'Email chưa được xác nhận. Mở email trên chính điện thoại này và chạm vào liên kết, hoặc gửi lại email xác nhận bên dưới.'
          : failure;
    });
  }

  Future<void> _resendConfirmation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Vui lòng nhập địa chỉ email hợp lệ.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    final err = await _store.cloudService.resendConfirmation(email: email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (err == null) {
        _infoMessage = 'Đã gửi lại email xác nhận tới $email.';
      } else {
        _errorMessage = err;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MochiScaffold(
      appBar: MochiAppBar.detail(
        title: _isViewer
            ? 'Xem tiến độ học tập'
            : (_isSignUp ? 'Tạo tài khoản học tập' : 'Đăng nhập tài khoản'),
        subtitle: _isViewer
            ? 'Dành cho phụ huynh và giáo viên'
            : 'Đồng bộ tiến độ học tập của bạn',
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: RobotMascotWidget(
                      size: 100,
                      emotion: RobotEmotion.happy,
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      _isViewer
                          ? 'Kết nối bằng mã mời'
                          : _isSignUp
                          ? 'Đăng ký lưu trữ đám mây'
                          : 'Chào mừng bạn quay lại!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: MochiPalette.of(context).ink,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Center(
                    child: Text(
                      _isViewer
                          ? 'Nhập email đã được học sinh cấp quyền và mã mời dùng một lần.'
                          : 'Dữ liệu mục tiêu, bài tập và sao sẽ được đồng bộ tự động an toàn qua máy chủ đám mây.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: MochiPalette.of(context).muted,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  if (_infoMessage != null) ...[
                    MochiNoticeBanner(
                      message: _infoMessage!,
                      severity: MochiNoticeSeverity.success,
                      compact: true,
                    ),
                    const SizedBox(height: MochiSpacing.md),
                  ],

                  if (_errorMessage != null) ...[
                    MochiNoticeBanner(
                      message: _errorMessage!,
                      severity: _awaitingConfirmation
                          ? MochiNoticeSeverity.warning
                          : MochiNoticeSeverity.error,
                      compact: true,
                    ),
                    const SizedBox(height: MochiSpacing.sm),
                  ],

                  if (_awaitingConfirmation && !_isViewer) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _isLoading ? null : _resendConfirmation,
                        icon: const Icon(
                          Icons.forward_to_inbox_rounded,
                          size: 18,
                        ),
                        label: const Text('Gửi lại email xác nhận'),
                      ),
                    ),
                    const SizedBox(height: MochiSpacing.sm),
                  ],

                  Text(
                    'Địa chỉ Email:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'hocsinh@example.com',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: MochiPalette.of(context).muted,
                      ),
                    ),
                  ),
                  if (!_isViewer) SizedBox(height: 16),
                  if (!_isViewer) ...[
                    Text(
                      'Mật khẩu:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 6),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Tối thiểu 6 ký tự',
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: MochiPalette.of(context).muted,
                        ),
                      ),
                    ),
                  ],
                  if (_isViewer) ...[
                    SizedBox(height: 16),
                    Text(
                      'Mã mời một lần:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 6),
                    TextField(
                      controller: _inviteCodeCtrl,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        hintText: 'Dán mã do học sinh gửi',
                        prefixIcon: Icon(
                          Icons.key_rounded,
                          color: MochiPalette.of(context).muted,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 24),

                  MochiButton(
                    label: _isViewer
                        ? 'Xem thông tin học sinh'
                        : (_isSignUp
                              ? 'Tạo tài khoản & Đồng bộ'
                              : 'Đăng nhập ngay'),
                    onPressed: _isLoading
                        ? null
                        : (_isViewer ? _handleViewerSubmit : _handleSubmit),
                    loading: _isLoading,
                    expand: true,
                  ),
                  SizedBox(height: 12),

                  if (!_isViewer)
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _isSignUp
                                ? 'Đã có tài khoản?'
                                : 'Chưa có tài khoản?',
                            style: TextStyle(
                              fontSize: 13,
                              color: MochiPalette.of(context).muted,
                            ),
                          ),
                          MochiTextAction(
                            label: _isSignUp ? 'Đăng nhập' : 'Đăng ký ngay',
                            onPressed: () => setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMessage = null;
                              _infoMessage = null;
                              _awaitingConfirmation = false;
                            }),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 8),
                  Center(
                    child: MochiTextAction(
                      label: _isViewer
                          ? 'Quay lại đăng nhập học sinh'
                          : 'Bạn là giáo viên/phụ huynh?',
                      icon: _isViewer
                          ? Icons.arrow_back_rounded
                          : Icons.family_restroom_rounded,
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                              _isViewer = !_isViewer;
                              _errorMessage = null;
                              _infoMessage = null;
                              _awaitingConfirmation = false;
                            }),
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
