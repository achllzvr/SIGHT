import 'package:flutter/material.dart';

import '../screens/guardian/partnered_professionals_screen.dart';
import '../theme/lumi_theme.dart';
import '../utils/parent_friendly_copy.dart';
import 'arcade/arcade.dart';

class ClinicalTrendAlertCard extends StatelessWidget {
  final Map<String, dynamic>? alert;
  final Map<String, dynamic>? usageThreshold;
  final Map<String, dynamic>? opi;
  final int? childId;

  const ClinicalTrendAlertCard({
    super.key,
    required this.alert,
    this.usageThreshold,
    this.opi,
    this.childId,
  });

  Color _toneFor(String? condition) {
    return switch (condition) {
      'SAFE' => LumiColors.primaryGreen,
      'CAUTION' => LumiColors.badgeAmber,
      'AT_RISK' => const Color(0xFFEA580C),
      'CRITICAL' => LumiColors.redAlert,
      _ => LumiColors.textMuted,
    };
  }

  IconData _iconFor(String? condition) {
    return switch (condition) {
      'SAFE' => Icons.verified_user,
      'CAUTION' => Icons.error_outline,
      'AT_RISK' => Icons.warning_amber_rounded,
      'CRITICAL' => Icons.medical_services_outlined,
      _ => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final condition = alert?['overall_condition'] as String?;
    final tone = _toneFor(condition);
    final showCta = alert?['show_professional_cta'] == true ||
        condition == 'AT_RISK' ||
        condition == 'CRITICAL' ||
        condition == 'CAUTION';
    final opiLevel = opi == null ? null : (opi!['level'] as num?)?.toInt();

    return ArcadeCard(
      padding: const EdgeInsets.all(LumiSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(condition), color: tone, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ParentFriendlyCopy.softenProse(
                    alert?['alert_title']?.toString(),
                    fallback: 'How eyes are doing lately',
                  ),
                  style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
                ),
              ),
              if (condition != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(LumiRadii.pill),
                    border: Border.all(color: tone, width: 2),
                  ),
                  child: Text(
                    ParentFriendlyCopy.conditionLabel(condition),
                    style: LumiTheme.clanMedium(12, color: tone),
                  ),
                ),
            ],
          ),
          const SizedBox(height: LumiSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                'Near vision habits',
                ParentFriendlyCopy.trackLabel(alert?['myopia_status']?.toString()),
              ),
              _pill(
                'Blink comfort',
                ParentFriendlyCopy.trackLabel(alert?['dry_eye_status']?.toString()),
              ),
              if (opiLevel != null)
                _pill('Blink comfort', ParentFriendlyCopy.blinkComfortLabel(opiLevel)),
              if (usageThreshold != null)
                _pill(
                  'Screen time',
                  ParentFriendlyCopy.usageBadgePlain(usageThreshold!['badge']?.toString()),
                ),
            ],
          ),
          const SizedBox(height: LumiSpacing.md),
          Text('What we noticed', style: LumiTheme.clanMedium(13, color: LumiColors.textDark)),
          const SizedBox(height: 4),
          Text(
            ParentFriendlyCopy.softenProse(
              alert?['what_is_wrong_text']?.toString(),
              fallback: 'Not enough eye-care data in this time range yet.',
            ),
            style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: LumiSpacing.sm),
          Text('Why this matters', style: LumiTheme.clanMedium(13, color: LumiColors.textDark)),
          const SizedBox(height: 4),
          Text(
            ParentFriendlyCopy.softenProse(
              alert?['why_showing_clinical_basis_text']?.toString(),
              fallback:
                  'Tips appear once distance, blinking, and screen-time patterns can be checked.',
            ),
            style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.4),
          ),
          if (showCta) ...[
            const SizedBox(height: LumiSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PartneredProfessionalsScreen(childId: childId),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: LumiColors.primaryPurple,
                  side: const BorderSide(color: LumiColors.primaryPurple, width: 3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LumiRadii.md),
                  ),
                ),
                child: Text(
                  'Want to check with an eye doctor?\nFind a clinic near you',
                  textAlign: TextAlign.center,
                  style: LumiTheme.clanMedium(13, color: LumiColors.primaryPurple, height: 1.3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: LumiColors.secondaryLight,
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        border: Border.all(color: LumiColors.outline, width: 2),
      ),
      child: Text('$label: $value', style: LumiTheme.clanRegular(11, color: LumiColors.textDark)),
    );
  }
}
