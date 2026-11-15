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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _isSignUp ? 'Tạo tài khoản học tập' : 'Đăng nhập tài khoản',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
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

              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: MochiPalette.of(context).dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: MochiPalette.of(context).danger
                          .withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: MochiPalette.of(context).danger,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: MochiPalette.of(context).danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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

              SizedBox(
                width: double.infinity,
                child: MochiPrimaryButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MochiPalette.of(context).accent,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: MochiPalette.of(context).onAccent,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isSignUp
                              ? 'Tạo tài khoản & Đồng bộ'
                              : 'Đăng nhập ngay',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 12),

              Wrap(
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
                  TextButton(
                    onPressed: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _errorMessage = null;
                    }),
                    child: Text(
                      _isSignUp ? 'Đăng nhập' : 'Đăng ký ngay',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: MochiPalette.of(context).action,
                      ),
                    ),
                  ),
                ],
              ),

              if (widget.isSkippable) ...[
                SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: widget.onAuthenticated,
                    icon: Icon(Icons.arrow_forward, size: 16),
                    label: Text(
                      'Bỏ qua & Dùng thử trực tiếp',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
