import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../contacts/domain/device_contact.dart';
import '../../../contacts/providers/contacts_provider.dart';
import '../../../dialer/data/telecom_bridge.dart';
import '../../../dialer/providers/call_guard.dart';
import '../../../dialer/providers/default_dialer_role_provider.dart';
import '../../../leads/domain/crm_lead.dart';
import '../../../leads/providers/cached_leads_provider.dart';
import '../../../settings/providers/call_log_name_preference_provider.dart';
import '../../domain/call_log_entry.dart';
import '../../providers/recents_provider.dart' show recentsProvider, recordedCallIndexProvider;

class RecentsScreen extends ConsumerStatefulWidget {
  const RecentsScreen({super.key, this.dialedDigits = '', this.bottomInset = 0});

  /// The number typed on the shell's keypad panel (`app.dart`). While it's
  /// non-empty this screen swaps the "Calls" header + call history for the
  /// typed number shown big at the top, with live matches below it — kept
  /// even while the keypad is collapsed, until the number is cleared.
  final String dialedDigits;

  /// How much of the bottom of this screen the keypad panel currently
  /// covers, so lists can still scroll their last rows into view above it.
  final double bottomInset;

  @override
  ConsumerState<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends ConsumerState<RecentsScreen> {
  bool _missedOnly = false;

  @override
  Widget build(BuildContext context) {
    if (widget.dialedDigits.isNotEmpty) {
      return SafeArea(
        bottom: false,
        child: _DialedNumberView(digits: widget.dialedDigits, bottomInset: widget.bottomInset),
      );
    }

    final recentsAsync = ref.watch(recentsProvider);
    final listPadding = EdgeInsets.only(bottom: widget.bottomInset + 88);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _CallsHeader(
            missedOnly: _missedOnly,
            hasMissedCalls: recentsAsync.valueOrNull?.any((e) => e.type == CallLogType.missed) ?? false,
            onChanged: (missedOnly) => setState(() => _missedOnly = missedOnly),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(recentsProvider.notifier).refresh(),
              child: recentsAsync.when(
                data: (entries) {
                  final filtered =
                      _missedOnly ? entries.where((e) => e.type == CallLogType.missed).toList() : entries;
                  return filtered.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(child: Text(_missedOnly ? 'No missed calls.' : 'No calls yet.')),
                            ),
                          ],
                        )
                      : _GroupedCallList(entries: filtered, padding: listPadding);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _RecentsError(error: error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One live match for the typed number. [nameMatch]/[numberMatch] are the
/// character ranges to highlight green (null = that part didn't match).
typedef _DialMatch = ({String name, String number, (int, int)? nameMatch, (int, int)? numberMatch});

/// What replaces the call history while a number is typed: the number
/// itself, large and centered where the "Calls" header was, then either
/// matching contacts/leads or — when nothing matches — the "New contact" /
/// "Add to existing contact" shortcuts for saving it.
class _DialedNumberView extends ConsumerWidget {
  const _DialedNumberView({required this.digits, required this.bottomInset});

  final String digits;
  final double bottomInset;

  static const _t9 = {
    'a': '2', 'b': '2', 'c': '2', 'd': '3', 'e': '3', 'f': '3',
    'g': '4', 'h': '4', 'i': '4', 'j': '5', 'k': '5', 'l': '5',
    'm': '6', 'n': '6', 'o': '6', 'p': '7', 'q': '7', 'r': '7', 's': '7',
    't': '8', 'u': '8', 'v': '8', 'w': '9', 'x': '9', 'y': '9', 'z': '9',
  };

  /// Range of the first word in [name] whose keypad spelling starts with
  /// [typed] (e.g. "5" matches "Kozhikod", "Jaggoos"), as stock dialers do.
  static (int, int)? _t9NameMatch(String name, String typed) {
    final lower = name.toLowerCase();
    for (final word in RegExp(r'[a-z0-9]+').allMatches(lower)) {
      final w = word.group(0)!;
      if (w.length < typed.length) continue;
      var ok = true;
      for (var i = 0; i < typed.length && ok; i++) {
        final ch = w[i];
        ok = (_t9[ch] ?? ch) == typed[i];
      }
      if (ok) return (word.start, word.start + typed.length);
    }
    return null;
  }

  /// Range in the *formatted* [number] covering the digits that contain
  /// [typed] anywhere, skipping spaces/dashes/+ in between.
  static (int, int)? _numberMatch(String number, String typed) {
    final positions = <int>[];
    final buffer = StringBuffer();
    for (var i = 0; i < number.length; i++) {
      final c = number[i];
      if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
        positions.add(i);
        buffer.write(c);
      }
    }
    final at = buffer.toString().indexOf(typed);
    if (at < 0) return null;
    return (positions[at], positions[at + typed.length - 1] + 1);
  }

  List<_DialMatch> _matches(WidgetRef ref) {
    // '*', '#', '+' in the typed string make it a code/raw dial, not a
    // search — show the save shortcuts instead of guessing.
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return const [];

    final preferCrm = ref.watch(preferCrmNameInCallLogsProvider).valueOrNull ?? true;
    final candidates = <({String name, List<String> numbers})>[];
    if (preferCrm) {
      for (final CrmLead lead in ref.watch(cachedLeadsProvider).valueOrNull ?? const <CrmLead>[]) {
        candidates.add((name: lead.displayName, numbers: [lead.phone, lead.secondaryPhone].whereType<String>().toList()));
      }
    } else {
      for (final DeviceContact contact in ref.watch(contactsListProvider).valueOrNull ?? const <DeviceContact>[]) {
        candidates.add((name: contact.displayName, numbers: contact.phones));
      }
    }

    final byName = <_DialMatch>[];
    final byNumber = <_DialMatch>[];
    for (final c in candidates) {
      if (c.numbers.isEmpty) continue;
      final nameMatch = _t9NameMatch(c.name, digits);
      for (final number in c.numbers) {
        final numberMatch = _numberMatch(number, digits);
        if (nameMatch != null) {
          byName.add((name: c.name, number: number, nameMatch: nameMatch, numberMatch: numberMatch));
          break;
        }
        if (numberMatch != null) {
          byNumber.add((name: c.name, number: number, nameMatch: null, numberMatch: numberMatch));
          break;
        }
      }
      if (byName.length + byNumber.length >= 60) break;
    }
    return [...byName, ...byNumber];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = _matches(ref);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
          child: SizedBox(
            width: double.infinity,
            height: 40,
            // Long numbers shrink to fit on one line rather than wrapping.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(digits, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: scheme.onSurface)),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: bottomInset + 88),
            children: matches.isEmpty
                ? [
                    _DialActionTile(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'New contact',
                      onTap: () => ref.read(telecomBridgeProvider).openNewContact(digits),
                    ),
                    _DialActionTile(
                      icon: Icons.contact_page_outlined,
                      label: 'Add to existing contact',
                      onTap: () => ref.read(telecomBridgeProvider).openAddToContact(digits),
                    ),
                  ]
                : [for (final match in matches) _DialMatchTile(match: match)],
          ),
        ),
      ],
    );
  }
}

