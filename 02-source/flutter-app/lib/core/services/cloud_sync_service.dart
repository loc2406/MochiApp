import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/mochi_models.dart';

class StudentInviteExpired implements Exception {
  const StudentInviteExpired();
}

class CloudSyncService {
  static const _viewerTokenKey = 'mochi_student_viewer_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String embeddedUrl = 'https://aiukgaacbncpbosgbwzp.supabase.co';
  static const String embeddedPublishableKey =
      'sb_publishable_gPGHiTBvds62XsjFxJZjYg_v03Cu45B';

  bool isInitialized = false;
  String? currentUserId;
  String supabaseUrl = embeddedUrl;
  String supabaseAnonKey = embeddedPublishableKey;
  bool isConnected = false;

  Future<bool> initialize({String? url, String? anonKey}) async {
    if (isInitialized) return true;
    try {
      supabaseUrl = (url != null && url.isNotEmpty) ? url.trim() : embeddedUrl;
      supabaseAnonKey = (anonKey != null && anonKey.isNotEmpty)
          ? anonKey.trim()
          : embeddedPublishableKey;

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        publishableKey: supabaseAnonKey,
        debug: kDebugMode,
      );

      isInitialized = true;
      isConnected = true;
      currentUserId = Supabase.instance.client.auth.currentUser?.id;
      return true;
    } catch (e) {
      debugPrint('Cloud sync init error: $e');
      isInitialized = false;
      isConnected = false;
      return false;
    }
  }

  bool get hasActiveUser =>
      isInitialized && Supabase.instance.client.auth.currentUser != null;

  String? get userEmail =>
      isInitialized ? Supabase.instance.client.auth.currentUser?.email : null;

  // Real Supabase Auth Operations
  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    if (!isInitialized) await initialize();
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      currentUserId = res.user?.id;
      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Đăng ký không thành công: $e';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isInitialized) await initialize();
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      currentUserId = res.user?.id;
      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Đăng nhập không thành công: $e';
    }
  }

  Future<void> signOut() async {
    if (isInitialized) {
      await Supabase.instance.client.auth.signOut();
      currentUserId = null;
    }
  }

  Future<Map<String, dynamic>?> fetchAccountState() async {
    if (!hasActiveUser) throw StateError('authentication_required');
    return await Supabase.instance.client
        .from('mochi_account_state')
        .select('revision,state')
        .eq('user_id', currentUserId!)
        .maybeSingle()
        .timeout(const Duration(seconds: 12));
  }

  Future<int> saveAccountState(Map<String, dynamic> state, int revision) async {
    if (!hasActiveUser) throw StateError('authentication_required');
    final result = await Supabase.instance.client
        .rpc(
          'mochi_save_state',
          params: {'expected_revision': revision, 'new_state': state},
        )
        .timeout(const Duration(seconds: 12));
    return (result as num).toInt();
  }

  Future<String> createStudentInvite({required String email, required String role, required String code}) async {
    if (!hasActiveUser) throw StateError('authentication_required');
    final result = await Supabase.instance.client.rpc('mochi_create_student_invite', params: {
      'recipient_email': email.trim().toLowerCase(), 'viewer_role': role, 'invite_code': code,
    }).timeout(const Duration(seconds: 12));
    return result.toString();
  }

  Future<List<Map<String, dynamic>>> listStudentViewers() async {
    if (!hasActiveUser) throw StateError('authentication_required');
    final result = await Supabase.instance.client.rpc('mochi_list_student_viewers');
    return (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> revokeStudentViewer(String viewerId) async {
    if (!hasActiveUser) throw StateError('authentication_required');
    await Supabase.instance.client.rpc('mochi_revoke_student_viewer', params: {'viewer_id': viewerId});
  }

  Future<Map<String, dynamic>> redeemStudentInvite({required String email, required String code}) async {
    dynamic result;
    try {
      result = await Supabase.instance.client.rpc('mochi_redeem_student_invite', params: {
        'viewer_email': email.trim().toLowerCase(), 'invite_code': code.trim(),
      }).timeout(const Duration(seconds: 12));
    } on PostgrestException catch (error) {
      if (error.message.contains('invite_expired')) {
        throw const StudentInviteExpired();
      }
      rethrow;
    }
    final data = Map<String, dynamic>.from(result as Map);
    await _secureStorage.write(key: _viewerTokenKey, value: data['session_token'] as String);
    return data;
  }

  Future<void> clearStudentViewerSession() => _secureStorage.delete(key: _viewerTokenKey);

  Future<Map<String, dynamic>?> fetchStudentOverview() async {
    final token = await _secureStorage.read(key: _viewerTokenKey);
    if (token == null) return null;
    final result = await Supabase.instance.client.rpc('mochi_fetch_student_overview', params: {'viewer_token': token}).timeout(const Duration(seconds: 12));
    return result == null ? null : Map<String, dynamic>.from(result as Map);
  }
}
