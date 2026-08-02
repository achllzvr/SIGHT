import 'package:flutter/material.dart';

import '../theme/lumi_theme.dart';
import 'rounded_card.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? status;
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: LumiSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LumiColors.textMuted,
                    ),
              ),
              const SizedBox(height: LumiSpacing.md),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: LumiColors.safeText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: LumiSpacing.md),
                Text(subtitle!, style: const TextStyle(color: LumiColors.accent, fontSize: 12)),
              ]
            ],
          ),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: LumiSpacing.sm, horizontal: 10),
              decoration: BoxDecoration(
                color: LumiColors.greenSoft,
                borderRadius: BorderRadius.circular(LumiRadii.pill),
                border: Border.all(color: LumiColors.outline),
              ),
              child: Text(
                status!,
                style: const TextStyle(
                  color: LumiColors.safeText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
        ],
      ),
    );
  }
}
