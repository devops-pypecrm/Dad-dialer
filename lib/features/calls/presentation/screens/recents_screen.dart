import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../contacts/domain/device_contact.dart';
import '../../../contacts/providers/contacts_provider.dart';
import '../../../dialer/data/telecom_bridge.dart';
import '../../../dialer/providers/call_guard.dart';
import '../../../dialer/providers/default_dialer_role_provider.dart';
import '../../../leads/domain/crm_lead.dart';
import '../../../leads/presentation/post_call_lead_sheet.dart';
import '../../../leads/providers/cached_leads_provider.dart';
import '../../../settings/providers/call_log_name_preference_provider.dart';
import '../../domain/call_log_entry.dart';
import '../../providers/recents_provider.dart' show recentsProvider, recordedCallIndexProvider;

/// Direction-coded colors for a call-log row's avatar/icon — green for a
/// completed incoming call, brand purple for outgoing (ties the "you called
/// them" case to the brand accent, replacing the reference app's orange),
/// coral-red for anything that didn't connect (missed/rejected/blocked).
const _kIncomingColor = Color(0xFF66BB6A);
const _kMissedColor = Color(0xFFEF5350);

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
  CallLogType? _filter;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    if (widget.dialedDigits.isNotEmpty) {
      return SafeArea(
        bottom: false,
        // The keypad panel has its own number field; only show the big
        // number up here when the keypad is tucked away.
        child: _DialedNumberView(
          digits: widget.dialedDigits,
          bottomInset: widget.bottomInset,
          showNumber: widget.bottomInset < 1,
        ),
      );
    }

    final recentsAsync = ref.watch(recentsProvider);
    // Shown as a persistent top banner (matching the reference) rather than
    // a full-screen takeover here — the full-screen ask only happens once,
    // before the shell even mounts (see `_DialerRoleGate` in app.dart); this
    // is the standing reminder for anyone who tapped "Skip" there.
    final isDefaultDialer = ref.watch(defaultDialerRoleProvider).valueOrNull ?? true;
    final listPadding = EdgeInsets.only(bottom: widget.bottomInset + 88);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _CallsHeader(
            filter: _filter,
            hasMissedCalls: recentsAsync.valueOrNull?.any((e) => e.type == CallLogType.missed) ?? false,
            onFilterChanged: (filter) => setState(() => _filter = filter),
            onSearchChanged: (query) => setState(() => _searchQuery = query),
          ),
          if (!isDefaultDialer)
            _MissingPermissionBanner(
              onFixNow: () async {
                await ref.read(defaultDialerRoleProvider.notifier).requestRole();
                ref.invalidate(recentsProvider);
              },
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(recentsProvider.notifier).refresh(),
              child: recentsAsync.when(
                data: (entries) {
                  var filtered = _filter == null ? entries : entries.where((e) => e.type == _filter).toList();
                  if (_searchQuery.trim().isNotEmpty) {
                    final query = _searchQuery.trim().toLowerCase();
                    filtered = filtered
                        .where((e) =>
                            (e.cachedName?.toLowerCase().contains(query) ?? false) ||
                            (e.number?.toLowerCase().contains(query) ?? false))
                        .toList();
                  }
                  return filtered.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(child: Text(_filter == null ? 'No calls yet.' : 'No calls here.')),
                            ),
                          ],
                        )
                      : _GroupedCallList(entries: filtered, padding: listPadding);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) {
                  // Already explained by the banner above — an empty list
                  // reads better here than a second, redundant error block.
                  final isPermissionDenied = error is PlatformException && error.code == 'permission_denied';
                  return isPermissionDenied
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(child: Text('No calls yet.')),
                            ),
                          ],
                        )
                      : _RecentsError(error: error);
                },
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
  const _DialedNumberView({required this.digits, required this.bottomInset, required this.showNumber});

  final String digits;
  final double bottomInset;
  final bool showNumber;

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
        if (!showNumber) const SizedBox(height: 56),
        if (showNumber)
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

