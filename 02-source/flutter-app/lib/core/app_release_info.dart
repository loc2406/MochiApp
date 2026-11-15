import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppReleaseInfo {
  final String version;
  final String build;
  const AppReleaseInfo(this.version, this.build);

  static Future<AppReleaseInfo> read() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final info = await const MethodChannel('mochi/notifications')
            .invokeMapMethod<String, dynamic>('appInfo');
        if (info != null)
          return AppReleaseInfo(
            info['version'].toString(),
            info['build'].toString(),
          );
      } on PlatformException {
        /* Fall back to build-time metadata. */
      } on MissingPluginException {
        /* Widget tests and non-native hosts. */
      }
    }
    return const AppReleaseInfo(
      String.fromEnvironment('MOCHII_VERSION', defaultValue: 'phát triển'),
      String.fromEnvironment('MOCHII_BUILD', defaultValue: ''),
    );
  }

  String get label =>
      build.isEmpty ? 'Phiên bản $version' : 'Phiên bản $version ($build)';
}
