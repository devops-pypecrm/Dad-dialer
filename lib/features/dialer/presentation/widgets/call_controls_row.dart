import 'package:flutter/material.dart';

class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onTap,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: active ? scheme.primary : (color ?? scheme.surfaceContainerHighest),
            foregroundColor: active ? scheme.onPrimary : scheme.onSurface,
            minimumSize: const Size(56, 56),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
