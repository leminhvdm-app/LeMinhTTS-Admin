import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'firebase_service.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String changelog;
  final String apkUrl;
  final bool forceUpdate;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.changelog,
    required this.apkUrl,
    this.forceUpdate = false,
  });
}

class AppUpdateService {
  static const String currentVersion = '1.0.0';
  static const String githubRepo = 'leminhvdm-app/LeMinhTTS';
  final FirebaseService _firebaseService = FirebaseService();

  static List<int> _parseVersion(String ver) {
    final clean = ver.trim().replaceAll(RegExp(r'^[vV]'), '');
    final parts = clean.split(RegExp(r'[^0-9]+'));
    return parts.where((p) => p.isNotEmpty).map(int.parse).toList();
  }

  static bool _isNewer(String remote, String current) {
    final r = _parseVersion(remote);
    final c = _parseVersion(current);
    final maxLen = r.length > c.length ? r.length : c.length;
    for (int i = 0; i < maxLen; i++) {
      final rVal = i < r.length ? r[i] : 0;
      final cVal = i < c.length ? c[i] : 0;
      if (rVal > cVal) return true;
      if (rVal < cVal) return false;
    }
    return false;
  }

  Future<AppUpdateInfo> checkForUpdate() async {
    // 1. Check Firebase first
    try {
      final baseUrl = await _firebaseService.getFirebaseUrl();
      final uri = Uri.parse('$baseUrl/admin_app.json');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200 && resp.body != 'null' && resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          final remoteVer = data['version']?.toString() ?? currentVersion;
          final apkUrl = data['apk_url']?.toString() ?? '';
          final changelog = data['changelog']?.toString() ?? 'Có phiên bản Admin mới!';
          final force = data['force_update'] == true;

          if (_isNewer(remoteVer, currentVersion) && apkUrl.isNotEmpty) {
            return AppUpdateInfo(
              hasUpdate: true,
              currentVersion: currentVersion,
              latestVersion: remoteVer,
              changelog: changelog,
              apkUrl: apkUrl,
              forceUpdate: force,
            );
          }
        }
      }
    } catch (_) {
      // Fallback to GitHub
    }

    // 2. Fallback: Check GitHub Releases API
    try {
      final ghUri = Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest');
      final resp = await http.get(ghUri, headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'LeMinhTTS-Admin-App',
      }).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final tag = data['tag_name']?.toString() ?? '';
        final remoteVer = tag.replaceAll(RegExp(r'^[vV]'), '');
        final body = data['body']?.toString() ?? 'Cập nhật phiên bản mới.';

        String apkUrl = '';
        final assets = data['assets'];
        if (assets is List) {
          for (final a in assets) {
            final name = a['name']?.toString().toLowerCase() ?? '';
            if (name.endsWith('.apk') && (name.contains('admin') || name.contains('app'))) {
              apkUrl = a['browser_download_url']?.toString() ?? '';
              break;
            }
          }
          if (apkUrl.isEmpty && assets.isNotEmpty) {
            for (final a in assets) {
              if (a['name']?.toString().toLowerCase().endsWith('.apk') == true) {
                apkUrl = a['browser_download_url']?.toString() ?? '';
                break;
              }
            }
          }
        }

        if (apkUrl.isEmpty) {
          apkUrl = data['html_url']?.toString() ?? 'https://github.com/$githubRepo/releases';
        }

        if (_isNewer(remoteVer, currentVersion)) {
          return AppUpdateInfo(
            hasUpdate: true,
            currentVersion: currentVersion,
            latestVersion: remoteVer,
            changelog: body,
            apkUrl: apkUrl,
          );
        }
      }
    } catch (_) {
      // Ignore network errors
    }

    return AppUpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      changelog: '',
      apkUrl: '',
    );
  }

  Future<bool> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
