import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/detection_service.dart';
import '../widgets/tracking_bubble.dart';

/// Media App definition with name, URL, and icon
class MediaApp {
  final String name;
  final String url;
  final IconData icon;

  MediaApp({required this.name, required this.url, required this.icon});
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

  // Predefined media apps with URLs and icons
  final List<MediaApp> _mediaApps = [
    MediaApp(name: 'YouTube', url: 'https://www.youtube.com', icon: Icons.play_circle),
    MediaApp(name: 'TikTok', url: 'https://www.tiktok.com', icon: Icons.music_note),
    MediaApp(name: 'Disney+', url: 'https://www.disneyplus.com', icon: Icons.movie),
    MediaApp(name: 'Netflix', url: 'https://www.netflix.com', icon: Icons.ondemand_video),
  ];

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    // Ensure camera is running in foreground sandbox mode
    DetectionService.instance.ensureMonitoringWithRetry();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Hub'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _webViewController.goBack();
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              // Media app selector bar
              Container(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_mediaApps.length, (index) {
                      final isSelected = index == _selectedMediaIndex;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: GestureDetector(
                          onTap: () => _switchToMedia(index),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF))
                                  : (isDark ? const Color(0xFF2A2A2E) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF))
                                    : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _mediaApps[index].icon,
                                  size: 24,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _mediaApps[index].name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
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
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
