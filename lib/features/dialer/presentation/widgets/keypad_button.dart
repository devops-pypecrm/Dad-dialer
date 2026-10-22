import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A single round dial-pad key — light gray filled circle, big digit, small
/// letters underneath, flashing brand-green on press. Matches the reference
/// phone-dialer layout rather than Material's default flat text-only
/// keypad.
class KeypadButton extends StatefulWidget {
  const KeypadButton({super.key, required this.digit, this.letters, required this.onTap});

  final String digit;
  final String? letters;
  final VoidCallback onTap;

  @override
  State<KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<KeypadButton> {
  static const _flashDuration = Duration(milliseconds: 220);

  bool _pressed = false;

  void _handleTap() {
    setState(() => _pressed = true);
    widget.onTap();
    // A timed flash, not InkWell's own transient splash -- this needs to
    // stay visible for a deliberate, controllable moment (roughly the
    // start of the digit's flight to the number field), not fade
    // immediately the way a ripple does.
    Future.delayed(_flashDuration, () {
      if (mounted) setState(() => _pressed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      // The circle used to be a hardcoded 72x72 regardless of how much
      // room its grid cell actually had -- fine full-screen, but once this
      // screen started being embedded in a shorter drawer (app.dart's
      // _DialerDrawer) each row's cell could be noticeably under 72px
      // tall, and a fixed-size child inside a flexible cell just overflows
      // instead of shrinking, which is what made the keypad look
      // overlapping/"congested" there. Sizing from the smaller of the
      // cell's own width/height keeps every key circular and makes it
      // shrink gracefully instead.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.hasBoundedWidth && constraints.hasBoundedHeight
              ? (constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight) * 0.82
              : 72.0;
          final diameter = side.clamp(44.0, 72.0);
          final digitStyle = (theme.textTheme.headlineMedium ?? const TextStyle(fontSize: 24)).copyWith(
            fontSize: (diameter * 0.38).clamp(16.0, 28.0),
            color: _pressed ? Colors.white : null,
          );
          final lettersStyle = (theme.textTheme.labelSmall ?? const TextStyle(fontSize: 10)).copyWith(
            fontSize: (diameter * 0.12).clamp(8.0, 11.0),
            letterSpacing: 1,
            color: _pressed ? Colors.white70 : null,
          );
          return Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _handleTap,
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: _flashDuration,
                curve: Curves.easeOut,
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  color: _pressed ? kBrandColor : theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: _flashDuration,
                      curve: Curves.easeOut,
                      style: digitStyle,
                      child: Text(widget.digit),
                    ),
                    if (widget.letters != null)
                      AnimatedDefaultTextStyle(
                        duration: _flashDuration,
                        curve: Curves.easeOut,
                        style: lettersStyle,
                        child: Text(widget.letters!),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
