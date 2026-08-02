import 'package:flutter/material.dart';

import '../../../services/guardian_preferences_service.dart';
import '../../../services/rule_engine_service.dart';
import '../../../services/session_timer_service.dart';
import '../../../theme/lumi_theme.dart';
import '../../../widgets/arcade/arcade.dart';
import 'shared_widgets.dart';

class ChildDashboardLimitsTab extends StatefulWidget {
  final int? childId;
  const ChildDashboardLimitsTab({super.key, this.childId});

  @override
  State<ChildDashboardLimitsTab> createState() => _ChildDashboardLimitsTabState();
}

class _ChildDashboardLimitsTabState extends State<ChildDashboardLimitsTab> {
  late GuardianPreferences _preferences;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await GuardianPreferencesService.instance.loadPreferences();
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _preferences = const GuardianPreferences.defaults();
          _loading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _saving = true);
    try {
      await GuardianPreferencesService.instance.savePreferences(_preferences);
      await GuardianPreferencesService.instance.pushSessionLimitsToServer(_preferences);
      await RuleEngineService.instance.applyGuardianPreferences(_preferences);
      await SessionTimerService.instance.reloadFromPreferences();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Limits saved and applied')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  /// Chunky arcade slider — thick track, bordered thumb.
  Widget _arcadeSlider({
    required double value,
    required double min,
    required double max,
    required Color accent,
    required Color track,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 12,
        activeTrackColor: accent,
        inactiveTrackColor: track,
        thumbColor: LumiColors.primaryLight,
        overlayColor: accent.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 0, pressedElevation: 0),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LumiColors.primaryPurple));
    }

    final isRelaxed = _preferences.monitoringMode == 'Relaxed';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LumiSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArcadeCard(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: GuardianSectionTitle('Daily Screen Limit', size: 17)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: LumiColors.secondaryGreen,
                        borderRadius: BorderRadius.circular(LumiRadii.pill),
                        border: Border.all(color: LumiColors.primaryGreen, width: 3),
                      ),
                      child: Text(
                        '${_preferences.dailyScreenLimitMinutes} min',
                        style: LumiTheme.clanMedium(13, color: LumiColors.primaryGreen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LumiSpacing.sm),
                _arcadeSlider(
                  value: _preferences.dailyScreenLimitMinutes.toDouble(),
                  min: 15,
                  max: 240,
                  divisions: 15,
                  accent: LumiColors.primaryGreen,
                  track: LumiColors.secondaryLight,
                  onChanged: (v) => setState(
                    () => _preferences = _preferences.copyWith(dailyScreenLimitMinutes: v.toInt()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LumiSpacing.lg),
          ArcadeCard(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GuardianSectionTitle('Distance Alerts', size: 17),
                const SizedBox(height: LumiSpacing.md),
                Text(
                  'Warn below ${_preferences.distanceAlertThresholdCm.toStringAsFixed(0)} cm',
                  style: LumiTheme.clanMedium(14, color: LumiColors.textDark),
                ),
                _arcadeSlider(
                  value: _preferences.distanceAlertThresholdCm,
                  min: 25,
                  max: 50,
                  accent: LumiColors.badgeAmber,
                  track: LumiColors.secondaryLight,
                  onChanged: (v) => setState(
                    () => _preferences = _preferences.copyWith(distanceAlertThresholdCm: v),
                  ),
                ),
                const SizedBox(height: LumiSpacing.sm),
                Text(
                  'Critical below ${_preferences.criticalDistanceThresholdCm.toStringAsFixed(0)} cm',
                  style: LumiTheme.clanMedium(14, color: LumiColors.textDark),
                ),
                _arcadeSlider(
                  value: _preferences.criticalDistanceThresholdCm,
                  min: 10,
                  max: 30,
                  accent: LumiColors.redAlert,
                  track: LumiColors.coralTrack,
                  onChanged: (v) => setState(
                    () => _preferences = _preferences.copyWith(criticalDistanceThresholdCm: v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LumiSpacing.lg),
          ArcadeCard(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GuardianSectionTitle('Auto Eye Breaks', size: 17),
                      const SizedBox(height: LumiSpacing.xs),
                      Text(
                        'Force 20-20-20 and blink exercises when needed',
                        style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: LumiSpacing.md),
                _ArcadeToggle(
                  value: _preferences.autoEnforceBreaks,
                  onChanged: (v) => setState(
                    () => _preferences = _preferences.copyWith(autoEnforceBreaks: v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LumiSpacing.lg),
          ArcadeCard(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GuardianSectionTitle('Monitoring Style', size: 17),
                const SizedBox(height: LumiSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ArcadeButton(
                        text: 'STRICT',
                        fontSize: 14,
                        variant: isRelaxed ? ArcadeButtonVariant.outline : ArcadeButtonVariant.primary,
                        onTap: () => setState(
                          () => _preferences = _preferences.copyWith(monitoringMode: 'Strict'),
                        ),
                      ),
                    ),
                    const SizedBox(width: LumiSpacing.md),
                    Expanded(
                      child: ArcadeButton(
                        text: 'RELAXED',
                        fontSize: 14,
                        variant: isRelaxed ? ArcadeButtonVariant.primary : ArcadeButtonVariant.outline,
                        onTap: () => setState(
                          () => _preferences = _preferences.copyWith(monitoringMode: 'Relaxed'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LumiSpacing.md),
                Text(
                  isRelaxed
                      ? 'Relaxed: gentler reminders, fewer forced breaks.'
                      : 'Strict: stronger enforcement of distance and blink habits.',
                  style: LumiTheme.clanRegular(12, color: LumiColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: LumiSpacing.xl),
          ArcadeButton(
            text: _saving ? 'SAVING…' : 'SAVE LIMITS',
            onTap: _saving ? null : _savePreferences,
          ),
          const SizedBox(height: LumiSpacing.xl),
        ],
      ),
    );
  }
}

/// Arcade pill toggle — thick border, hard shadow, sliding knob.
class _ArcadeToggle extends StatelessWidget {
  const _ArcadeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = value ? LumiColors.primaryGreen : LumiColors.secondaryLight;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: LumiMotion.fast,
        curve: LumiMotion.easeStandard,
        width: 64,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? LumiColors.secondaryGreen : LumiColors.primaryLight,
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          border: Border.all(color: accent, width: ArcadeSizes.badgeBorder),
          boxShadow: LumiShadows.badge(accent),
        ),
        child: AnimatedAlign(
          duration: LumiMotion.fast,
          curve: LumiMotion.easeStandard,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? LumiColors.primaryGreen : LumiColors.secondaryLight,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
