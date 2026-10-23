import 'package:flutter/material.dart';

import '../../theme/lumi_theme.dart';
import '../../widgets/arcade/arcade.dart';

/// Plain-language explainer for parents (no medical/formula jargon).
class HowLumiWorksScreen extends StatelessWidget {
  const HowLumiWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('How LUMI Works', style: LumiTheme.joyful(20, color: LumiColors.primaryPurple)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(LumiSpacing.lg),
        children: const [
          _Section(
            icon: Icons.zoom_out_map,
            title: 'Keeping a comfy distance',
            body:
                'While your child watches in the Watch Area, LUMI uses the front camera to estimate how far the phone is from their face. About an arm\'s length (30 cm or more) is the comfy zone. Holding the phone very close for a long time can make eyes feel tired, so LUMI gives gentle reminders to move back.',
          ),
          _Section(
            icon: Icons.visibility,
            title: 'Blinking keeps eyes moist',
            body:
                'Every blink spreads a fresh layer of tears over the eye. When children stare at a screen, they often blink much less, and eyes can feel dry. LUMI counts blinks and nudges your child to blink more. The "Blink comfort" badge shows whether blinking looks healthy, a bit low, or very low.',
          ),
          _Section(
            icon: Icons.timer_outlined,
            title: 'Screen-time limits by age',
            body:
                'Younger children get shorter daily limits, and bigger limits unlock as they grow: up to 60 minutes for ages 3–5, 90 minutes for ages 6–8, and 120 minutes for ages 9 and older. You set the exact limit in the Limits tab — it can never go above the max for your child\'s age.',
          ),
          _Section(
            icon: Icons.favorite,
            title: 'The Eye Care Score and Stars',
            body:
                'The score (0–100) goes down a little when viewing is too close or blinks are too few, and goes back up after breaks and blink games. Your child also earns Stars for healthy watching minutes. If screen time goes well past the daily limit, Stars pause until habits are back on track.',
          ),
          _Section(
            icon: Icons.insights,
            title: 'What the badges mean',
            body:
                '"Looking good" means habits in the chosen time range look healthy. "Worth watching" means something is near the edge. "Needs attention" or "Talk to a doctor" means close viewing, low blinking, or long screen time showed up often in that range. You can change the time range (last week up to lifetime) at the top of Usage Analytics.',
          ),
          _Section(
            icon: Icons.local_hospital_outlined,
            title: 'When to see an eye doctor',
            body:
                'LUMI is a habit helper, not a medical diagnosis. If the badges keep warning, or your child squints, rubs their eyes, or complains of headaches or blurry vision, please visit an eye doctor. Use "Find a clinic near you" on the alert card to see LUMI partner clinics and share a visit code.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Section({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LumiSpacing.lg),
      child: ArcadeCard(
        padding: const EdgeInsets.all(LumiSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: LumiColors.primaryPurple),
                const SizedBox(width: LumiSpacing.sm),
                Expanded(child: Text(title, style: LumiTheme.clanMedium(16, color: LumiColors.textDark))),
              ],
            ),
            const SizedBox(height: LumiSpacing.sm),
            Text(body, style: LumiTheme.clanRegular(13, color: LumiColors.textDark, height: 1.45)),
          ],
        ),
      ),
    );
  }
}