/// "Call History" title + filter/export icons, then the All/Incoming/
/// Outgoing/Missed/Rejected tab row and a search field — matching the
/// reference's layout (title+icons row, tabs row, search row, each full
/// width) instead of the previous centered All/Missed pill.
class _CallsHeader extends StatelessWidget {
  const _CallsHeader({
    required this.filter,
    required this.hasMissedCalls,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  final CallLogType? filter;
  final bool hasMissedCalls;
  final ValueChanged<CallLogType?> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Call History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.filter_list_rounded), onPressed: () {}),
                IconButton(icon: const Icon(Icons.ios_share_rounded), onPressed: () {}),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _CallTypeTab(label: 'All Calls', icon: Icons.phone, selected: filter == null, onTap: () => onFilterChanged(null)),
                _CallTypeTab(
                  label: 'Incoming',
                  icon: Icons.call_received,
                  color: _kIncomingColor,
                  selected: filter == CallLogType.incoming,
                  onTap: () => onFilterChanged(CallLogType.incoming),
                ),
                _CallTypeTab(
                  label: 'Outgoing',
                  icon: Icons.call_made,
                  color: kBrandColor,
                  selected: filter == CallLogType.outgoing,
                  onTap: () => onFilterChanged(CallLogType.outgoing),
                ),
                _CallTypeTab(
                  label: 'Missed',
                  icon: Icons.call_received,
                  color: _kMissedColor,
                  selected: filter == CallLogType.missed,
                  showDot: hasMissedCalls,
                  onTap: () => onFilterChanged(CallLogType.missed),
                ),
                _CallTypeTab(
                  label: 'Rejected',
                  icon: Icons.call_end,
                  color: _kMissedColor,
                  selected: filter == CallLogType.rejected,
                  onTap: () => onFilterChanged(CallLogType.rejected),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tab in the call-type filter row: a direction-colored icon beside its
/// label, with a small dot under the label when selected (matching the
/// reference) instead of a filled pill background.
class _CallTypeTab extends StatelessWidget {
  const _CallTypeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
    this.showDot = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool showDot;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = selected ? (color ?? scheme.onSurface) : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: tint),
                const SizedBox(width: 5),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: tint, fontWeight: selected ? FontWeight.w700 : FontWeight.normal, fontSize: 13),
                    ),
                    if (showDot)
                      Positioned(
                        right: -8,
                        top: -2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: selected ? tint : Colors.transparent, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

/// A genuine, unexpected recents-load failure — the one expected failure
/// (`permission_denied`, before "Set as default dialer" is granted) is
/// handled by the caller instead, via `_MissingPermissionBanner` + an empty
/// list, so it never reaches here.
class _RecentsError extends StatelessWidget {
  const _RecentsError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('Could not load recents: $error')),
        ),
      ],
    );
  }
}

/// "Some required permissions are missing. Please fix this for smooth
/// functionality. FIX NOW" — matches the reference app's standing reminder
/// banner, shown above the list on every call-related tab until the user
/// grants the default-dialer role (whether they skipped the initial full-screen
/// ask or revoked it later from system Settings).
class _MissingPermissionBanner extends StatelessWidget {
  const _MissingPermissionBanner({required this.onFixNow});

