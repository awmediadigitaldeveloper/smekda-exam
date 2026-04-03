import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

final Uri appHomeUrl = Uri.parse('https://smekda-mobile-test.vercel.app/');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

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

class _WebAppScreenState extends State<WebAppScreen> {
  late final WebViewController _controller;

  int _loadingProgress = 0;
  bool _isLoading = true;
  bool _didStartInitialLoad = false;
  bool _isPullRefreshing = false;
  double _scrollY = 0;
  double _pullDistance = 0;
  double? _dragStartY;
  String? _mainFrameError;
  _StartupStage _startupStage = _StartupStage.preparing;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
    _prepareStartup();
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
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _didStartInitialLoad = true;
              _isLoading = false;
              _isPullRefreshing = false;
              _loadingProgress = 100;
              _startupStage = _StartupStage.ready;
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) {
              return;
            }

            setState(() {
              _didStartInitialLoad = true;
              _isLoading = false;
              _isPullRefreshing = false;
              _startupStage = _StartupStage.ready;
              _mainFrameError = error.description;
            });
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) {
              return NavigationDecision.prevent;
            }

            if (_shouldOpenExternally(uri)) {
              await _launchExternal(uri);
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

    controller.setOnScrollPositionChange((change) {
      if (!mounted) {
        return;
      }

      setState(() {
        _scrollY = change.y;
      });
    });

    return controller;
  }

  bool _shouldOpenExternally(Uri uri) {
    const webSchemes = <String>{'http', 'https'};
    return !webSchemes.contains(uri.scheme);
  }

  Future<void> _launchExternal(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<List<String>> _handleFileSelection(FileSelectorParams params) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: params.mode == FileSelectorMode.openMultiple,
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
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

    if (mounted && Platform.isAndroid) {
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

  void _handlePointerDown(PointerDownEvent event) {
    if (_scrollY > 0 || _isLoading || _isPullRefreshing) {
      _dragStartY = null;
      return;
    }

    _dragStartY = event.position.dy;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final startY = _dragStartY;
    if (startY == null || _scrollY > 0 || _isPullRefreshing) {
      return;
    }

    final delta = event.position.dy - startY;
    if (delta <= 0) {
      return;
    }

    setState(() {
      _pullDistance = (delta * 0.45).clamp(0, 110);
    });
  }

  Future<void> _handlePointerEnd() async {
    final shouldRefresh = _pullDistance >= 72 && !_isPullRefreshing;

    setState(() {
      _dragStartY = null;
      _pullDistance = 0;
      if (shouldRefresh) {
        _isPullRefreshing = true;
      }
    });

    if (shouldRefresh) {
      await _reloadPage();
    }
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
          bottom: false,
          child: ColoredBox(
            color: Colors.white,
            child: Stack(
              children: [
                Positioned.fill(child: WebViewWidget(controller: _controller)),
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: (_) async => _handlePointerEnd(),
                    onPointerCancel: (_) async => _handlePointerEnd(),
                  ),
                ),
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
                if (_pullDistance > 0 || _isPullRefreshing)
                  Positioned(
                    top: 18,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Center(
                        child: _PullToRefreshIndicator(
                          progress: _pullDistance / 72,
                          isRefreshing: _isPullRefreshing,
                        ),
                      ),
                    ),
                  ),
                if (_mainFrameError != null)
                  Positioned.fill(
                    child: _ErrorView(
                      message: _mainFrameError!,
                      onRetry: _reloadPage,
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

class _PullToRefreshIndicator extends StatelessWidget {
  const _PullToRefreshIndicator({
    required this.progress,
    required this.isRefreshing,
  });

  final double progress;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0, 1).toDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              value: isRefreshing ? null : value,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isRefreshing ? 'Memuat ulang...' : 'Tarik untuk memuat ulang',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              FilledButton(onPressed: onRetry, child: const Text('Muat Ulang')),
            ],
          ),
        ),
      ),
    );
  }
}
