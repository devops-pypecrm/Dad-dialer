import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/telecom_bridge.dart';
import 'keypad_button.dart';

/// Call-capable SIMs, used to decide between one call button per SIM
/// (dual-SIM phones) and a single default-SIM button.
final simAccountsProvider = FutureProvider<List<({int index, String label})>>((ref) async {
  try {
    return await ref.watch(telecomBridgeProvider).getSimAccounts();
  } on PlatformException {
    return const [];
  }
});

/// The compact keypad panel that slides up over the Calls tab (hosted by
/// the shell in `app.dart`, which owns the open/close animation and the
/// typed number). It deliberately has no number field of its own — the
/// typed number shows big at the top of the screen *above* the panel
/// instead, the way the stock dialer does it.
///
/// Layout, top to bottom: drag handle, 4x3 keys, then an action row of
/// [collapse keypad] [call per SIM...] [backspace].
class DialerKeypadSheet extends ConsumerWidget {
  const DialerKeypadSheet({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onCollapse,
    required this.onCall,
    this.onDragUpdate,
    this.onDragEnd,
  });

  /// Total panel height (handle + keys + action row), not counting the
  /// bottom nav bar below it. The shell needs this for its slide math.
  static const double height = _handleHeight + _inputHeight + _rowHeight * 4 + _actionRowHeight + 8;

  static const double _inputHeight = 52;

  static const double _handleHeight = 22;
  static const double _rowHeight = 50;
  static const double _actionRowHeight = 60;

  static const _keys = [
    ['1', ''], ['2', 'ABC'], ['3', 'DEF'],
    ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
    ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
    ['*', ''], ['0', '+'], ['#', ''],
  ];

  /// The typed number. A real text field (with the soft keyboard turned
  /// off) so the cursor can be moved and the text selected, cut, copied and
  /// pasted with the normal long-press menu.
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCollapse;

  /// Called with the chosen SIM's index, or null for "system default".
  final ValueChanged<int?> onCall;

  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sims = ref.watch(simAccountsProvider).valueOrNull ?? const [];

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            // Dragging anywhere on the handle strip drags the whole panel.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: SizedBox(
                height: _handleHeight,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: _inputHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  showCursor: true,
                  keyboardType: TextInputType.none,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: scheme.onSurface, letterSpacing: 0.5),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+*#,;]'))],
                  decoration: InputDecoration(
                    hintText: 'Enter number',
                    hintStyle: TextStyle(fontSize: 22, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (var row = 0; row < _keys.length; row += 3)
                    SizedBox(
                      height: _rowHeight,
                      child: Row(
                        children: [
                          for (final key in _keys.sublist(row, row + 3))
                            Expanded(
                              child: KeypadButton(
                                digit: key[0],
                                letters: key[1].isEmpty ? null : key[1],
                                onPressed: () => onDigit(key[0]),
                                // Long-press 0 swaps the 0 it just typed for '+'.
                                onLongPress: key[0] == '0'
                                    ? () {
                                        onBackspace();
                                        onDigit('+');
                                      }
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: _actionRowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onCollapse,
                      tooltip: 'Hide keypad',
                      icon: Icon(Icons.dialpad, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    if (sims.length > 1)
                      for (final sim in sims) ...[
                        Expanded(child: _CallPill(label: sim.label, onTap: () => onCall(sim.index))),
                        if (sim != sims.last) const SizedBox(width: 10),
                      ]
                    else
                      Expanded(child: _CallPill(label: sims.firstOrNull?.label ?? 'Call', onTap: () => onCall(null))),
                    const SizedBox(width: 4),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) =>
                          _BackspaceButton(enabled: value.text.isNotEmpty, onTap: onBackspace, onLongPress: onClear),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallPill extends StatelessWidget {
  const _CallPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kBrandColor,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        icon: const Icon(Icons.call, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

/// Dimmed and inert while nothing is typed; tap deletes one character,
/// long-press clears the whole number.
class _BackspaceButton extends StatelessWidget {
  const _BackspaceButton({required this.enabled, required this.onTap, required this.onLongPress});

  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkResponse(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      onLongPress: enabled
          ? () {
              HapticFeedback.mediumImpact();
              onLongPress();
            }
          : null,
      radius: 24,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.backspace, size: 22, color: enabled ? color : color.withValues(alpha: 0.35)),
      ),
    );
  }
}
