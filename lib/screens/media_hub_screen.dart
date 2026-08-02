import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../main.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';

/// Media App definition with name, URL, and icon
class MediaApp {
  final String name;
  final String url;
  final IconData? icon;
  final String? imagePath;
  final Color accent;

  MediaApp({
    required this.name,
    required this.url,
    this.icon,
    this.imagePath,
    this.accent = LumiColors.greenNav,
  });
}

/// Allowed hosts for the Watch Area sandbox (YouTube family only).
const _allowedHostSuffixes = <String>[
  'youtube.com',
  'youtu.be',
  'youtubekids.com',
  'youtube-nocookie.com',
  'googlevideo.com',
  'ytimg.com',
  'ggpht.com',
  'google.com',
  'gstatic.com',
];

bool isAllowedWatchUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;
  return _allowedHostSuffixes.any(
    (suffix) => host == suffix || host.endsWith('.$suffix'),
  );
}

/// Watch Area — sandbox for safe YouTube content with continuous camera monitoring.
///
/// Children can open YouTube, YouTube Kids, or YouTube Playables while LUMI
/// tracks blinks and phone distance in the background.
class MediaHubScreen extends StatefulWidget {
  const MediaHubScreen({super.key, this.active = true});

  /// When false (e.g. another RootApp tab), dispose the WebView to free memory.
  final bool active;

  @override
  State<MediaHubScreen> createState() => _MediaHubScreenState();
}

class _MediaHubScreenState extends State<MediaHubScreen> {
  WebViewController? _webViewController;
  int? _selectedMediaIndex;
  bool _barsVisible = true;
  bool _bubbleExpanded = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOfflineBlocked = false;

  final List<MediaApp> _mediaApps = [
    MediaApp(
      name: 'YouTube',
      url: 'https://www.youtube.com',
      imagePath: 'assets/media_hub/youtube.png',
      accent: const Color(0xFFFF0000), // YouTube red
    ),
    MediaApp(
      name: 'YouTube Kids',
      url: 'https://www.youtubekids.com',
      icon: Icons.child_care_rounded,
      accent: const Color(0xFFFFC72C), // Kids yellow
    ),
    MediaApp(
      name: 'Playables',
      url: 'https://www.youtube.com/playables',
      icon: Icons.sports_esports_rounded,
      accent: const Color(0xFF1A73E8), // Playables blue
    ),
  ];

  @override
  void initState() {
    super.initState();
    _webViewController = null;
    mediaHubFullscreenNotifier.value = false;
    mediaHubBubbleTapNotifier.addListener(_onBubbleTap);
  }

