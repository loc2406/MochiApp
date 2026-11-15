import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AIAuthenticationRequired implements Exception {
  const AIAuthenticationRequired();
  @override
  String toString() => 'Đăng nhập để sử dụng trợ lý AI và lưu tiến độ học.';
}

/// Lỗi từ gateway/provider kèm mã để UI giải thích đúng nguyên nhân thay vì
/// chỉ báo "chưa kết nối được".
class AIGatewayFailure implements Exception {
  final String code;
  const AIGatewayFailure(this.code);
  @override
  String toString() => 'AIGatewayFailure($code)';
}

/// The application never ships the provider secret. The gateway checks the
/// actual authenticated user and enforces capacity before calling the provider.
class AIGatewayClient extends http.BaseClient {
  static const String _productionUrl =
      'https://bendocs.tailc1f51b.ts.net/mochi-ai';

  /// Gateway address. Build-time override wins; otherwise a loopback web
  /// preview (127.0.0.1/localhost) calls the same-origin `/mochi-ai` path so
  /// `05-operations/preview.py` can relay it server-side and CORS never
  /// applies. Production web/APK keep the absolute gateway.
  static String get baseUrl {
    const configured = String.fromEnvironment('MOCHI_AI_GATEWAY');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == '127.0.0.1' || host == 'localhost' || host == '::1') {
        return '${Uri.base.origin}/mochi-ai';
      }
    }
    return _productionUrl;
  }

  final http.Client _inner;
  final String? Function() _token;
  AIGatewayClient({http.Client? inner, String? Function()? token})
    : _inner = inner ?? http.Client(),
      _token = token ?? sessionToken;
  static String? sessionToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = _token();
    if (token == null || token.isEmpty) throw const AIAuthenticationRequired();
    final gateway =
        http.Request(request.method, Uri.parse('$baseUrl/chat/completions'))
          ..headers.addAll(request.headers)
          ..headers['Authorization'] = 'Bearer $token'
          ..bodyBytes = await request.finalize().toBytes();
    gateway.headers.remove('User-Agent');
    return _inner.send(gateway);
  }

  @override
  void close() => _inner.close();
}
