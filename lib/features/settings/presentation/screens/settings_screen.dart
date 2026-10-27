import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/session_provider.dart';
import '../../../dialer/data/telecom_bridge.dart';
import '../../../dialer/providers/call_screening_role_provider.dart';
import '../../../dialer/providers/default_dialer_role_provider.dart';
import '../../../updates/presentation/screens/updates_screen.dart';
import '../../../updates/providers/app_update_provider.dart';
import '../../providers/call_log_name_preference_provider.dart';
import '../../providers/post_call_note_preference_provider.dart';

/// Grouped settings list: profile header, then Phone setup / Calls / Call
/// recording / App sections, each a rounded group of rows with a tinted
/// leading icon — the same shape as Android's own Settings app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _requestDialerRole(BuildContext context, WidgetRef ref) async {
    final outcome = await ref.read(defaultDialerRoleProvider.notifier).requestRole();
    if (!context.mounted) return;
    final message = switch (outcome) {
      DialerRoleOutcome.granted => 'Pype Dialer is now your default Phone app.',
      DialerRoleOutcome.denied => 'Not set as default — you can try again anytime.',
      DialerRoleOutcome.unsupportedSdk => 'This Android version is not supported.',
      _ => null,
    };
    if (outcome == DialerRoleOutcome.permanentlyDenied) {
      _showPermanentlyDeniedDialog(context, ref);
    } else if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _requestScreeningRole(BuildContext context, WidgetRef ref) async {
    final outcome = await ref.read(callScreeningRoleProvider.notifier).requestRole();
    if (!context.mounted) return;
    final message = switch (outcome) {
      DialerRoleOutcome.granted => 'Pype Dialer is now your Caller ID & spam app.',
      DialerRoleOutcome.denied => 'Not set — you can try again anytime.',
      DialerRoleOutcome.unsupportedSdk => 'This phone does not offer a Caller ID & spam app option.',
      _ => null,
    };
    if (message != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPermanentlyDeniedDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permission needed'),
        content: const Text(
          'You previously denied a permission Pype Dialer needs. Open app Settings to grant it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(telecomBridgeProvider).openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Calls will stop syncing to the CRM until you sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(0, 40)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(sessionControllerProvider.notifier).logout();
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final isDefault = ref.watch(defaultDialerRoleProvider).valueOrNull ?? false;
    final isScreeningDefault = ref.watch(callScreeningRoleProvider).valueOrNull ?? false;
    final preferCrmName = ref.watch(preferCrmNameInCallLogsProvider).valueOrNull ?? true;
    final askNote = ref.watch(askNoteAfterCallProvider).valueOrNull ?? true;
    final availableUpdate = ref.watch(availableUpdateProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (session != null)
          _ProfileHeader(
            name: '${session.firstName} ${session.lastName}'.trim(),
            organisation: session.organisation.name,
            email: session.email,
          ),
        const _SectionTitle('Phone setup'),
        _Group(children: [
          _SettingRow(
            icon: Icons.phone_in_talk_outlined,
            title: 'Default Phone app',
            subtitle: 'Place and receive calls, read call history',
            trailing: isDefault
                ? const _StatusChip.active()
                : _SetUpButton(onPressed: () => _requestDialerRole(context, ref)),
          ),
          _SettingRow(
            icon: Icons.verified_user_outlined,
            title: 'Caller ID & spam app',
            subtitle: 'Identify CRM leads on incoming calls. Never blocks calls.',
            trailing: isScreeningDefault
                ? const _StatusChip.active()
                : _SetUpButton(onPressed: () => _requestScreeningRole(context, ref)),
          ),
        ]),
        const _SectionTitle('Calls'),
        _Group(children: [
          _SettingRow(
            icon: Icons.badge_outlined,
            title: 'Show CRM lead names',
            subtitle: preferCrmName
                ? 'Matched numbers show the CRM lead name'
                : 'Matched numbers show the phone contact name',
            trailing: Switch(
              value: preferCrmName,
              onChanged: (v) => ref.read(preferCrmNameInCallLogsProvider.notifier).setEnabled(v),
            ),
          ),
          _SettingRow(
            icon: Icons.edit_note_outlined,
            title: 'Update lead after calls',
            subtitle: 'Ask for a note and status after a call with a CRM lead',
            trailing: Switch(
              value: askNote,
              onChanged: (v) => ref.read(askNoteAfterCallProvider.notifier).setEnabled(v),
            ),
          ),
        ]),
        const _SectionTitle('Call recording'),
        const _CallRecordingGroup(),
        const _SectionTitle('App'),
        _Group(children: [
          _SettingRow(
            icon: Icons.system_update_outlined,
            title: 'Check for updates',
            subtitle: availableUpdate != null ? 'Version ${availableUpdate.versionName} available' : 'You\'re up to date',
            trailing: availableUpdate != null
                ? const Icon(Icons.circle, color: Colors.redAccent, size: 10)
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UpdatesScreen())),
          ),
          _SettingRow(
            icon: Icons.bug_report_outlined,
            title: 'Diagnostics',
            subtitle: 'Engine log for support',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _DiagnosticsScreen())),
          ),
          _SettingRow(
            icon: Icons.logout,
            iconColor: Colors.redAccent,
            title: 'Log out',
            titleColor: Colors.redAccent,
            onTap: () => _confirmLogout(context, ref),
          ),
        ]),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.organisation, required this.email});

  final String name;
  final String organisation;
  final String email;

  @override
  Widget build(BuildContext context) {
    final initials = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kBrandColor, Color.lerp(kBrandColor, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(initials.isEmpty ? '?' : initials,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(organisation, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13), overflow: TextOverflow.ellipsis),
                Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: kBrandColor),
      ),
    );
  }
}

