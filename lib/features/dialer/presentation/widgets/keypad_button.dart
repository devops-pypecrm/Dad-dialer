import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single dial-pad key in the stock-dialer style: no filled background
/// at rest, just the big digit with its letters underneath, and a soft
/// gray circle that appears under the finger on press and fades out on
/// release.
///
/// The digit fires on touch-*down*, not on tap-up, so fast typing never
/// drops or lags a key — same as a real phone dialer.
class KeypadButton extends StatefulWidget {
  const KeypadButton({super.key, required this.digit, this.letters, required this.onPressed, this.onLongPress});

  final String digit;
  final String? letters;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  State<KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<KeypadButton> {
  bool _pressed = false;

  void _down(TapDownDetails _) {
    HapticFeedback.selectionClick();
    setState(() => _pressed = true);
    widget.onPressed();
  }

  void _release() {
    if (mounted) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      onLongPressEnd: (_) => _release(),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final diameter = (constraints.maxHeight * 0.92).clamp(40.0, 64.0);
            return AnimatedContainer(
              // Snaps in instantly on press, fades out on release.
              duration: _pressed ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pressed ? scheme.onSurface.withValues(alpha: 0.12) : scheme.onSurface.withValues(alpha: 0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.digit,
                    style: TextStyle(
                      fontSize: widget.digit == '*' ? 30 : 26,
                      height: 1.05,
                      fontWeight: FontWeight.w400,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(
                    height: 11,
                    child: widget.digit == '1'
                        ? Icon(Icons.voicemail, size: 11, color: scheme.onSurfaceVariant)
                        : Text(
                            widget.letters ?? '',
                            style: TextStyle(fontSize: 8.5, letterSpacing: 0.6, color: scheme.onSurfaceVariant),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