  @override
  void didUpdateWidget(covariant MediaHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _tearDownWebView(keepSelection: true);
    } else if (!oldWidget.active &&
        widget.active &&
        _selectedMediaIndex != null &&
        _webViewController == null) {
      _initializeWebView(_selectedMediaIndex!);
      if (mounted) setState(() {});
    }
  }

  void _onBubbleTap() {
    if (_selectedMediaIndex == null) return;
    setState(() {
      _bubbleExpanded = !_bubbleExpanded;
      // Long-press from the floating bubble should surface Play Area controls,
      // even if the user was in fullscreen.
      if (_bubbleExpanded && !_barsVisible) {
        _barsVisible = true;
        mediaHubFullscreenNotifier.value = false;
      }
    });
  }

  void _tearDownWebView({required bool keepSelection}) {
    _webViewController = null;
    _isLoading = false;
    _errorMessage = null;
    _isOfflineBlocked = false;
    mediaHubFullscreenNotifier.value = false;
    if (!keepSelection) {
      _selectedMediaIndex = null;
      _barsVisible = true;
      _bubbleExpanded = false;
    }
    if (mounted) setState(() {});
  }

  void _initializeWebView(int index) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOfflineBlocked = false;
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _errorMessage = 'Could not load this page. Check your connection and try again.';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (isAllowedWatchUrl(request.url)) {
              return NavigationDecision.navigate;
            }
            debugPrint('Blocked non-allowlisted URL: ${request.url}');
            return NavigationDecision.prevent;
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(Uri.parse(_mediaApps[index].url));

    _webViewController = controller;
  }

  void _switchToMedia(int index) {
    setState(() {
      _selectedMediaIndex = index;
      _bubbleExpanded = false;
      _errorMessage = null;
      if (_webViewController == null) {
        _initializeWebView(index);
      } else {
        _isLoading = true;
        _webViewController!.loadRequest(Uri.parse(_mediaApps[index].url));
      }
    });
  }

  void _retry() {
    final index = _selectedMediaIndex;
    if (index == null) return;
    _tearDownWebView(keepSelection: true);
    _initializeWebView(index);
    setState(() {});
  }

  void _toggleFullScreen() {
    setState(() {
      _barsVisible = !_barsVisible;
      mediaHubFullscreenNotifier.value = !_barsVisible;
      _bubbleExpanded = false;
    });
  }

  Widget _buildMediaIcon(MediaApp app, {double size = 80}) {
    if (app.imagePath != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(app.imagePath!, fit: BoxFit.contain),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: app.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(LumiRadii.lg),
      ),
      child: Icon(app.icon ?? Icons.play_circle_fill, size: size * 0.55, color: app.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.active && _webViewController == null && _selectedMediaIndex == null) {
      return const SizedBox.shrink();
    }

    if (_selectedMediaIndex == null) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.lg),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          LumiTheme.caps('Play Area'),
                          textAlign: TextAlign.center,
                          style: LumiTheme.joyful(28, color: LumiColors.primaryPurple),
                        ),
                        const SizedBox(height: LumiSpacing.xs),
                        Text(
                          'YouTube · Kids · Playables',
                          textAlign: TextAlign.center,
                          style: LumiTheme.clanRegular(13),
                        ),
                        const SizedBox(height: LumiSpacing.lg),
                        ...List.generate(_mediaApps.length, (index) {
                          final app = _mediaApps[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: index == _mediaApps.length - 1 ? 0 : LumiSpacing.md),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
                                onTap: () => _switchToMedia(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: LumiSpacing.lg,
                                    vertical: LumiSpacing.md,
                                  ),
                                    decoration: BoxDecoration(
                                    color: LumiColors.primaryLight,
                                    borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
                                    border: Border.all(color: app.accent, width: ArcadeSizes.cardBorder),
                                    boxShadow: LumiShadows.hard(
                                      color: app.accent,
                                      offset: const Offset(0, ArcadeSizes.cardShadowY),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildMediaIcon(app, size: 56),
                                      const SizedBox(width: LumiSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              app.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: LumiTheme.clanMedium(18, color: LumiColors.textDark),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Tap to play',
                                              style: LumiTheme.clanRegular(12, color: app.accent),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const ArcadeIcon('play', size: 28),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F11) : LumiColors.scaffoldMint,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Web content fills the page content area (above the root nav bar).
            if (_webViewController != null && widget.active)
              WebViewWidget(controller: _webViewController!)
            else if (!widget.active)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(LumiSpacing.xl),
                  child: Text(
                    'Play paused — open Play Area again to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: LumiColors.textMuted,
                    ),
                  ),
                ),
              ),

            if (_isLoading) const Center(child: CircularProgressIndicator()),

            if (_errorMessage != null || _isOfflineBlocked)
              Positioned.fill(
                child: Container(
                  color: (isDark ? const Color(0xFF0F172A) : LumiColors.cardWhite).withValues(alpha: 0.92),
                  padding: const EdgeInsets.all(LumiSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: LumiColors.textDisabled),
                      const SizedBox(height: LumiSpacing.lg),
                      Text(
                        _errorMessage ?? 'You need an internet connection to watch.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 24 / 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : LumiColors.textDark,
                        ),
                      ),
                      const SizedBox(height: LumiSpacing.lg),
                      ElevatedButton(
                        onPressed: _retry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LumiColors.greenMid,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: LumiSpacing.lg,
                            vertical: LumiSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LumiRadii.md),
                          ),
                        ),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),

            // Top floating controls
            if (_barsVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(LumiSpacing.md, LumiSpacing.sm, LumiSpacing.md, 0),
                    child: Row(
                      children: [
                        _FloatingWatchButton(
                          arcadeIcon: 'back',
                          accent: LumiColors.primaryPurple,
                          tooltip: 'Go back',
                          onTap: () => _webViewController?.goBack(),
                        ),
                        const Spacer(),
                        _FloatingWatchButton(
                          materialIcon: Icons.refresh_rounded,
                          accent: LumiColors.primaryGreen,
                          tooltip: 'Reload',
                          onTap: _retry,
                        ),
                        const SizedBox(width: LumiSpacing.sm),
                        _FloatingWatchButton(
                          arcadeIcon: 'close',
                          accent: LumiColors.redAlert,
                          tooltip: 'Exit Play Area',
                          onTap: () => _tearDownWebView(keepSelection: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom collapsible sheet — pinned above the root nav bar
            if (_barsVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _bubbleExpanded = !_bubbleExpanded),
                      child: Container(
                        width: 52,
                        height: 40,
                        margin: const EdgeInsets.only(bottom: LumiSpacing.sm),
                        decoration: BoxDecoration(
                          color: LumiColors.primaryLight,
                          borderRadius: BorderRadius.circular(LumiRadii.pill),
                          border: Border.all(
                            color: LumiColors.primaryPurple,
                            width: ArcadeSizes.badgeBorder,
                          ),
                          boxShadow: LumiShadows.badge(LumiColors.primaryPurple),
                        ),
                        child: Center(
                          child: AnimatedRotation(
                            turns: _bubbleExpanded ? 0.5 : 0.0,
                            duration: LumiMotion.normal,
                            curve: LumiMotion.easeStandard,
                            child: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: LumiColors.primaryPurple,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: LumiMotion.slow,
                      curve: LumiMotion.easeStandard,
                      alignment: Alignment.topCenter,
                      child: _bubbleExpanded
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(
                                LumiSpacing.lg,
                                0,
                                LumiSpacing.lg,
                                LumiSpacing.lg,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                                decoration: BoxDecoration(
                                  color: LumiColors.primaryLight,
                                  borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
                                  border: Border.all(
                                    color: LumiColors.secondaryLight,
                                    width: ArcadeSizes.cardBorder,
                                  ),
                                  boxShadow: LumiShadows.modal(),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      LumiTheme.caps('Switch Media'),
                                      textAlign: TextAlign.center,
                                      style: LumiTheme.joyful(18, color: LumiColors.primaryPurple),
                                    ),
                                    const SizedBox(height: LumiSpacing.md),
                                    ...List.generate(_mediaApps.length, (index) {
                                      final isSelected = index == _selectedMediaIndex;
                                      final app = _mediaApps[index];
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: index == _mediaApps.length - 1 ? 0 : LumiSpacing.sm,
                                        ),
                                        child: GestureDetector(
                                          onTap: () => _switchToMedia(index),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: LumiSpacing.md,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: LumiColors.primaryLight,
                                              borderRadius: BorderRadius.circular(LumiRadii.lg),
                                              border: Border.all(
                                                color: app.accent,
                                                width: isSelected ? ArcadeSizes.cardBorder : 2.5,
                                              ),
                                              boxShadow: isSelected
                                                  ? LumiShadows.hard(
                                                      color: app.accent,
                                                      offset: const Offset(0, 3),
                                                    )
                                                  : const [],
                                            ),
                                            child: Row(
                                              children: [
                                                _buildMediaIcon(app, size: 36),
                                                const SizedBox(width: LumiSpacing.md),
                                                Expanded(
                                                  child: Text(
                                                    app.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: LumiTheme.clanMedium(
                                                      14,
                                                      color: LumiColors.textDark,
                                                    ),
                                                  ),
                                                ),
                                                ArcadeIcon('play', size: 20, greyscale: !isSelected),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: LumiSpacing.md),
                                    ArcadeButton(
                                      text: 'FULL SCREEN',
                                      onTap: _toggleFullScreen,
                                      variant: ArcadeButtonVariant.primary,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    mediaHubBubbleTapNotifier.removeListener(_onBubbleTap);
    mediaHubFullscreenNotifier.value = false;
    _webViewController = null;
    super.dispose();
  }
}

class _FloatingWatchButton extends StatelessWidget {
  const _FloatingWatchButton({
    required this.accent,
    required this.onTap,
    required this.tooltip,
    this.arcadeIcon,
    this.materialIcon,
  });

  final Color accent;
  final VoidCallback onTap;
  final String tooltip;
  final String? arcadeIcon;
  final IconData? materialIcon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LumiColors.primaryLight,
            borderRadius: BorderRadius.circular(LumiRadii.pill),
            border: Border.all(color: accent, width: ArcadeSizes.badgeBorder),
            boxShadow: LumiShadows.badge(accent),
          ),
          child: arcadeIcon != null
              ? ArcadeIcon(arcadeIcon!, size: 22)
              : Icon(materialIcon, size: 22, color: accent),
        ),
      ),
    );
  }
}
