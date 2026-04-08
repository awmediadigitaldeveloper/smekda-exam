import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

final Uri appHomeUrl = Uri.parse('https://smekda-mobile-test.vercel.app/');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const SmekdaMobileApp());
}

class SmekdaMobileApp extends StatelessWidget {
  const SmekdaMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMEKDA MOBILE TEST',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const WebAppScreen(),
    );
  }
}

enum _StartupStage { preparing, openingWeb, ready }

class WebAppScreen extends StatefulWidget {
  const WebAppScreen({super.key});

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> with WidgetsBindingObserver {
  static const _allowedTopLevelHosts = <String>{'smekda-mobile-test.vercel.app'};

  late final WebViewController _controller;

  int _loadingProgress = 0;
  bool _isLoading = true;
  bool _didStartInitialLoad = false;
  Uri _currentUrl = appHomeUrl;
  String? _mainFrameError;
  String? _securityMessage;
  bool _isSecurityLockActive = false;
  _StartupStage _startupStage = _StartupStage.preparing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activateExamMode();
    _controller = _buildController();
    _prepareStartup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _activateExamMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _activateSecurityLock(
        'Aplikasi keluar dari fokus ujian. Silakan kembali ke mode ujian.',
      );
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _activateExamMode();
      if (_isSecurityLockActive) {
        setState(() {
          _securityMessage = 'Mode ujian aktif. Tetap fokus pada aplikasi.';
        });
        _reloadPage();
      }
    }
  }

  void _activateSecurityLock(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isSecurityLockActive = true;
      _securityMessage = message;
    });
  }

  void _clearSecurityLock() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isSecurityLockActive = false;
      _securityMessage = null;
    });
  }

  bool _isAllowedTopLevelUri(Uri uri) {
    if (!uri.hasScheme) {
      return false;
    }

    if (!uri.scheme.startsWith('http')) {
      return true;
    }

    return _allowedTopLevelHosts.contains(uri.host);
  }

  Future<void> _prepareStartup() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) {
      return;
    }

    setState(() {
      _startupStage = _StartupStage.openingWeb;
    });

    await _controller.loadRequest(appHomeUrl);
  }

  WebViewController _buildController() {
    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..addJavaScriptChannel(
        'DownloadBridge',
        onMessageReceived: _handleDownloadMessage,
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }

            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isLoading = true;
              _mainFrameError = null;
            });
          },
          onPageFinished: (_) async {
            if (!mounted) {
              return;
            }

            setState(() {
              _didStartInitialLoad = true;
              _isLoading = false;
              _loadingProgress = 100;
              _startupStage = _StartupStage.ready;
            });

            final currentUrl = await _controller.currentUrl();
            if (currentUrl == null || !mounted) {
              return;
            }

            setState(() {
              _currentUrl = Uri.tryParse(currentUrl) ?? appHomeUrl;
            });

            await _injectDownloadSupport();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) {
              return;
            }

            setState(() {
              _didStartInitialLoad = true;
              _isLoading = false;
              _startupStage = _StartupStage.ready;
              _mainFrameError = error.description;
            });
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) {
              return NavigationDecision.prevent;
            }

            setState(() {
              _currentUrl = uri;
            });

            if (!_isAllowedTopLevelUri(uri)) {
              _activateSecurityLock(
                'Navigasi ke domain tidak diizinkan dalam mode ujian.',
              );
              await _controller.loadRequest(appHomeUrl);
              return NavigationDecision.prevent;
            }

            if (_shouldOpenExternally(uri)) {
              await _launchExternal(uri);
              return NavigationDecision.prevent;
            }

            if (_shouldTreatAsDownload(uri)) {
              await _handleDownloadNavigation(uri);

              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );

    if (controller.platform
        case final AndroidWebViewController androidController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setAllowFileAccess(true);
      androidController.setAllowContentAccess(true);
      androidController.setOnShowFileSelector(_handleFileSelection);
    }

    return controller;
  }

  bool _shouldOpenExternally(Uri uri) {
    const webSchemes = <String>{'http', 'https'};
    return !webSchemes.contains(uri.scheme);
  }

  bool _shouldTreatAsDownload(Uri uri) {
    final lowerPath = uri.path.toLowerCase();
    final lowerQuery = uri.query.toLowerCase();
    final hasFileExtension = RegExp(r'\.[a-z0-9]{1,8}$').hasMatch(lowerPath);
    final hasDownloadHint =
        lowerPath.contains('/download') ||
        lowerPath.contains('/export') ||
        lowerQuery.contains('download=') ||
        lowerQuery.contains('export=') ||
        lowerQuery.contains('attachment=') ||
        lowerQuery.contains('file=');

    return hasFileExtension || hasDownloadHint;
  }

  Future<void> _handleDownloadNavigation(Uri uri) async {
    if (uri.scheme == 'data') {
      await _saveDataUrlToDevice(uri.toString());
      return;
    }

    await _launchExternal(uri);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download diteruskan ke browser atau aplikasi sistem.'),
      ),
    );
  }

  Future<void> _launchExternal(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _injectDownloadSupport() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          if (window.__smekdaDownloadBridgeInstalled) return;
          window.__smekdaDownloadBridgeInstalled = true;

          document.documentElement.style.webkitTouchCallout = 'none';
          document.documentElement.style.webkitUserSelect = 'none';
          document.documentElement.style.msUserSelect = 'none';
          document.documentElement.style.userSelect = 'none';
          document.documentElement.style.touchAction = 'manipulation';

          document.addEventListener('contextmenu', function(event) {
            event.preventDefault();
          }, true);

          document.addEventListener('keydown', function(event) {
            const key = event.key.toLowerCase();
            const blockModifiers = event.ctrlKey || event.metaKey || event.altKey;
            const forbiddenKeys = ['c', 'x', 'v', 'a', 'p', 's', 'f12'];
            if (blockModifiers && forbiddenKeys.includes(key)) {
              event.preventDefault();
              event.stopPropagation();
            }
          }, true);

          document.addEventListener('visibilitychange', function() {
            if (document.hidden) {
              try {
                window.location.reload();
              } catch (_) {}
            }
          });

          async function sendBlobAsDataUrl(blobUrl, fileName) {
            const response = await fetch(blobUrl);
            const blob = await response.blob();
            const reader = new FileReader();
            reader.onloadend = function() {
              DownloadBridge.postMessage(JSON.stringify({
                type: 'dataUrl',
                dataUrl: reader.result,
                fileName: fileName || 'download',
                mimeType: blob.type || ''
              }));
            };
            reader.readAsDataURL(blob);
          }

          document.addEventListener('click', async function(event) {
            const anchor = event.target.closest('a');
            if (!anchor) return;

            const href = anchor.getAttribute('href') || '';
            const fileName = anchor.getAttribute('download') || '';
            if (!href) return;

            if (href.startsWith('blob:')) {
              event.preventDefault();
              try {
                await sendBlobAsDataUrl(href, fileName);
              } catch (_) {}
              return;
            }

            if (href.startsWith('data:')) {
              event.preventDefault();
              DownloadBridge.postMessage(JSON.stringify({
                type: 'dataUrl',
                dataUrl: href,
                fileName: fileName || 'download'
              }));
              return;
            }

            if (anchor.hasAttribute('download')) {
              DownloadBridge.postMessage(JSON.stringify({
                type: 'url',
                url: href,
                fileName: fileName || 'download'
              }));
            }
          }, true);
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _handleDownloadMessage(JavaScriptMessage message) async {
    try {
      final payload = jsonDecode(message.message) as Map<String, dynamic>;
      final type = payload['type'] as String?;

      if (type == 'dataUrl') {
        await _saveDataUrlToDevice(
          payload['dataUrl'] as String,
          suggestedFileName: payload['fileName'] as String?,
          mimeType: payload['mimeType'] as String?,
        );
        return;
      }

      if (type == 'url') {
        final url = payload['url'] as String?;
        final uri = url == null ? null : Uri.tryParse(url);
        if (uri != null) {
          await _handleDownloadNavigation(uri);
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download file tidak dapat diproses.')),
      );
    }
  }

  Future<void> _saveDataUrlToDevice(
    String dataUrl, {
    String? suggestedFileName,
    String? mimeType,
  }) async {
    final match = RegExp(
      r'^data:([^;,]+)?(?:;charset=[^;,]+)?(;base64)?,(.*)$',
      dotAll: true,
    ).firstMatch(dataUrl);

    if (match == null) {
      throw const FormatException('Invalid data URL');
    }

    final detectedMimeType = (mimeType?.isNotEmpty ?? false)
        ? mimeType!
        : (match.group(1)?.isNotEmpty ?? false)
        ? match.group(1)!
        : 'application/octet-stream';
    final isBase64 = match.group(2) != null;
    final rawData = match.group(3) ?? '';

    final bytes = isBase64
        ? base64Decode(rawData)
        : Uint8List.fromList(Uri.decodeComponent(rawData).codeUnits);

    final tempDir = await getTemporaryDirectory();
    final fileName = _buildDownloadFileName(
      suggestedFileName: suggestedFileName,
      mimeType: detectedMimeType,
    );
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);

    final savedPath = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        sourceFilePath: tempFile.path,
        fileName: fileName,
        mimeTypesFilter: <String>[detectedMimeType],
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath == null
              ? 'Penyimpanan file dibatalkan.'
              : 'File berhasil disimpan.',
        ),
      ),
    );
  }

  String _buildDownloadFileName({
    String? suggestedFileName,
    required String mimeType,
  }) {
    final sanitizedName = suggestedFileName?.trim();
    if (sanitizedName != null && sanitizedName.isNotEmpty) {
      return sanitizedName;
    }

    final extension = switch (mimeType.toLowerCase()) {
      'text/csv' => 'csv',
      'application/pdf' => 'pdf',
      'application/zip' => 'zip',
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      'application/vnd.ms-excel' => 'xls',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
        'xlsx',
      _ => 'bin',
    };

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'download_$timestamp.$extension';
  }

  Future<List<String>> _handleFileSelection(FileSelectorParams params) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: params.mode == FileSelectorMode.openMultiple,
      type: FileType.any,
    );

    if (result == null) {
      return const <String>[];
    }

    return result.files.map((file) => file.path).whereType<String>().toList();
  }

  Future<void> _handleBackPressed() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }

    if (!_isAtRootUrl(_currentUrl)) {
      await _controller.loadRequest(appHomeUrl);
      return;
    }

    final shouldExit = await _showExitConfirmation();
    if (shouldExit == true && mounted && Platform.isAndroid) {
      await SystemNavigator.pop();
    }
  }

  Future<void> _reloadPage() async {
    setState(() {
      _isLoading = true;
      _mainFrameError = null;
      _loadingProgress = 0;
      _startupStage = _StartupStage.openingWeb;
    });
    await _controller.reload();
  }

  bool _isAtRootUrl(Uri uri) {
    return uri.scheme == appHomeUrl.scheme &&
        uri.host == appHomeUrl.host &&
        uri.port == appHomeUrl.port &&
        uri.path == appHomeUrl.path;
  }

  Future<bool?> _showExitConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Keluar aplikasi?'),
          content: const Text(
            'Anda sudah berada di halaman utama. Apakah Anda ingin keluar dari aplikasi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showStartupOverlay =
        !_didStartInitialLoad || (_isLoading && _loadingProgress < 30);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }

        await _handleBackPressed();
      },
      child: Scaffold(
        body: SafeArea(
          child: ColoredBox(
            color: Colors.white,
            child: Stack(
              children: [
                Positioned.fill(child: WebViewWidget(controller: _controller)),
                if (_isLoading && _didStartInitialLoad)
                  Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: _loadingProgress == 100
                          ? null
                          : _loadingProgress / 100,
                    ),
                  ),
                if (showStartupOverlay)
                  Positioned.fill(
                    child: _StartupOverlay(
                      progress: _loadingProgress,
                      stage: _startupStage,
                    ),
                  ),
                if (_mainFrameError != null)
                  Positioned.fill(
                    child: _ErrorView(
                      message: _mainFrameError!,
                      onRetry: _reloadPage,
                    ),
                  ),
                if (_isSecurityLockActive && _securityMessage != null)
                  Positioned.fill(
                    child: _SecurityLockOverlay(
                      message: _securityMessage!,
                      onResume: _clearSecurityLock,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupOverlay extends StatelessWidget {
  const _StartupOverlay({required this.progress, required this.stage});

  final int progress;
  final _StartupStage stage;

  String get _title {
    switch (stage) {
      case _StartupStage.preparing:
        return 'Menyiapkan aplikasi';
      case _StartupStage.openingWeb:
        return 'Menghubungkan ke layanan';
      case _StartupStage.ready:
        return 'Hampir selesai';
    }
  }

  String get _subtitle {
    switch (stage) {
      case _StartupStage.preparing:
        return 'Aplikasi sedang menyiapkan tampilan awal.';
      case _StartupStage.openingWeb:
        return 'Mohon tunggu, halaman pertama sedang dimuat.';
      case _StartupStage.ready:
        return 'Menyelesaikan proses pembukaan aplikasi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressValue = progress <= 0 ? null : progress / 100;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFF5FBFF), Colors.white],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Image.asset('lib/images/logo.png'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SMEKDA MOBILE TEST',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF0F766E),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: progressValue,
                      backgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progress <= 0 ? 'Memulai...' : '$progress%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: Color(0xFF475569),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Halaman tidak bisa dimuat',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Muat Ulang'),
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

class _SecurityLockOverlay extends StatelessWidget {
  const _SecurityLockOverlay({required this.message, required this.onResume});

  final String message;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withOpacity(0.92),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  'Mode Ujian Terkunci',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onResume,
                  child: const Text('Kembali ke Ujian'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