  final VoidCallback onFixNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E3B8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB8860B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: Color(0xFF4A4028), fontSize: 13, height: 1.3),
                children: [
                  const TextSpan(
                    text: 'Some required permissions are missing. Please fix this for smooth functionality. ',
                  ),
                  TextSpan(
                    text: 'FIX NOW',
                    style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = onFixNow,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

  /// `wa.me` wants digits only (no `+`, spaces or punctuation) — country
  /// code included, same convention used by every "click to WhatsApp" link.
  static String _digitsOnly(String number) => number.replaceAll(RegExp(r'[^0-9]'), '');

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
    final isBadStatus = isMissed || isRejected || entry.type == CallLogType.blocked;
    final directionColor = _directionColor(entry.type);
    final number = entry.number;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kCardSurfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: number == null
                ? null
                : () async {
                    if (!await ensureCanPlaceCall(ref, context)) return;
                    await ref.read(telecomBridgeProvider).placeCall(number);
                  },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Avatar(name: resolvedName, color: directionColor, icon: _directionIcon(entry.type)),
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
                            color: isBadStatus ? _kMissedColor : scheme.onSurface,
                          ),
                        ),
                        if (resolvedName != null && number != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            number,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                          ),
                        ],
                        if (entry.simSlot != null || hasRecording) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (entry.simSlot != null) ...[
                                _SimChip(slot: entry.simSlot!, label: entry.simLabel),
                                const SizedBox(width: 6),
                              ],
                              if (hasRecording) const _RecordedBadge(),
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
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusLabel(entry),
                        style: TextStyle(
                          fontSize: 12,
                          color: isBadStatus ? _kMissedColor : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  _InfoButton(entry: entry),
                ],
              ),
            ),
          ),
          if (number != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickActionIcon(
                    icon: Icons.copy_outlined,
                    tooltip: 'Copy number',
                    onTap: () => Clipboard.setData(ClipboardData(text: number)),
                  ),
                  _QuickActionIcon(
                    icon: Icons.sms_outlined,
                    tooltip: 'Message',
                    color: scheme.onSurfaceVariant,
                    onTap: () => launchUrl(Uri.parse('sms:$number')),
                  ),
                  _QuickActionIcon(
                    icon: Icons.chat_bubble_outline,
                    tooltip: 'WhatsApp',
                    color: _kIncomingColor,
                    onTap: () => launchUrl(
                      Uri.parse('https://wa.me/${_digitsOnly(number)}'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  _QuickActionIcon(
                    icon: Icons.call_outlined,
                    tooltip: 'Call',
                    color: kBrandColor,
                    onTap: () async {
                      if (!await ensureCanPlaceCall(ref, context)) return;
                      await ref.read(telecomBridgeProvider).placeCall(number);
                    },
                  ),
                ],
              ),
            ),
          // Only offered for a number that actually resolves to a CRM lead —
          // there's nothing to attach a note to otherwise, so the bar is
          // omitted entirely rather than shown disabled.
          if (matchedLead != null)
            InkWell(
              onTap: () => showPostCallLeadSheet(context, matchedLead, wasIncoming: entry.type == CallLogType.incoming),
              child: Container(
                width: double.infinity,
                color: kNestedSurfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Tap to add note & tag',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
        CallLogType.incoming => _kIncomingColor,
        CallLogType.missed => _kMissedColor,
        CallLogType.rejected => _kMissedColor,
        CallLogType.blocked => _kMissedColor,
        CallLogType.unknown => Colors.grey,
      };

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes}m ${remaining}s';
  }
}

/// Call-direction-colored circle, with the resolved name's initial (or a
/// plain person silhouette for an unrecognized number — this app has no
/// contact-photo support, Android Contacts photo lookup isn't wired up) and
/// a small corner badge carrying the direction icon (call-made/received/
/// end), matching the reference's direction-coded avatar ring.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color, required this.icon});

  final String? name;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const size = 46.0;
    final trimmed = name?.trim();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: color.withValues(alpha: 0.18),
            child: trimmed == null || trimmed.isEmpty
                ? Icon(Icons.person, color: color, size: 24)
                : Text(
                    trimmed[0].toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: kCardSurfaceColor, width: 1.5)),
              alignment: Alignment.center,
              child: Icon(icon, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the 4 quick-action icons under a call-log row (Copy/SMS/WhatsApp/
/// Call) — a plain circular tap target, not a Material [IconButton], so it
/// sits flush against its 3 siblings without the button's built-in min-size
/// padding fighting the `spaceEvenly` row.
class _QuickActionIcon extends StatelessWidget {
  const _QuickActionIcon({required this.icon, required this.tooltip, required this.onTap, this.color});

  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
        ),
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
