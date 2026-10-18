import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String minVersion;
  final String downloadUrl;
  final String changelog;
  final bool isForceUpdate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.downloadUrl,
    required this.changelog,
    required this.isForceUpdate,
  });
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String fallbackCurrentVersion = '1.0.0';

  /// Membandingkan 2 string versi (misal: "1.0.0" vs "1.0.1")
  /// Return true jika v1 < v2 (butuh update)
  static bool isVersionLower(String v1, String v2) {
    try {
      final cleanV1 = v1.split('+').first.trim();
      final cleanV2 = v2.split('+').first.trim();

      final parts1 = cleanV1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = cleanV2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (parts1.length < 3) {
        parts1.add(0);
      }
      while (parts2.length < 3) {
        parts2.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (parts1[i] < parts2[i]) return true;
        if (parts1[i] > parts2[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Mendapatkan versi aplikasi yang sedang aktif
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version.isNotEmpty ? packageInfo.version : fallbackCurrentVersion;
    } catch (_) {
      return fallbackCurrentVersion;
    }
  }

  /// Mengecek ke Supabase apakah ada versi terbaru
  Future<AppUpdateInfo?> checkUpdate() async {
    try {
      final platform = !kIsWeb && Platform.isWindows ? 'windows' : 'android';
      final response = await Supabase.instance.client
          .from('app_versions')
          .select()
          .or('platform.eq.$platform,platform.eq.all')
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final latestVer = response['latest_version']?.toString() ?? '';
      final minVer = response['min_version']?.toString() ?? '';
      final downloadUrl = response['download_url']?.toString() ?? '';
      final changelog = response['changelog']?.toString() ?? '';
      final isForce = (response['is_force_update'] as bool?) ?? true;

      final currentVer = await getCurrentVersion();

      // Jika versi saat ini lebih rendah dari latestVer
      if (isVersionLower(currentVer, latestVer)) {
        // Cek apakah wajib update (jika current < minVersion atau isForceUpdate == true)
        final mustForce = isForce || isVersionLower(currentVer, minVer);
        return AppUpdateInfo(
          latestVersion: latestVer,
          minVersion: minVer,
          downloadUrl: downloadUrl,
          changelog: changelog,
          isForceUpdate: mustForce,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[AppUpdateService] Check update failed/offline: $e');
      return null;
    }
  }

  /// Tampilkan dialog update (Wajib / Opsional)
  void showUpdateDialog(BuildContext context, AppUpdateInfo info, String currentVer) {
    showDialog(
      context: context,
      barrierDismissible: !info.isForceUpdate,
      builder: (ctx) => _UpdateDialogWidget(
        info: info,
        currentVersion: currentVer,
      ),
    );
  }
}

class _UpdateDialogWidget extends StatefulWidget {
  final AppUpdateInfo info;
  final String currentVersion;

  const _UpdateDialogWidget({
    required this.info,
    required this.currentVersion,
  });

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _startUpdate() async {
    final url = widget.info.downloadUrl;
    if (url.isEmpty) return;

    if (!kIsWeb && Platform.isWindows && url.endsWith('.exe')) {
      // Direct in-app background download & silent installer trigger for Windows
      setState(() {
        _isDownloading = true;
        _progress = 0.0;
        _statusMessage = 'Menghubungkan ke server pembaruan...';
      });

      try {
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request);

        if (response.statusCode != 200) {
          throw Exception('Gagal mendownload installer (HTTP ${response.statusCode})');
        }

        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}\\KasirKu_Update_Setup.exe');
        final sink = tempFile.openWrite();

        await response.stream.listen((chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            setState(() {
              _progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
              final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
              final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
              _statusMessage = 'Mendownload: $mbReceived MB / $mbTotal MB (${(_progress * 100).toInt()}%)';
            });
          }
        }).asFuture();

        await sink.flush();
        await sink.close();

        setState(() {
          _statusMessage = 'Memasang pembaruan & memuat ulang aplikasi...';
        });

        // Jalankan installer dan keluar dari aplikasi lama
        await Process.start(
          tempFile.path,
          ['/SILENT', '/VERYSILENT', '/SUPPRESSMSGBOXES'],
          mode: ProcessStartMode.detached,
        );

        await Future.delayed(const Duration(milliseconds: 600));
        exit(0);
      } catch (e) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Download otomatis gagal: $e. Membuka browser...';
        });
        // Fallback buka URL di browser
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } else {
      // Android / Web / Direct Link
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.info.isForceUpdate && !_isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.card,
        elevation: 10,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Icon & Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.info.isForceUpdate
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.info.isForceUpdate
                            ? Icons.system_update_alt_rounded
                            : Icons.auto_awesome_rounded,
                        color: widget.info.isForceUpdate
                            ? AppColors.danger
                            : AppColors.primary,
                        size: 28,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.info.isForceUpdate
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.info.isForceUpdate ? 'WAJIB DIPERBARUI' : 'VERSI BARU',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.info.isForceUpdate
                              ? AppColors.danger
                              : AppColors.success,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  widget.info.isForceUpdate
                      ? 'Pembaruan Aplikasi Diperlukan'
                      : 'Pembaruan Tersedia',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Version subtitle
                Text(
                  'Versi saat ini: v${widget.currentVersion} → Versi baru: v${widget.info.latestVersion}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),

                // Warning / Info Note
                Text(
                  widget.info.isForceUpdate
                      ? 'Aplikasi versi ini tidak dapat digunakan sebelum diperbarui ke versi ${widget.info.latestVersion} demi keamanan dan kestabilan data transaksi.'
                      : 'Tersedia peningkatan fitur dan perbaikan untuk KasirKu.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Changelog Box
                if (widget.info.changelog.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catatan Pembaruan:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.info.changelog,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF1E293B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Downloading Progress Bar
                if (_isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    if (!widget.info.isForceUpdate && !_isDownloading)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Nanti Saja'),
                        ),
                      ),
                    if (!widget.info.isForceUpdate && !_isDownloading)
                      const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isDownloading ? null : _startUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          _isDownloading
                              ? 'Mendownload...'
                              : 'Perbarui Sekarang (v${widget.info.latestVersion})',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
