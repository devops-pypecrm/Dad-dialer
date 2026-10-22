import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_normalizer.dart';
import '../../../contacts/data/contacts_repository.dart';
import '../../../contacts/domain/device_contact.dart';
import '../../../contacts/providers/contacts_provider.dart';
import '../../../leads/domain/crm_lead.dart';
import '../../../leads/providers/cached_leads_provider.dart';
import '../../../settings/providers/call_log_name_preference_provider.dart';
import '../../data/telecom_bridge.dart';
import '../../providers/call_guard.dart';
import '../widgets/keypad_button.dart';
import '../widgets/lead_match_chip.dart';

/// One row in the dial pad's live-matching suggestions panel.
typedef _Suggestion = ({String name, String number});

class DialPadScreen extends ConsumerStatefulWidget {
  const DialPadScreen({super.key, this.onNumberChanged, this.showSuggestionsPanel = true});

  /// Fired whenever the typed number changes (append, backspace, or tapping
  /// a suggestion) -- lets an embedding parent (the half-screen dialer
  /// drawer in `app.dart`) mirror the digits elsewhere on screen, e.g. to
  /// drive the recents list's own live-match view behind the drawer.
  final ValueChanged<String>? onNumberChanged;

  /// The drawer embeds its own live-match list (styled like the call log,
  /// behind the drawer) instead of this screen's compact suggestions card,
  /// so it passes false here to avoid showing matches twice.
  final bool showSuggestionsPanel;

  @override
  ConsumerState<DialPadScreen> createState() => _DialPadScreenState();
}

class _DialPadScreenState extends ConsumerState<DialPadScreen> with TickerProviderStateMixin {
  String _number = '';

  static const _keys = [
    ['1', ''],
    ['2', 'ABC'],
    ['3', 'DEF'],
    ['4', 'GHI'],
    ['5', 'JKL'],
    ['6', 'MNO'],
    ['7', 'PQRS'],
    ['8', 'TUV'],
    ['9', 'WXYZ'],
    ['*', ''],
    ['0', '+'],
    ['#', ''],
  ];

  // One GlobalKey per key so a tap can find that exact button's on-screen
  // position to animate from -- the number display's own key is the
  // animation's destination.
  final Map<String, GlobalKey> _keypadKeys = {for (final k in _keys) k[0]: GlobalKey()};
  final _numberDisplayKey = GlobalKey();
  final List<AnimationController> _flyingDigitControllers = [];

