import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../main.dart';
import '../services/detection_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  late WebViewController? _webViewController;
  int? _selectedMediaIndex; // null = no service selected
  bool _barsVisible = true;
  bool _bubbleExpanded = false;

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
    // Do NOT initialize webview yet - wait for service selection
    _webViewController = null;
    // Ensure camera is running in foreground sandbox mode
    DetectionService.instance.ensureMonitoringWithRetry();
    // Reset fullscreen mode when entering media hub
    mediaHubFullscreenNotifier.value = false;
    
    // Listen to bubble tap events from TrackingBubble
    mediaHubBubbleTapNotifier.addListener(_onBubbleTap);
    // Keep screen awake while in media hub
    WakelockPlus.enable();
  }

  void _onBubbleTap() {
    // Toggle bubble expansion when bubble is tapped
    if (_selectedMediaIndex != null) {
      setState(() {
        _bubbleExpanded = !_bubbleExpanded;
      });
    }
  }

  void _initializeWebView(int index) {
    // Only initialize webview when a service is selected
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            // Page loading started
          },
          onPageFinished: (String url) {
            // Page finished loading
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow only http/https URLs
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
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36')
      ..loadRequest(
        Uri.parse(_mediaApps[index].url),
      );
  }

  void _switchToMedia(int index) {
    setState(() {
      _selectedMediaIndex = index;
      _bubbleExpanded = false;
      // Initialize webview only on first selection
      if (_webViewController == null) {
        _initializeWebView(index);
      } else {
        // Just load the new URL if webview already exists
        _webViewController!.loadRequest(
          Uri.parse(_mediaApps[index].url),
        );
      }
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _barsVisible = !_barsVisible;
      mediaHubFullscreenNotifier.value = !_barsVisible;
      _bubbleExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Show service selector if no service is selected
    if (_selectedMediaIndex == null) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Media Hub'),
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
          ),
          backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAFAFC),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Choose a Streaming Service',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 20,
                      children: List.generate(_mediaApps.length, (index) {
                        final app = _mediaApps[index];
                        return GestureDetector(
                          onTap: () => _switchToMedia(index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: Image.asset(
                                    app.imagePath!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  app.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Show webview with service selector and controls
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAFAFC),
        appBar: _barsVisible && _selectedMediaIndex != null
            ? AppBar(
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                elevation: 0,
                title: const Text(
                  'Media Hub',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    iconSize: 22,
                    onPressed: () => _webViewController?.reload(),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    iconSize: 22,
                    onPressed: () => _webViewController?.goBack(),
                  ),
                ],
              )
            : (_barsVisible ? AppBar(
                title: const Text('Media Hub'),
                elevation: 0,
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
              ) : null),
        body: Column(
          children: [
            // WebView content - only loaded when service is selected
            if (_webViewController != null)
              Expanded(
                child: WebViewWidget(controller: _webViewController!),
              ),

            // Collapsible bubble menu container
            if (_selectedMediaIndex != null && _barsVisible)
              GestureDetector(
                onTap: () => setState(() => _bubbleExpanded = !_bubbleExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AnimatedRotation(
                    turns: _bubbleExpanded ? 0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '^',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),

            // Animated collapsible container with app carousel and fullscreen toggle
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _bubbleExpanded && _selectedMediaIndex != null
                  ? Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        border: Border.all(
                          color: isDark ? Colors.white54 : Colors.black26,
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFB9E3A4),
                            offset: Offset(0, -2),
                            blurRadius: 0,
                          ),
                          BoxShadow(
                            color: Color(0xFFD5C2E8),
                            offset: Offset(0, -1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App carousel selector
                          SizedBox(
                            height: 110,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _mediaApps.length,
                              itemBuilder: (context, index) {
                                final isSelected = index == _selectedMediaIndex;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: GestureDetector(
                                    onTap: () => _switchToMedia(index),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF00ACC1)
                                                  : (isDark ? Colors.white24 : Colors.black12),
                                              width: isSelected ? 3 : 1,
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFF00ACC1).withValues(alpha: 0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: Image.asset(
                                              _mediaApps[index].imagePath!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _mediaApps[index].name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isDark
                                                ? (isSelected ? const Color(0xFF00BCD4) : Colors.white70)
                                                : (isSelected ? const Color(0xFF00ACC1) : Colors.black54),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Fullscreen toggle button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _toggleFullScreen,
                              icon: Icon(
                                _barsVisible ? Icons.fullscreen : Icons.fullscreen_exit,
                                size: 22,
                              ),
                              label: Text(
                                _barsVisible ? 'Enter Full Screen' : 'Exit Full Screen',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00ACC1),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
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
    // Allow screen to sleep again when exiting media hub
    WakelockPlus.disable();
    super.dispose();
  }
}
