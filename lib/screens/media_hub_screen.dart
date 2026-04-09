import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../main.dart';
import '../services/detection_service.dart';

/// Media App definition with name, URL, and icon
class MediaApp {
  final String name;
  final String url;
  final IconData? icon;
  final String? imagePath;

  MediaApp({
    required this.name,
    required this.url,
    this.icon,
    this.imagePath,
  });
}

/// Media Hub Screen - Sandbox for safe content consumption with continuous camera monitoring.
/// 
/// This screen creates a "Media Sandbox" where children can consume web content (YouTube, TikTok, Disney+, Netflix)
/// while SIGHT maintains foreground camera tracking for blink rate and viewing distance.
/// The camera overlay (TrackingBubble) remains visible to monitor eye health metrics.
class MediaHubScreen extends StatefulWidget {
  const MediaHubScreen({super.key});

  @override
  State<MediaHubScreen> createState() => _MediaHubScreenState();
}

class _MediaHubScreenState extends State<MediaHubScreen> {
  late WebViewController _webViewController;
  bool _isWebViewReady = false;
  int _selectedMediaIndex = 0;
  bool _barsVisible = true;

  // Predefined media apps with URLs and PNG icons
  final List<MediaApp> _mediaApps = [
    MediaApp(
      name: 'YouTube',
      url: 'https://www.youtube.com',
      imagePath: 'assets/media_hub/youtube.png',
    ),
    MediaApp(
      name: 'TikTok',
      url: 'https://www.tiktok.com',
      imagePath: 'assets/media_hub/tiktok.png',
    ),
    MediaApp(
      name: 'Disney+',
      url: 'https://www.disneyplus.com',
      imagePath: 'assets/media_hub/disney_plus.png',
    ),
    MediaApp(
      name: 'Netflix',
      url: 'https://www.netflix.com',
      imagePath: 'assets/media_hub/netflix.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    // Ensure camera is running in foreground sandbox mode
    DetectionService.instance.ensureMonitoringWithRetry();
    // Reset fullscreen mode when entering media hub
    mediaHubFullscreenNotifier.value = false;
    
    // Listen to bubble tap events from TrackingBubble
    mediaHubBubbleTapNotifier.addListener(_onBubbleTap);
  }

  void _onBubbleTap() {
    // Toggle bars when bubble is tapped
    _toggleBars();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isWebViewReady = false);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isWebViewReady = true);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
          // Handle custom URL schemes (e.g., TikTok's snssdk1180://)
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('http://') ||
                request.url.startsWith('https://')) {
              return NavigationDecision.navigate;
            }
            // Block custom schemes (app-specific URLs)
            debugPrint('Blocked custom URL scheme: ${request.url}');
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(_mediaApps[_selectedMediaIndex].url),
      );
  }

  void _switchToMedia(int index) {
    setState(() {
      _selectedMediaIndex = index;
      _webViewController.loadRequest(
        Uri.parse(_mediaApps[index].url),
      );
    });
  }

  void _toggleBars() {
    setState(() {
      _barsVisible = !_barsVisible;
      mediaHubFullscreenNotifier.value = !_barsVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: _barsVisible
            ? AppBar(
                title: const Text('Media Hub'),
                elevation: 1,
              )
            : null,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                // Media selector bar with controls - combined on one line
                if (_barsVisible)
                  Container(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    height: 70,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Media app selector buttons - scrollable
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_mediaApps.length, (index) {
                                final isSelected = index == _selectedMediaIndex;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: GestureDetector(
                                    onTap: () => _switchToMedia(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDark
                                                ? const Color(0xFF0A84FF)
                                                : const Color(0xFF007AFF))
                                            : (isDark
                                                ? const Color(0xFF2A2A2E)
                                                : Colors.white),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? (isDark
                                                  ? const Color(0xFF0A84FF)
                                                  : const Color(0xFF007AFF))
                                              : (isDark
                                                  ? Colors.grey.shade700
                                                  : Colors.grey.shade300),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: Image.asset(
                                              _mediaApps[index].imagePath!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            _mediaApps[index].name,
                                            style: TextStyle(
                                              fontSize: 6.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isDark
                                                      ? Colors.white70
                                                      : Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        // Refresh and Back buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 1,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: IconButton(
                                  icon: const Icon(Icons.refresh),
                                  iconSize: 16,
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _webViewController.reload();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  iconSize: 16,
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _webViewController.goBack();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // WebView content
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isWebViewReady)
                        WebViewWidget(controller: _webViewController)
                      else
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Remove listener when leaving media hub
    mediaHubBubbleTapNotifier.removeListener(_onBubbleTap);
    // Reset fullscreen mode when leaving media hub
    mediaHubFullscreenNotifier.value = false;
    super.dispose();
  }
}
