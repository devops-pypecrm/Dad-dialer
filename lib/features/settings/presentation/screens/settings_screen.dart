import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/session_provider.dart';
import '../../../dialer/data/telecom_bridge.dart';
import '../../../dialer/providers/call_screening_role_provider.dart';
import '../../../dialer/providers/default_dialer_role_provider.dart';
import '../../../updates/presentation/screens/updates_screen.dart';
import '../../../updates/providers/app_update_provider.dart';
import '../../providers/call_log_name_preference_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _requestRole(BuildContext context, WidgetRef ref) async {
    final outcome = await ref.read(defaultDialerRoleProvider.notifier).requestRole();
    if (!context.mounted) return;
    switch (outcome) {
      case DialerRoleOutcome.granted:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pype Dialer is now your default Phone app.')),
        );
      case DialerRoleOutcome.denied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not set as default — you can try again anytime.')),
        );
      case DialerRoleOutcome.permanentlyDenied:
        _showPermanentlyDeniedDialog(context, ref);
      case DialerRoleOutcome.unsupportedSdk:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This Android version is not supported.')),
        );
      case DialerRoleOutcome.alreadyDefault:
      case DialerRoleOutcome.alreadyInFlight:
      case DialerRoleOutcome.permissionsDenied:
      case DialerRoleOutcome.unknown:
        break;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final isDefaultAsync = ref.watch(defaultDialerRoleProvider);
    final isDefault = isDefaultAsync.valueOrNull ?? false;
    final isScreeningDefault = ref.watch(callScreeningRoleProvider).valueOrNull ?? false;
    final preferCrmNameAsync = ref.watch(preferCrmNameInCallLogsProvider);
    final preferCrmName = preferCrmNameAsync.valueOrNull ?? true;
    final availableUpdate = ref.watch(availableUpdateProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (session != null)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('${session.firstName} ${session.lastName}'),
              subtitle: Text('${session.organisation.name} • ${session.email}'),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDefault ? 'Default dialer: ACTIVE' : 'Default dialer: INACTIVE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDefault ? Colors.green : Colors.orange,
                      ),
                    ),
                    if (!isDefault)
                      FilledButton(
                        onPressed: () => _requestRole(context, ref),
                        child: const Text('Set as default'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Required for Pype Dialer to place/receive calls, read call '
                  'history, and identify CRM leads on incoming calls.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isScreeningDefault ? 'Caller ID & spam app: ACTIVE' : 'Caller ID & spam app: INACTIVE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isScreeningDefault ? Colors.green : Colors.orange,
                      ),
                    ),
                    if (!isScreeningDefault)
                      FilledButton(
                        onPressed: () => _requestScreeningRole(context, ref),
                        child: const Text('Set as default'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lets Pype Dialer identify incoming callers as CRM leads. '
                  'It never blocks or hides a call.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: SwitchListTile(
            title: const Text('Show CRM lead names in Call Logs'),
            subtitle: Text(
              preferCrmName
                  ? 'A matched number shows its CRM lead name. Numbers with no CRM match show just the number.'
                  : 'A matched number shows its phone contact name instead. Falls back to the number if there\'s no contact either.',
              style: const TextStyle(fontSize: 12),
            ),
            value: preferCrmName,
            onChanged: (enabled) =>
                ref.read(preferCrmNameInCallLogsProvider.notifier).setEnabled(enabled),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('Check for updates'),
            subtitle: availableUpdate != null ? Text('Version ${availableUpdate.versionName} available') : null,
            trailing: availableUpdate != null
                ? const Icon(Icons.circle, color: Colors.redAccent, size: 10)
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UpdatesScreen())),
          ),
        ),
        const SizedBox(height: 16),
        const _CallRecordingCard(),
        const SizedBox(height: 16),
        const _MergeSpikeDebugCard(),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
          onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
        ),
      ],
    );
  }
}

/// Shows the org's REAL call-recording policy (admin-set in the web CRM's
/// Call Settings page — this card never writes it, only reads what's
/// already configured there) and, when it's on, a way to actually enable
/// the thing that does the recording: the phone's own native dialer's
/// built-in call-recording feature. Dad-dialer never records a call
/// itself — see `_InCallActions._onRecordingTap`'s doc comment for why.
class _CallRecordingCard extends ConsumerStatefulWidget {
  const _CallRecordingCard();

  @override
  ConsumerState<_CallRecordingCard> createState() => _CallRecordingCardState();
}

class _CallRecordingCardState extends ConsumerState<_CallRecordingCard> {
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

  @override
  Widget build(BuildContext context) {
    final settings = _orgSettings;
    final orgHasRecordingOn = settings != null && settings.hasFetched && (settings.autoRecordInbound || settings.autoRecordOutbound);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Call Recording', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (settings == null)
              const Text('Checking your org\'s recording policy…', style: TextStyle(fontSize: 12))
            else if (!settings.hasFetched)
              const Text(
                'Could not check your org\'s recording policy yet — try again after signing in.',
                style: TextStyle(fontSize: 12),
              )
            else
              Text(
                orgHasRecordingOn
                    ? 'Your org has call recording enabled (set by an admin in Call Settings).'
                    : 'Your org has call recording turned off. Ask an admin to enable it in Call Settings if you need it.',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            Text(
              _nativeConfirmed
                  ? 'Your phone\'s own native call recorder is confirmed working.'
                  : 'The actual recording comes from your phone\'s own native dialer\'s built-in call-recording feature — Dad-dialer never records calls itself.',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            if (orgHasRecordingOn && !_nativeConfirmed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.mic_none),
                  label: const Text('Open phone\'s dialer to enable recording'),
                  onPressed: () async {
                    final opened = await ref.read(telecomBridgeProvider).openOriginalDialerApp();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          opened
                              ? 'Look for a call-recording toggle in that app\'s settings.'
                              : 'Couldn\'t find your phone\'s original dialer — check its settings manually.',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
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
