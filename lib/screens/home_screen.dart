import 'package:flutter/material.dart';

import '../services/cleanup_service.dart';
import '../services/gamification_service.dart';
import '../services/metrics_service.dart';
import '../services/session_timer_service.dart';
import '../widgets/rounded_card.dart';
// ignore: unused_import
import '../services/offline_models.dart';
import '../services/feedback_service.dart';
import '../services/guardian_auth_service.dart';
import '../services/auth_session_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showMetrics = true; // Track whether metrics container is expanded
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _TopBadge(), // Your Coin Badge
                      Row(
                        children: [
                          // Clothes icon (Store)
                          GestureDetector(
                            onTap: () {
                              if (!context.mounted) return;
                              // TODO: Implement actual store screen and navigation
                              Navigator.pushNamed(context, '/store');
                            },
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 1),
                                boxShadow: const [
                                  BoxShadow(color: Color(0xFFB9E3A4), offset: Offset(2, 2), blurRadius: 0),
                                  BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(1, 1), blurRadius: 0),
                                ],
                              ),
                              child: const Icon(Icons.checkroom, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const _SessionTimeBadge(),
                          // Settings gear icon
                          GestureDetector(
                            onTap: () => _showSettingsDialog(context),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 1),
                                boxShadow: const [
                                  BoxShadow(color: Color(0xFFB9E3A4), offset: Offset(2, 2), blurRadius: 0),
                                  BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(1, 1), blurRadius: 0),
                                ],
                              ),
                              child: const Icon(Icons.settings, size: 20),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _HealthBar(),
                ],
              ),
            ),

            // Mascot area - animated based on Health Score
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 270,
                  height: _showMetrics ? 340 : 360,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: MetricsService.instance.faceDetectedNotifier,
                    builder: (_, faceDetected, __) {
                      return ValueListenableBuilder<int>(
                        valueListenable: GamificationService.instance.healthScoreNotifier,
                        builder: (_, hp, __) {
                          final mascotPath = _resolveMascotAsset(
                            faceDetected: faceDetected,
                            hp: hp,
                          );
                          return Image.asset(mascotPath, fit: BoxFit.contain);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // Collapsible metrics container with arrow toggle
            GestureDetector(
              onTap: () => setState(() => _showMetrics = !_showMetrics),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedRotation(
                  turns: _showMetrics ? 0 : 0.5,
                  duration: const Duration(milliseconds: 300),
                  child: Text('^', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
                ),
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _showMetrics
                  ? Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: isDark ? Colors.white54 : Colors.black26, width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFB9E3A4), offset: Offset(0, -2), blurRadius: 0),
                  BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(0, -1), blurRadius: 0),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
                        builder: (_, value, __) => _MetricChip(label: '$value/min', caption: 'Blink Rate'),
                      ),
                      ValueListenableBuilder<double>(
                        valueListenable: MetricsService.instance.distanceCmNotifier,
                        builder: (_, value, __) => _MetricChip(label: value > 0 ? '${value.toStringAsFixed(1)} cm' : '--', caption: 'Distance'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.08),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Use the bottom navigation to go to Tracker or Tasks', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
                    )
                  : const SizedBox.shrink(),
            )
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Haptic Feedback Toggle
            _SettingsTile(
              title: 'Haptic Feedback',
              subtitle: 'Vibrations and touches',
              icon: Icons.vibration,
              onTap: () {
                final current = FeedbackService.instance.isHapticEnabled;
                FeedbackService.instance.setHapticEnabled(!current);
                setState(() {});
              },
              isEnabled: FeedbackService.instance.isHapticEnabled,
            ),
            const SizedBox(height: 12),
            // Vibration Intensity Preset Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Vibration Duration',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${(FeedbackService.instance.vibrationIntensity * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF7FC86D)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [0, 25, 50, 75, 100].map((percent) {
                    final value = percent / 100.0;
                    final isSelected = (FeedbackService.instance.vibrationIntensity * 100).round() == percent;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () {
                            FeedbackService.instance.setVibrationIntensity(value);
                            FeedbackService.instance.provideFeedback(FeedbackType.info);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF7FC86D) : (isDark ? Colors.white10 : Colors.grey[200]),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF7FC86D) : (isDark ? Colors.white24 : Colors.black12),
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$percent%',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap a level to adjust vibration duration',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Audio Feedback Toggle
            _SettingsTile(
              title: 'Audio Feedback',
              subtitle: 'Sounds and beeps',
              icon: Icons.volume_up,
              onTap: () {
                final current = FeedbackService.instance.isAudioEnabled;
                FeedbackService.instance.setAudioEnabled(!current);
                setState(() {});
              },
              isEnabled: FeedbackService.instance.isAudioEnabled,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Try biometric authentication first
    final canAuth = await GuardianAuthService.instance.canAuthenticate();
    if (canAuth) {
      final authenticated = await GuardianAuthService.instance.authenticateWithBiometrics();
      if (authenticated) {
        if (!context.mounted) return; // Added context check
        await _performLogout(context);
        return;
      }
    }

    // Fall back to PIN entry
    if (!context.mounted) return; // Swapped to context.mounted
    _showPinEntryDialog(context);
  }

  void _showPinEntryDialog(BuildContext context) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Guardian Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter guardian passcode to logout'),
            const SizedBox(height: 20),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: '••••',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final storedPin = await GuardianAuthService.instance.loadFallbackPin();
              if (storedPin != null && GuardianAuthService.instance.verifyFallbackPin(pinController.text, storedPin)) {
                if (!dialogContext.mounted) return; // Swapped to context check
                Navigator.pop(dialogContext); // Close PIN dialog
                
                if (!context.mounted) return;
                await _performLogout(context);
              } else {
                if (!dialogContext.mounted) return; // Swapped to context check
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Incorrect passcode')),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    // Perform complete service cleanup (stop camera, cancel timers, clear metrics)
    await CleanupService.instance.performCompleteCleanup();

    // Clear auth session
    await AuthSessionService.instance.clearSession();

    if (!context.mounted) return; // Swapped to context.mounted
    // Navigate back to auth screen
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String caption;
  const _MetricChip({required this.label, required this.caption});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFDFDFD),
            border: Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0xFFB9E3A4), offset: Offset(2, 2), blurRadius: 0),
              BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(1, 1), blurRadius: 0),
            ],
          ),
          child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 5),
        Text(caption, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 76,
      height: 46,
      child: ValueListenableBuilder<int>(
        valueListenable: GamificationService.instance.coinsNotifier,
        builder: (_, coins, __) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFD9EE),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 1),
              boxShadow: const [
                BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$coins', style: const TextStyle(fontWeight: FontWeight.bold, height: 1)),
                const SizedBox(height: 2),
                const Text('COINS', style: TextStyle(fontSize: 8.5, height: 1, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );

  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isEnabled;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? const Color(0xFF7FC86D)
                : (isDark ? Colors.white24 : Colors.black12),
            width: isEnabled ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: isEnabled ? const Color(0xFF7FC86D) : (isDark ? Colors.white60 : Colors.black54)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            Container(
              width: 50,
              height: 28,
              decoration: BoxDecoration(
                color: isEnabled ? const Color(0xFF7FC86D) : (isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  isEnabled ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: GamificationService.instance.healthScoreNotifier,
      builder: (context, hp, _) {
        Color barColor = hp < 30 ? const Color(0xFFFF6B6B) : (hp < 70 ? const Color(0xFFE9C37F) : const Color(0xFF9DE18A));
        return RoundedCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: GamificationService.instance.mascotNameNotifier,
                    builder: (_, name, __) => GestureDetector(
                      onTap: () => _showRenameDialog(context, name),
                      child: Row(
                        children: [
                          Text('$name\'S HEALTH', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 12, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  Text('$hp / 100', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: barColor)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: hp / 100,
                  minHeight: 10,
                  backgroundColor: Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
  
  void _showRenameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Mascot"),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Enter new name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              GamificationService.instance.renameMascot(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

String _resolveMascotAsset({
  required bool faceDetected,
  required int hp,
}) {
  if (!faceDetected) {
    return 'assets/mascot/mascot_head_v1.png';
  }

  if (hp >= 70) {
    return 'assets/mascot/mascot_great_v1.png'; // Happy
  } else if (hp >= 30) {
    return 'assets/mascot/mascot_good_v1.png'; // Warning/Tired
  } else {
    return 'assets/mascot/mascot_bad_v1.png'; // Critical/Sad
  }
}

class _SessionTimeBadge extends StatelessWidget {
  const _SessionTimeBadge();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SessionTimerService.instance.remainingSecondsNotifier,
      builder: (_, seconds, __) {
        final mins = (seconds / 60).floor();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD5C2E8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black87, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 4),
              Text('$mins m', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}