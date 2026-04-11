import 'package:flutter/material.dart';
import '../services/twenty_twenty_twenty_service.dart';
import '../services/detection_service.dart';

class TwentyTwentyBreakScreen extends StatefulWidget {
  const TwentyTwentyBreakScreen({Key? key}) : super(key: key);

  @override
  State<TwentyTwentyBreakScreen> createState() => _TwentyTwentyBreakScreenState();
}

class _TwentyTwentyBreakScreenState extends State<TwentyTwentyBreakScreen> {
  late TwentyTwentyBreakService _breakService;

  @override
  void initState() {
    super.initState();
    _breakService = TwentyTwentyBreakService.instance;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _breakService.canCancel || _breakService.stateNotifier.value == BreakState.completed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          if (_breakService.stateNotifier.value == BreakState.completed) {
            _breakService.resetBreakState();
          } else {
            _breakService.cancelBreak();
          }
        } else if (!_breakService.canCancel) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete your break to continue.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: _breakService.canCancel,
          title: const Text(
            '20-20-20 Eye Break',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: ValueListenableBuilder<BreakState>(
          valueListenable: _breakService.stateNotifier,
          builder: (context, state, _) {
            // Show permission dialog first
            if (state == BreakState.askingPermission) {
              return _buildPermissionDialog(context, isDark);
            }

            // Show break activity
            if (state == BreakState.running || state == BreakState.countdown) {
              return _buildBreakActivity(context, screenSize, isDark);
            }

            // Show completion screen
            if (state == BreakState.completed) {
              return _buildCompletionScreen(context, screenSize, isDark);
            }

            return const SizedBox.expand();
          },
        ),
      ),
    );
  }

  Widget _buildPermissionDialog(BuildContext context, bool isDark) {
    return Center(
      child: Dialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_off, size: 48, color: Color(0xFFFF6B6B)),
              const SizedBox(height: 16),
              const Text(
                'Time for an Eye Break!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Look away from the screen at something 20 feet away for 20 seconds.',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'When should you come back?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTimeButton(
                    onPressed: () => _breakService.confirmBreakWithRecoveryTime(1),
                    label: '1 Minute',
                    subtitle: 'Quick',
                  ),
                  _buildTimeButton(
                    onPressed: () => _breakService.confirmBreakWithRecoveryTime(2),
                    label: '2 Minutes',
                    subtitle: 'Extended',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'This is your only choice.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black45, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeButton({
    required VoidCallback onPressed,
    required String label,
    required String subtitle,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7FC86D),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBreakActivity(BuildContext context, Size screenSize, bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background with gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
            ),
          ),
        ),

        // Main timer and game area
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Timer Circle
              ValueListenableBuilder<BreakState>(
                valueListenable: _breakService.stateNotifier,
                builder: (_, state, __) {
                  if (state == BreakState.countdown) {
                    return _buildCountdownCircle();
                  }
                  return _buildTimerCircle();
                },
              ),
              const SizedBox(height: 40),

              // Face Detection Status
              ValueListenableBuilder<bool>(
                valueListenable: _breakService.faceDetectedNotifier,
                builder: (_, faceDetected, __) {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: faceDetected ? const Color(0xFF7FC86D).withOpacity(0.2) : const Color(0xFFFF6B6B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: faceDetected ? const Color(0xFF7FC86D) : const Color(0xFFFF6B6B),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              faceDetected ? Icons.check_circle : Icons.visibility_off,
                              color: faceDetected ? const Color(0xFF7FC86D) : const Color(0xFFFF6B6B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              faceDetected ? 'Face Detected' : 'Look Away (20 feet)',
                              style: TextStyle(
                                color: faceDetected ? const Color(0xFF7FC86D) : const Color(0xFFFF6B6B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'When your face reappears, the timer resets.',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // Recovery time badge (top right)
        ValueListenableBuilder<int>(
          valueListenable: _breakService.recoverySecondsNotifier,
          builder: (_, recoverySeconds, __) {
            if (recoverySeconds == 0) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: 80,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7FC86D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${recoverySeconds ~/ 60} min break',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimerCircle() {
    return ValueListenableBuilder<int>(
      valueListenable: _breakService.secondsRemainingNotifier,
      builder: (_, seconds, __) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(seconds: 1),
          builder: (context, value, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7FC86D).withOpacity(0.1),
                    border: Border.all(
                      color: const Color(0xFF7FC86D).withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                ),
                // Countdown text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seconds.toString(),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7FC86D),
                      ),
                    ),
                    const Text(
                      'seconds',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCountdownCircle() {
    return ValueListenableBuilder<int>(
      valueListenable: _breakService.countdownNotifier,
      builder: (_, countdown, __) {
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated circle
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1, end: (20 - countdown) / 20),
                duration: const Duration(milliseconds: 100),
                builder: (context, progress, child) {
                  return CustomPaint(
                    size: const Size(200, 200),
                    painter: CountdownPainter(progress),
                  );
                },
              ),
              // Victory icon
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF7FC86D),
                size: 80,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletionScreen(BuildContext context, Size screenSize, bool isDark) {
    return WillPopScope(
      onWillPop: () async {
        _breakService.resetBreakState();
        Navigator.of(context).pop();
        return false;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
              ),
            ),
          ),
          // Close button (top right)
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                _breakService.resetBreakState();
                Navigator.of(context).pop();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7FC86D).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFF7FC86D), width: 3),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Color(0xFF7FC86D),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Eye Break Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your eyes are refreshed. Great job!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'You can continue using the app now',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: () {
                            _breakService.resetBreakState();
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7FC86D),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

/// Custom painter for countdown progress circle
class CountdownPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  CountdownPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF7FC86D).withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Draw progress arc
    final paint = Paint()
      ..color = const Color(0xFF7FC86D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final angle = progress * 2 * 3.14159;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      angle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CountdownPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
