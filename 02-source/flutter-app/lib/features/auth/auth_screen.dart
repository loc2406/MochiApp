import '../../design/mochi_design.dart';
import '../../core/models/mochi_models.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../robot/robot_mascot_widget.dart';

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
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
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
    });

    final store = context.read<MochiStore>();
    String? err;

    if (_isSignUp) {
      err = await store.cloudService.signUp(email: email, password: pass);
    } else {
      err = await store.cloudService.signIn(email: email, password: pass);
    }

    if (!mounted) return;
    if (err == null && !store.cloudService.hasActiveUser) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kiểm tra email để xác nhận tài khoản, sau đó đăng nhập để đồng bộ.';
      });
      return;
    }
    if (err == null) {
      await store.refreshCloudAuth();
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (store.syncError != null) {
        setState(() => _errorMessage = store.syncError);
        return;
      }
      widget.onAuthenticated();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MochiScaffold(
      appBar: MochiAppBar.detail(
        title: _isSignUp ? 'Tạo tài khoản học tập' : 'Đăng nhập tài khoản',
        subtitle: 'Đồng bộ tiến độ học tập của bạn',
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
                  _isSignUp
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
                  'Dữ liệu mục tiêu, bài tập và sao sẽ được đồng bộ tự động an toàn qua máy chủ đám mây.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: MochiPalette.of(context).muted,
                  ),
                ),
              ),
              SizedBox(height: 24),

              if (_errorMessage != null) ...[
                MochiNoticeBanner(
                  message: _errorMessage!,
                  severity: MochiNoticeSeverity.error,
                  compact: true,
                ),
                const SizedBox(height: MochiSpacing.md),
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
              SizedBox(height: 16),
              Text(
                'Mật khẩu:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
              SizedBox(height: 24),

              MochiButton(
                label: _isSignUp ? 'Tạo tài khoản & Đồng bộ' : 'Đăng nhập ngay',
                onPressed: _isLoading ? null : _handleSubmit,
                loading: _isLoading,
                expand: true,
              ),
              SizedBox(height: 12),

              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'Đã có tài khoản?' : 'Chưa có tài khoản?',
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
                      }),
                    ),
                  ],
                ),
              ),

              if (widget.isSkippable) ...[
                SizedBox(height: 16),
                Center(
                  child: MochiTextAction(
                    label: 'Bỏ qua & Dùng thử trực tiếp',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: widget.onAuthenticated,
                  ),
                ),
              ],
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
