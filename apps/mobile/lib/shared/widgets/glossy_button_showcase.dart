import 'package:flutter/material.dart';

import 'glossy_button.dart';

/// Reference screen for glossy 3D button presets (dev / design review).
class GlossyButtonShowcase extends StatelessWidget {
  const GlossyButtonShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Glossy buttons')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlossyButton.startJourney(onPressed: () {}),
          const SizedBox(height: 12),
          GlossyButton.profileSettings(onPressed: () {}),
          const SizedBox(height: 12),
          GlossyButton.notifications(onPressed: () {}, badgeCount: 3),
          const SizedBox(height: 12),
          GlossyButton.exploreNow(onPressed: () {}),
          const SizedBox(height: 12),
          GlossyButton.logOut(onPressed: () {}),
          const SizedBox(height: 24),
          GlossyButton(
            title: 'Teal → Blue',
            icon: Icons.water_rounded,
            variant: GlossyButtonVariant.tealBlue,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          GlossyButton(
            title: 'Blue → Purple',
            icon: Icons.auto_awesome_rounded,
            variant: GlossyButtonVariant.bluePurple,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          GlossyButton(
            title: 'Orange → Red',
            icon: Icons.local_fire_department_rounded,
            variant: GlossyButtonVariant.orangeRed,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          GlossyButton(
            title: 'Disabled',
            icon: Icons.lock_rounded,
            variant: GlossyButtonVariant.neutral,
            disabled: true,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