/// A rounded group of rows separated by inset dividers.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Divider(height: 1, indent: 64, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = iconColor ?? kBrandColor;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: titleColor)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  const _StatusChip.active() : label = 'Active', color = const Color(0xFF16A34A);
  const _StatusChip.off() : label = 'Off', color = Colors.grey;

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _SetUpButton extends StatelessWidget {
  const _SetUpButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: const Text('Set up'),
    );
  }
}

/// The org's real call-recording policy (admin-set in the web CRM's Call
/// Settings — read-only here) and whether this phone's own built-in
/// recorder has been seen working. Pype Dialer never records audio itself;
/// recordings come from the phone's native recorder files.
class _CallRecordingGroup extends ConsumerStatefulWidget {
  const _CallRecordingGroup();

  @override
  ConsumerState<_CallRecordingGroup> createState() => _CallRecordingGroupState();
}

class _CallRecordingGroupState extends ConsumerState<_CallRecordingGroup> {
  ({bool hasFetched, bool autoRecordInbound, bool autoRecordOutbound})? _orgSettings;
  bool _nativeConfirmed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bridge = ref.read(telecomBridgeProvider);
    final settings = await bridge.getCallRecordingOrgSettings();
    final confirmed = await bridge.isNativeRecordingConfirmed();
    if (!mounted) return;
    setState(() {
      _orgSettings = settings;
      _nativeConfirmed = confirmed;
    });
  }

  Future<void> _openNativeDialer() async {
    final opened = await ref.read(telecomBridgeProvider).openOriginalDialerApp();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Look for a call-recording toggle in that app\'s settings.'
              : 'Couldn\'t find your phone\'s original dialer — check its settings manually.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _orgSettings;
    final fetched = settings != null && settings.hasFetched;
    final directions = [
      if (fetched && settings.autoRecordOutbound) 'outgoing',
      if (fetched && settings.autoRecordInbound) 'incoming',
    ];
    final orgOn = directions.isNotEmpty;

    return _Group(children: [
      _SettingRow(
        icon: Icons.policy_outlined,
        title: 'Organisation policy',
        subtitle: settings == null
            ? 'Checking…'
            : !fetched
                ? 'Not checked yet — sign in and try again'
                : orgOn
                    ? 'Recording ${directions.join(' & ')} calls (set by your admin)'
                    : 'Turned off by your admin',
        trailing: settings == null || !fetched
            ? null
            : orgOn
                ? const _StatusChip.active()
                : const _StatusChip.off(),
      ),
      _SettingRow(
        icon: Icons.mic_none,
        title: 'Phone\'s recorder',
        subtitle: _nativeConfirmed
            ? 'Recordings from this phone are being picked up'
            : orgOn
                ? 'No recording found yet. Turn on auto-record in your phone\'s dialer.'
                : 'Uses your phone\'s own call recorder when available',
        trailing: _nativeConfirmed ? const _StatusChip.active() : (orgOn ? const Icon(Icons.chevron_right) : null),
        onTap: !_nativeConfirmed && orgOn ? _openNativeDialer : null,
      ),
    ]);
  }
}

class _DiagnosticsScreen extends StatelessWidget {
  const _DiagnosticsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListView(padding: const EdgeInsets.all(16), children: const [_MergeSpikeDebugCard()]),
    );
  }
}

/// Phase 1 carrier-merge feasibility spike only — see
/// `Dad-dialer/CALL_RECORDING_SERVER_METHOD_PLAN.md`. Not a real feature:
/// answers whether this SIM/carrier/plan can merge a live call with a
/// second outgoing call into a real network conference, which the planned
/// server-number recording method depends on entirely. Point [_numberController]
/// at any second number you can answer (another phone you own works fine —
/// this doesn't need a telephony vendor account to test) while on an active
/// call with a first phone, then read the log below.
class _MergeSpikeDebugCard extends ConsumerStatefulWidget {
  const _MergeSpikeDebugCard();

  @override
  ConsumerState<_MergeSpikeDebugCard> createState() => _MergeSpikeDebugCardState();
}

class _MergeSpikeDebugCardState extends ConsumerState<_MergeSpikeDebugCard> {
  final _numberController = TextEditingController();
  List<Map<String, Object?>> _log = const [];
  bool _refreshing = false;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) return;
    final bridge = ref.read(telecomBridgeProvider);
    final started = await bridge.runMergeSpike(number);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          started
              ? 'Spike started — merge is attempted once $number answers.'
              : 'Could not start — need an ACTIVE call first.',
        ),
      ),
    );
    await _refreshLog();
  }

  Future<void> _refreshLog() async {
    setState(() => _refreshing = true);
    final bridge = ref.read(telecomBridgeProvider);
    final entries = await bridge.getEngineDebugLog();
    if (!mounted) return;
    setState(() {
      _log = entries;
      _refreshing = false;
    });
  }

  Future<void> _clearLog() async {
    final bridge = ref.read(telecomBridgeProvider);
    await bridge.clearEngineDebugLog();
    await _refreshLog();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diagnostic: carrier merge test (Phase 1 spike)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Not a feature — validates whether this SIM/carrier can merge '
              'calls into a real 3-way conference. While on an active call, '
              'enter a second number you can answer and run this.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numberController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Bridge test number',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _run, child: const Text('Run')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _refreshing ? null : _refreshLog,
                  child: const Text('Refresh log'),
                ),
                TextButton(onPressed: _clearLog, child: const Text('Clear log')),
              ],
            ),
            if (_log.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _log.length,
                  itemBuilder: (context, index) {
                    final entry = _log[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${entry['event']}: ${entry['detail']}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