class _DialActionTile extends StatelessWidget {
  const _DialActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)))),
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.onSurface),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// A matching contact/lead: name on top, number below, with the part that
/// matched what's typed tinted green. Tapping calls it.
class _DialMatchTile extends ConsumerWidget {
  const _DialMatchTile({required this.match});

  final _DialMatch match;

  static List<TextSpan> _highlighted(String text, (int, int)? range, TextStyle base) {
    if (range == null) return [TextSpan(text: text, style: base)];
    final (start, end) = range;
    return [
      TextSpan(text: text.substring(0, start), style: base),
      TextSpan(text: text.substring(start, end), style: base.copyWith(color: kBrandColor)),
      TextSpan(text: text.substring(end), style: base),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final nameStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: scheme.onSurface);
    final numberStyle = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);
    return InkWell(
      onTap: () async {
        if (!await ensureCanPlaceCall(ref, context)) return;
        await ref.read(telecomBridgeProvider).placeCall(match.number);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: _highlighted(match.name, match.nameMatch, nameStyle)), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text.rich(TextSpan(children: _highlighted(match.number, match.numberMatch, numberStyle))),
                ],
              ),
            ),
            Icon(Icons.call_outlined, size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Big "Calls" title + the All/Missed segmented filter + search/overflow
/// actions — built into the screen itself rather than a Material [AppBar]
/// so it can match the reference's exact proportions (title below the
/// control row, not beside it).
class _CallsHeader extends StatelessWidget {
  const _CallsHeader({required this.missedOnly, required this.hasMissedCalls, required this.onChanged});

  final bool missedOnly;
  final bool hasMissedCalls;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Stack rather than a Row so the segmented control centers on
          // the full screen width -- a Row with the icon buttons as
          // trailing siblings skews the "center" of the leftover space
          // instead of the screen, which is what left the control visibly
          // off-center next to the reference.
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: _SegmentedFilter(missedOnly: missedOnly, hasMissedCalls: hasMissedCalls, onChanged: onChanged),
                ),
                Positioned(
                  right: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 4, bottom: 8),
            child: Text('Calls', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SegmentedFilter extends StatelessWidget {
  const _SegmentedFilter({required this.missedOnly, required this.hasMissedCalls, required this.onChanged});

  final bool missedOnly;
  final bool hasMissedCalls;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentButton(label: 'All', selected: !missedOnly, onTap: () => onChanged(false)),
          _SegmentButton(
            label: 'Missed',
            selected: missedOnly,
            showDot: hasMissedCalls,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.label, required this.selected, required this.onTap, this.showDot = false});

  final String label;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kBrandColor.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? kBrandColor : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (showDot)
              Positioned(
                right: -8,
                top: -2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `getCallLog` returns a typed `permission_denied` PlatformException when
/// READ_CALL_LOG isn't granted yet — that permission is only ever requested
/// via "Set as default dialer" (see `DialerPermissions`'s doc comment), so
/// this is the expected state for anyone who hasn't done that step yet, not
/// a bug. Show a real prompt instead of the raw exception text.
class _RecentsError extends ConsumerWidget {
  const _RecentsError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPermissionDenied = error is PlatformException &&
        (error as PlatformException).code == 'permission_denied';

    if (!isPermissionDenied) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('Could not load recents: $error')),
          ),
        ],
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Pype Dialer needs to be your default Phone app to read call history.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await ref.read(defaultDialerRoleProvider.notifier).requestRole();
                  ref.invalidate(recentsProvider);
                },
                child: const Text('Set as default dialer'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Splits the already date-DESC-sorted entries into Today/Yesterday/exact-date
/// sections and renders each with its own header, matching the reference.
class _GroupedCallList extends StatelessWidget {
  const _GroupedCallList({required this.entries, this.padding});

  final List<CallLogEntry> entries;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sections = <String, List<CallLogEntry>>{};
    for (final entry in entries) {
      final label = _sectionLabel(entry.date, now);
      sections.putIfAbsent(label, () => []).add(entry);
    }

    return ListView.builder(
      padding: padding,
      itemCount: sections.length,
      itemBuilder: (context, sectionIndex) {
        final label = sections.keys.elementAt(sectionIndex);
        final sectionEntries = sections[label]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final entry in sectionEntries) _RecentTile(entry: entry, sectionLabel: label),
          ],
        );
      },
    );
  }

  static String _sectionLabel(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(date);
  }
}

