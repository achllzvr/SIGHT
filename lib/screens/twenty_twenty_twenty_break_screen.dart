import 'package:flutter/material.dart';

import '../services/twenty_twenty_twenty_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/lumi_form.dart';
import '../widgets/lumi_game_kit.dart';

class TwentyTwentyBreakScreen extends StatefulWidget {
  const TwentyTwentyBreakScreen({super.key});

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
    return PopScope(
      canPop: _breakService.canCancel || _breakService.stateNotifier.value == BreakState.completed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          if (_breakService.stateNotifier.value == BreakState.completed) {
            await _breakService.resetBreakState();
          } else {
            await _breakService.cancelBreak();
          }
        } else if (!_breakService.canCancel) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Finish your eye rest to keep going.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [LumiColors.gradientTop, LumiColors.gradientBottom],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(LumiSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ValueListenableBuilder<BreakState>(
                    valueListenable: _breakService.stateNotifier,
                    builder: (context, state, _) {
                      if (state == BreakState.askingPermission) {
                        return _buildStartCard(context);
                      }
                      if (state == BreakState.running || state == BreakState.countdown) {
                        return _buildBreakActivity(context);
                      }
                      if (state == BreakState.completed) {
                        return _buildCompletionScreen(context);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modalCard({required Widget child}) {
    return LumiGameCard(
      borderRadius: LumiRadii.xl,
      padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.xl, vertical: LumiSpacing.xl),
      child: child,
    );
  }

  Widget _buildStartCard(BuildContext context) {
    return _modalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/mascot/mascot_head_v1.png',
            width: 72,
            height: 72,
            errorBuilder: (_, __, ___) => const Icon(Icons.visibility_off, size: 56, color: LumiColors.greenMid),
          ),
          const SizedBox(height: LumiSpacing.lg),
          const Text(
            'Time for an Eye Rest!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, height: 32 / 24, letterSpacing: -0.24, fontWeight: FontWeight.w600, color: LumiColors.textDark),
          ),
          const SizedBox(height: LumiSpacing.md),
          const Text(
            'Look at something far away for 20 seconds. Keep your face off the phone so the timer can count down.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: LumiColors.textMuted, height: 20 / 14),
          ),
          const SizedBox(height: LumiSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(LumiSpacing.md),
            decoration: BoxDecoration(
              color: LumiColors.tipYellow,
              borderRadius: BorderRadius.circular(LumiRadii.md),
              border: Border.all(color: LumiColors.outline, width: 1),
              boxShadow: LumiShadows.card(LumiColors.shadowFor(LumiColors.tipYellow)),
            ),
            child: const Text(
              '20-20-20 tip: every 20 minutes, look 20 feet away for 20 seconds.',
              style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: LumiColors.textDark),
            ),
          ),
          const SizedBox(height: LumiSpacing.xl),
          LumiPillButton(
            label: 'Start Eye Rest',
            backgroundColor: LumiColors.greenSoft,
            onPressed: () => _breakService.startBreak(),
          ),
          if (_breakService.canCancel) ...[
            const SizedBox(height: LumiSpacing.md),
            LumiPillButton(
              label: 'Not now',
              backgroundColor: LumiColors.cardWhite,
              onPressed: () async {
                await _breakService.cancelBreak();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakActivity(BuildContext context) {
    return _modalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Look far away',
            style: TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, color: LumiColors.textDark),
          ),
          const SizedBox(height: LumiSpacing.lg),
          ValueListenableBuilder<BreakState>(
            valueListenable: _breakService.stateNotifier,
            builder: (_, state, __) {
              if (state == BreakState.countdown) {
                return const Icon(Icons.check_circle, size: 72, color: LumiColors.greenMid);
              }
              return ValueListenableBuilder<int>(
                valueListenable: _breakService.secondsRemainingNotifier,
                builder: (_, seconds, __) {
                  return Column(
                    children: [
                      Text(
                        '$seconds',
                        style: const TextStyle(
                          fontSize: 64,
                          letterSpacing: -0.64,
                          fontWeight: FontWeight.w700,
                          color: LumiColors.greenMid,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'seconds left',
                        style: TextStyle(fontSize: 14, height: 20 / 14, color: LumiColors.textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: LumiSpacing.xl),
          ValueListenableBuilder<bool>(
            valueListenable: _breakService.faceDetectedNotifier,
            builder: (_, lookingAtPhone, __) {
              final good = !lookingAtPhone;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.lg, vertical: LumiSpacing.md),
                decoration: BoxDecoration(
                  color: good ? LumiColors.greenBg : LumiColors.pinkUnsafe,
                  borderRadius: BorderRadius.circular(LumiRadii.pill),
                  border: Border.all(color: LumiColors.outline, width: 1),
                  boxShadow: LumiShadows.card(
                    LumiColors.shadowFor(good ? LumiColors.greenBg : LumiColors.pinkUnsafe),
                  ),
                ),
                child: Text(
                  good ? 'SAFE — looking far away' : 'Still looking at phone',
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                    color: good ? LumiColors.safeText : LumiColors.redAlert,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: LumiSpacing.lg),
          const Text(
            'Looking back at the phone resets the timer.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 16 / 12, color: LumiColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(BuildContext context) {
    return _modalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 80, color: LumiColors.greenMid),
          const SizedBox(height: LumiSpacing.lg),
          const Text(
            'Eye Rest Done!',
            style: TextStyle(fontSize: 24, height: 32 / 24, letterSpacing: -0.24, fontWeight: FontWeight.w600, color: LumiColors.textDark),
          ),
          const SizedBox(height: LumiSpacing.md),
          const Text(
            'Nice job — your eyes got a short break.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 20 / 14, color: LumiColors.textMuted, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: LumiSpacing.xl),
          LumiPillButton(
            label: 'Keep Going',
            backgroundColor: LumiColors.greenSoft,
            onPressed: () async {
              await _breakService.resetBreakState();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
