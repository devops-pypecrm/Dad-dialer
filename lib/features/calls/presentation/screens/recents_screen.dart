import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_normalizer.dart';
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
  const RecentsScreen({super.key, this.dialerOpen = false, this.dialedDigits = ''});

  /// True while the half-screen dial pad drawer (`app.dart`) is open —
  /// hides this screen's own "Calls" title + All/Missed control for as
  /// long as the drawer is up, matching the reference behavior where the
  /// header blanks out rather than staying put behind the drawer.
  final bool dialerOpen;

  /// Mirrors the drawer's currently typed number. Once non-empty, the list
  /// normally showing call history switches to live-matching contacts/
  /// leads instead, rendered with the same row look as a call log entry.
  final String dialedDigits;

  @override
  ConsumerState<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends ConsumerState<RecentsScreen> {
  bool _missedOnly = false;

  @override
  Widget build(BuildContext context) {
    final recentsAsync = ref.watch(recentsProvider);
    final isDialing = widget.dialerOpen && widget.dialedDigits.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (!widget.dialerOpen)
            _CallsHeader(
              missedOnly: _missedOnly,
              hasMissedCalls: recentsAsync.valueOrNull?.any((e) => e.type == CallLogType.missed) ?? false,
              onChanged: (missedOnly) => setState(() => _missedOnly = missedOnly),
            ),
          Expanded(
            child: isDialing
                ? _DialMatchList(digits: widget.dialedDigits)
                : RefreshIndicator(
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
                            : _GroupedCallList(entries: filtered);
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

/// Live-matching contacts/leads as digits are typed into the drawer below,
/// shown behind it in place of call history — same matching rules as
/// [DialPadScreen]'s own suggestions (CRM lead vs device contact, gated by
/// the same "Show CRM lead names in Call Logs" preference), just rendered
/// as full-width rows styled like a call log entry instead of a compact card.
class _DialMatchList extends ConsumerWidget {
  const _DialMatchList({required this.digits});

  final String digits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leads = ref.watch(cachedLeadsProvider).valueOrNull ?? const [];
    final contacts = ref.watch(contactsListProvider).valueOrNull ?? const [];
    final preferCrm = ref.watch(preferCrmNameInCallLogsProvider).valueOrNull ?? true;

    final typed = normalizePhoneNumber(digits);
    bool startsWithTyped(String raw) => normalizePhoneNumber(raw).startsWith(typed);

    final matches = <({String name, String number})>[];
    if (preferCrm) {
      for (final lead in leads) {
        final candidates = [lead.phone, lead.secondaryPhone].whereType<String>();
        final match = candidates.where(startsWithTyped).firstOrNull;
        if (match != null) matches.add((name: lead.displayName, number: match));
      }
    } else {
      for (final DeviceContact contact in contacts) {
        final match = contact.phones.where(startsWithTyped).firstOrNull;
        if (match != null) matches.add((name: contact.displayName, number: match));
      }
    }

    return ListView(
      children: [
        _DialMatchTile(name: null, number: digits),
        for (final match in matches) _DialMatchTile(name: match.name, number: match.number),
      ],
    );
  }
}

/// One row in [_DialMatchList] — deliberately built from the same bones as
/// [_RecentTile] (avatar + name/number block, same paddings/text styles)
/// minus the call-history-only parts (direction icon, SIM chip, duration),
/// since there's no call history for a number you're still dialing.
class _DialMatchTile extends ConsumerWidget {
  const _DialMatchTile({required this.name, required this.number});

  final String? name;
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = name ?? number;
    return InkWell(
      onTap: () async {
        if (!await ensureCanPlaceCall(ref, context)) return;
        await ref.read(telecomBridgeProvider).placeCall(number);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(name: name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  if (name != null) ...[
                    const SizedBox(height: 2),
                    Text(number, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            Icon(Icons.call, color: kBrandColor, size: 20),
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
  const _GroupedCallList({required this.entries});

  final List<CallLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sections = <String, List<CallLogEntry>>{};
    for (final entry in entries) {
      final label = _sectionLabel(entry.date, now);
      sections.putIfAbsent(label, () => []).add(entry);
    }

    return ListView.builder(
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