class _RecentTile extends ConsumerWidget {
  const _RecentTile({required this.entry, required this.sectionLabel});

  final CallLogEntry entry;
  final String sectionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchedLead = entry.number != null
        ? ref.read(cachedLeadsProvider.notifier).matchLead(entry.number!)
        : null;
    // ON: CRM lead name wins when a number matches both a CRM lead and a
    // device contact. OFF: the device contact name wins instead. See
    // PreferCrmNameInCallLogs's doc comment.
    final preferCrmName = ref.watch(preferCrmNameInCallLogsProvider).valueOrNull ?? true;
    final resolvedName = preferCrmName ? (matchedLead?.displayName ?? entry.cachedName) : (entry.cachedName ?? matchedLead?.displayName);
    final title = resolvedName ?? entry.number ?? 'Unknown';
    final isMissed = entry.type == CallLogType.missed;
    // Real Tier 0 signal (see RecordingStatusStore.kt) — never shown for a
    // call this device didn't actually confirm a native recording for.
    final hasRecording = ref.watch(recordedCallIndexProvider).valueOrNull?.hasRecording(entry.number, entry.date) ?? false;
    final isRejected = entry.type == CallLogType.rejected;

    return InkWell(
      onTap: entry.number == null
          ? null
          : () async {
              if (!await ensureCanPlaceCall(ref, context)) return;
              await ref.read(telecomBridgeProvider).placeCall(entry.number!);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(_directionIcon(entry.type), color: _directionColor(entry.type), size: 18),
            const SizedBox(width: 8),
            _Avatar(name: resolvedName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isMissed || isRejected ? Colors.redAccent : null,
                    ),
                  ),
                  if (entry.simSlot != null || hasRecording || (resolvedName != null && entry.number != null)) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (entry.simSlot != null) ...[
                          _SimChip(slot: entry.simSlot!, label: entry.simLabel),
                          const SizedBox(width: 6),
                        ],
                        if (hasRecording) ...[
                          const _RecordedBadge(),
                          const SizedBox(width: 6),
                        ],
                        if (resolvedName != null && entry.number != null)
                          Flexible(
                            child: Text(
                              entry.number!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(entry.date, sectionLabel),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusLabel(entry),
                  style: TextStyle(
                    fontSize: 12,
                    color: isMissed || isRejected ? Colors.redAccent : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            _InfoButton(entry: entry),
          ],
        ),
      ),
    );
  }

  static String _timeLabel(DateTime date, String sectionLabel) {
    if (sectionLabel == 'Today') return DateFormat('h:mm a').format(date);
    return sectionLabel; // "Yesterday" or the exact-date label, matching the group header.
  }

  static String _statusLabel(CallLogEntry entry) {
    final type = _typeLabel(entry.type);
    if (entry.durationSeconds > 0 && entry.type != CallLogType.missed) {
      return '$type · ${_formatDuration(entry.durationSeconds)}';
    }
    return type;
  }

  static String _typeLabel(CallLogType type) => switch (type) {
        CallLogType.incoming => 'Incoming',
        CallLogType.outgoing => 'Outgoing',
        CallLogType.missed => 'Missed',
        CallLogType.rejected => 'Rejected',
        CallLogType.blocked => 'Blocked',
        CallLogType.unknown => 'Call',
      };

  static IconData _directionIcon(CallLogType type) => switch (type) {
        CallLogType.outgoing => Icons.call_made,
        CallLogType.incoming => Icons.call_received,
        CallLogType.missed => Icons.call_received,
        CallLogType.rejected => Icons.call_end,
        CallLogType.blocked => Icons.block,
        CallLogType.unknown => Icons.call,
      };

  static Color _directionColor(CallLogType type) => switch (type) {
        CallLogType.outgoing => kBrandColor,
        CallLogType.incoming => kBrandColor,
        CallLogType.missed => Colors.redAccent,
        CallLogType.rejected => Colors.redAccent,
        CallLogType.blocked => Colors.redAccent,
        CallLogType.unknown => Colors.grey,
      };

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes}m ${remaining}s';
  }
}

