import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Full-screen, nav-free ask shown before the main app shell whenever Pype
/// Dialer isn't the device's default Phone app yet — matching the reference
/// app's own "Set Default Phone App" screen (own illustration/copy, not
/// their asset, to avoid reusing their art). Deliberately rendered as its
/// own [Scaffold] rather than a banner/dialog layered over
/// `_AuthenticatedShell`, so the bottom nav bar never shows behind it.
class DefaultDialerOnboardingScreen extends StatelessWidget {
  const DefaultDialerOnboardingScreen({super.key, required this.onAgree, required this.onSkip});

  final VoidCallback onAgree;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: kBrandColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk_rounded, size: 64, color: kBrandColor),
              ),
              const Spacer(flex: 2),
              const Text(
                'Set Default Phone App',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kOnDarkPrimaryText),
              ),
              const SizedBox(height: 16),
              const Text(
                'Make Pype Dialer your default Phone app so every call, note and '
                'recording stays linked to the right CRM lead automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.4, color: kOnDarkMutedText),
              ),
              const Spacer(flex: 3),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      onPressed: onAgree,
                      style: FilledButton.styleFrom(
                        backgroundColor: kBrandColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      child: const Text('Yes, I Agree', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: onSkip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kOnDarkPrimaryText,
                        side: const BorderSide(color: kNestedSurfaceColor, width: 1.4),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'You can always do this later from Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: kOnDarkMutedText.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