  @override
  void dispose() {
    for (final controller in _flyingDigitControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The digit only actually joins [_number] once its flying clone lands
  /// (see [_flyDigitToDisplay]'s `onLand`) -- it should look like the
  /// number itself is what traveled from the key into the field, not a
  /// decorative copy running alongside a field that already updated.
  void _append(String digit) {
    final animated = _flyDigitToDisplay(digit, onLand: () => _setNumber(_number + digit));
    if (!animated) {
      // Couldn't measure a real start/end position (e.g. called before the
      // first frame laid out) -- update immediately rather than silently
      // dropping the keypress.
      _setNumber(_number + digit);
    }
  }

  void _setNumber(String value) {
    setState(() => _number = value);
    widget.onNumberChanged?.call(_number);
  }

  /// Spawns a copy of the tapped digit as an Overlay entry and animates it
  /// from the button's actual on-screen position to the number display's.
  /// Stays fully opaque for almost the whole flight (this should read as
  /// the digit traveling there, not fading away mid-flight) and only
  /// shrinks/fades in the last moment, timed to disappear in the same
  /// frame [onLand] fires and the real number takes its place -- a
  /// hand-off, not two things briefly overlapping. Returns false if the
  /// positions couldn't be measured, so the caller can fall back to an
  /// immediate update instead of silently doing nothing.
  bool _flyDigitToDisplay(String digit, {required VoidCallback onLand}) {
    final keyContext = _keypadKeys[digit]?.currentContext;
    final targetContext = _numberDisplayKey.currentContext;
    if (keyContext == null || targetContext == null) return false;

    final keyBox = keyContext.findRenderObject() as RenderBox?;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    if (keyBox == null || targetBox == null || !keyBox.attached || !targetBox.attached) return false;

    final startOffset = keyBox.localToGlobal(keyBox.size.center(Offset.zero));
    final endOffset = targetBox.localToGlobal(targetBox.size.center(Offset.zero));

    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _flyingDigitControllers.add(controller);
    final position = Tween<Offset>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );
    // Fully visible for most of the flight -- only the last 12% fades/
    // shrinks, right as it lands, instead of dissolving away mid-air.
    final landing = CurvedAnimation(parent: controller, curve: const Interval(0.88, 1.0));
    final opacity = Tween<double>(begin: 1, end: 0).animate(landing);
    final scale = Tween<double>(begin: 1, end: 0.6).animate(landing);

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Positioned(
          left: position.value.dx - 14,
          top: position.value.dy - 18,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.value,
              child: Transform.scale(
                scale: scale.value,
                child: Text(
                  digit,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: kBrandColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    controller.forward().whenComplete(() {
      onLand();
      entry.remove();
      _flyingDigitControllers.remove(controller);
      controller.dispose();
    });
    return true;
  }

  /// Live-matching suggestions as you type, sourced from CRM leads or
  /// device contacts depending on the same "Show CRM lead names in Call
  /// Logs" toggle Settings already exposes (Dad-dialer/lib/features/
  /// settings/providers/call_log_name_preference_provider.dart) -- one
  /// toggle, one consistent "which identity source wins" answer, instead
  /// of a second independent setting for the same underlying question.
  List<_Suggestion> _matchingSuggestions({
    required bool preferCrm,
    required List<CrmLead> leads,
    required List<DeviceContact> contacts,
  }) {
    // Below this, a prefix match is too broad to be a useful suggestion
    // (matches nearly everything) -- same floor the CRM lead index uses
    // for a real match, just applied a level earlier here.
    if (_number.length < 2) return const [];
    final typed = normalizePhoneNumber(_number);
    if (typed.length < 2) return const [];

    bool startsWithTyped(String raw) => normalizePhoneNumber(raw).startsWith(typed);

    final results = <_Suggestion>[];
    if (preferCrm) {
      for (final lead in leads) {
        final candidates = [lead.phone, lead.secondaryPhone].whereType<String>();
        final match = candidates.where(startsWithTyped).firstOrNull;
        if (match != null) {
          results.add((name: lead.displayName, number: match));
          if (results.length >= 5) break;
        }
      }
    } else {
      for (final contact in contacts) {
        final match = contact.phones.where(startsWithTyped).firstOrNull;
        if (match != null) {
          results.add((name: contact.displayName, number: match));
          if (results.length >= 5) break;
        }
      }
    }

    // A single suggestion that's already an exact match for what's typed
    // adds nothing -- the CRM lead chip / matchedContact context elsewhere
    // on this screen already covers "you've typed a known number in full".
    if (results.length == 1 && normalizePhoneNumber(results.first.number) == typed) {
      return const [];
    }
    return results;
  }

  Widget _buildSuggestionsPanel(List<_Suggestion> suggestions) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      curve: Curves.easeOut,
      child: suggestions.isEmpty
          ? const SizedBox(width: double.infinity)
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 176),
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: suggestions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
                      title: Text(suggestion.name),
                      subtitle: Text(suggestion.number),
                      onTap: () => _setNumber(suggestion.number),
                    );
                  },
                ),
              ),
            ),
    );
  }

  void _backspace() {
    if (_number.isEmpty) return;
    final removedDigit = _number[_number.length - 1];
    // Removed immediately (backspace should feel instant/responsive for
    // fast corrections, unlike typing where the "arrival" is the point) --
    // the fall animation is a decorative parting effect on the digit that
    // just left, not something the field waits on.
    _setNumber(_number.substring(0, _number.length - 1));
    _fallDigitFromDisplay(removedDigit);
  }

  /// Spawns a copy of the just-deleted digit and animates it falling away
  /// from the number display, accelerating downward and fading out --
  /// mirrors [_flyDigitToDisplay]'s Overlay-entry approach, reversed.
  void _fallDigitFromDisplay(String digit) {
    final targetContext = _numberDisplayKey.currentContext;
    if (targetContext == null) return;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    if (targetBox == null || !targetBox.attached) return;

    final startOffset = targetBox.localToGlobal(targetBox.size.center(Offset.zero));
    final endOffset = startOffset + const Offset(0, 130);

    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _flyingDigitControllers.add(controller);
    final position = Tween<Offset>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeIn),
    );
    final opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: controller, curve: const Interval(0.3, 1.0)),
    );

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Positioned(
          left: position.value.dx - 14,
          top: position.value.dy - 18,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.value,
              child: Text(
                digit,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    controller.forward().whenComplete(() {
      entry.remove();
      _flyingDigitControllers.remove(controller);
      controller.dispose();
    });
  }

  Future<void> _call() async {
    if (_number.isEmpty) return;
    if (!mounted || !await ensureCanPlaceCall(ref, context)) return;
    await ref.read(telecomBridgeProvider).placeCall(_number);
  }

  Future<void> _addNumber() async {
    final number = _number;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Number'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Name', hintText: number),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !mounted) return;

    final added = await ref.read(contactsRepositoryProvider).addContact(name: name, number: number);
    if (!mounted) return;
    if (added == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save — contacts permission denied.')),
      );
      return;
    }
    ref.invalidate(contactsListProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved $name to contacts.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(cachedLeadsProvider);
    final matchedLead = leadsAsync.valueOrNull != null && _number.isNotEmpty
        ? ref.read(cachedLeadsProvider.notifier).matchLead(_number)
        : null;

    final contacts = ref.watch(contactsListProvider).valueOrNull ?? const [];
    final matchedContact = _number.isEmpty
        ? null
        : contacts.where((c) => c.phones.any((p) => phoneNumbersMatch(p, _number))).firstOrNull;
    final canAddNumber = _number.isNotEmpty && matchedLead == null && matchedContact == null;

    final preferCrmName = ref.watch(preferCrmNameInCallLogsProvider).valueOrNull ?? true;
    final suggestions = _matchingSuggestions(
      preferCrm: preferCrmName,
      leads: leadsAsync.valueOrNull ?? const [],
      contacts: contacts,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            // Only takes up space when there's actually a chip to show --
            // reserving a fixed 40px for it unconditionally (the old
            // layout) ate into the keypad's share of a now-shorter drawer
            // for no reason on the (common) case of no match yet.
            if (matchedLead != null) ...[
              SizedBox(height: 36, child: LeadMatchChip(lead: matchedLead)),
              const SizedBox(height: 4),
            ],
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _number.isEmpty ? ' ' : _number,
                    key: _numberDisplayKey,
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (canAddNumber) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _addNumber,
                      child: const Text('Add Number', style: TextStyle(color: kBrandColor)),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.showSuggestionsPanel) _buildSuggestionsPanel(suggestions),
            Expanded(
              flex: 5,
              // A Column of Expanded Rows (not GridView.count) so the
              // keypad always fits exactly in the space it's given --
              // GridView.count sizes each cell as a square derived from
              // available *width*, so on a screen where 4 rows of
              // width-sized cells add up to more height than this Expanded
              // actually has, it silently clips the last row (no scrolling,
              // no overflow error) instead of shrinking to fit.
              child: Column(
                children: [
                  for (var row = 0; row < _keys.length; row += 3)
                    Expanded(
                      child: Row(
                        children: [
                          for (final key in _keys.sublist(row, row + 3))
                            Expanded(
                              child: KeypadButton(
                                key: _keypadKeys[key[0]],
                                digit: key[0],
                                letters: key[1].isEmpty ? null : key[1],
                                onTap: () => _append(key[0]),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: FloatingActionButton(
                        heroTag: 'call',
                        backgroundColor: kBrandColor,
                        onPressed: _call,
                        child: const Icon(Icons.call, color: Colors.white),
                      ),
                    ),
                  ),
                  if (_number.isNotEmpty)
                    Positioned(
                      right: 24,
                      child: IconButton(
                        onPressed: _backspace,
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