/// Colored initial circle for a resolved name, or a plain gray silhouette
/// for an unrecognized number — this app has no contact-photo support
/// (Android Contacts photo lookup isn't wired up), so a real photo was
/// never an option here, unlike the reference mockup's avatars.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String? name;

  static const _palette = [
    Color(0xFFE57373),
    Color(0xFF64B5F6),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFF4DB6AC),
    Color(0xFFF06292),
    Color(0xFFA1887F),
  ];

  @override
  Widget build(BuildContext context) {
    const size = 46.0;
    if (name == null || name!.trim().isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 26),
      );
    }
    final trimmed = name!.trim();
    final color = _palette[trimmed.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(
        trimmed[0].toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}

/// Small pill showing which SIM placed/received the call — only rendered
/// when [CallLogReader.kt] resolved one (real multi-SIM devices only, see
/// its doc comment on why a single-SIM phone never gets one of these).
class _SimChip extends StatelessWidget {
  const _SimChip({required this.slot, required this.label});

  final int slot;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = slot == 0 ? kBrandColor : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            child: Text(
              '${slot + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label ?? 'SIM ${slot + 1}',
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Small red mic icon — shown ONLY when `RecordingStatusStore.kt` (native)
/// confirms this specific call actually got a Tier 0 recording uploaded.
/// Never a decorative default; see recordedCallIndexProvider's doc comment.
class _RecordedBadge extends StatelessWidget {
  const _RecordedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Icon(Icons.mic, size: 10, color: Colors.white),
    );
  }
}

/// Outlined "i" button — opens a sheet with the full number and quick
/// actions, rather than placing a call immediately like tapping the row
/// itself does.
class _InfoButton extends ConsumerWidget {
  const _InfoButton({required this.entry});

  final CallLogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showDetails(context, ref),
      customBorder: const CircleBorder(),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.info_outline, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    final number = entry.number;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(number ?? 'Unknown number', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(DateFormat('MMM d, yyyy • h:mm a').format(entry.date)),
            ),
            if (number != null)
              ListTile(
                leading: const Icon(Icons.call, color: kBrandColor),
                title: const Text('Call'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (!await ensureCanPlaceCall(ref, context)) return;
                  await ref.read(telecomBridgeProvider).placeCall(number);
                },
              ),
            if (number != null)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy number'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: number));
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
