import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../leads/domain/crm_lead.dart';
import '../../../leads/providers/cached_leads_provider.dart';
import '../../../leads/providers/last_note_provider.dart';
import '../../../settings/providers/call_log_name_preference_provider.dart';
import '../../data/telecom_bridge.dart';
import '../../domain/call_state.dart';
import '../../providers/active_call_provider.dart';
import '../widgets/call_controls_row.dart';
import '../widgets/call_timer.dart';

/// Renders whatever `activeCallProvider` says Telecom currently has —
/// RINGING (incoming, slide to answer/decline), DIALING (outgoing, ringing
/// out), or ACTIVE/HOLDING (in-call controls). One screen for all three
/// states rather than a separate incoming-call screen, since they share
/// almost everything (matched-lead identity, number, end action) and
/// Phase 1 has no need for the duplication.
class InCallScreen extends ConsumerWidget {
  const InCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callAsync = ref.watch(activeCallProvider);
    final call = callAsync.valueOrNull ?? ActiveCall.none;
    final bridge = ref.read(telecomBridgeProvider);
    final matchedLead = call.number != null
        ? ref.read(cachedLeadsProvider.notifier).matchLead(call.number!)
        : null;
    // Same toggle Call Logs uses to decide "CRM identity or device contact
    // identity" -- reused here for "show CRM context (status/notes) or
    // don't", one consistent answer to "which identity source do you trust"
    // rather than a second independent setting for the same question.
    final showCrmContext = ref.watch(preferCrmNameInCallLogsProvider).valueOrNull ?? true;

    return PopScope(
      canPop: !call.isOngoing,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kBrandColor.withValues(alpha: 0.16),
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _CallerIdentity(call: call, matchedLead: matchedLead),
                  if (call.state == TelecomCallState.active) ...[
                    const SizedBox(height: 12),
                    const CallTimer(),
                  ],
                  if (call.isRinging && showCrmContext && matchedLead != null) ...[
                    const SizedBox(height: 20),
                    _CrmContextCard(lead: matchedLead),
                  ],
                  const Spacer(),
                  if (call.isRinging)
                    _SlideToAnswerControl(onAnswer: bridge.answerCall, onDecline: bridge.rejectCall)
                  else if (call.isOngoing)
                    _InCallActions(bridge: bridge, call: call)
                  else
                    // The call has actually ended (native CALL_REMOVED ->
                    // ActiveCall.none) — the app shell (see app.dart's
                    // ref.listen) pops this screen automatically, but that
                    // happens on the NEXT frame; without this branch there
                    // was a visible flash of full call controls (mute/
                    // speaker/hold/end) for a call that no longer exists,
                    // which is exactly what looked like the screen being
                    // "stuck." Show nothing interactive instead.
                    Text('Call ended', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallerIdentity extends StatelessWidget {
  const _CallerIdentity({required this.call, required this.matchedLead});

  final ActiveCall call;
  final CrmLead? matchedLead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = matchedLead?.displayName ?? call.number ?? '';
    final initial = displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : '#';

    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kBrandColor.withValues(alpha: 0.15),
            border: Border.all(color: kBrandColor.withValues(alpha: 0.3), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: theme.textTheme.displaySmall?.copyWith(color: kBrandColor, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          displayName,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        if (matchedLead != null && call.number != null) ...[
          const SizedBox(height: 2),
          Text(call.number!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 6),
        Text(_statusLabel(call.state), style: theme.textTheme.bodyLarge?.copyWith(color: kBrandColor)),
      ],
    );
  }

  String _statusLabel(TelecomCallState state) => switch (state) {
        TelecomCallState.dialing => 'Calling…',
        TelecomCallState.ringingIncoming => 'Incoming call',
        TelecomCallState.active => 'In call',
        TelecomCallState.holding => 'On hold',
        _ => '',
      };
}

/// CRM status + most recent note for the matched lead, shown only while the
/// call is ringing (the moment this context is actually useful -- deciding
/// how to answer, not mid-conversation) and only when [showCrmContext] is
/// on. The note is fetched on demand ([lastNoteProvider], `autoDispose`) --
/// there's no reason to fetch/cache it for leads that never call.
class _CrmContextCard extends ConsumerWidget {
  const _CrmContextCard({required this.lead});

  final CrmLead lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final noteAsync = lead.isLead ? ref.watch(lastNoteProvider(lead.id)) : const AsyncValue.data(null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(lead.isLead ? Icons.person_search : Icons.contacts, color: kBrandColor, size: 18),
              const SizedBox(width: 6),
              Text(
                lead.isLead ? (lead.status ?? 'CRM Lead') : 'Saved Contact',
                style: theme.textTheme.labelLarge?.copyWith(color: kBrandColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (lead.isLead) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 8),
            noteAsync.when(
              data: (note) => Text(
                note?.trim().isNotEmpty == true ? note! : 'No notes yet for this lead.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: note?.trim().isNotEmpty == true ? null : theme.colorScheme.onSurfaceVariant,
                  fontStyle: note?.trim().isNotEmpty == true ? null : FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              loading: () => Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Text('Loading notes…', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              // Best-effort context, not critical path -- a failed note
              // fetch shouldn't draw attention on an incoming-call screen
              // the user needs to act on quickly.
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Single horizontal slider: drag the puck right past the threshold to
/// answer, left to decline. Springs back to center if released before the
/// threshold. Hand-rolled rather than a package dependency -- this is a
/// simple enough gesture (one drag axis, two outcomes) not to be worth one.
class _SlideToAnswerControl extends StatefulWidget {
  const _SlideToAnswerControl({required this.onAnswer, required this.onDecline});

  final VoidCallback onAnswer;
  final VoidCallback onDecline;

  @override
  State<_SlideToAnswerControl> createState() => _SlideToAnswerControlState();
}

class _SlideToAnswerControlState extends State<_SlideToAnswerControl> {
  static const _threshold = 0.62;
  static const _puckSize = 64.0;

  double _dragExtent = 0; // -1 (decline) .. 0 (center) .. 1 (answer)
  bool _resolved = false;

  void _handleUpdate(DragUpdateDetails details, double trackWidth) {
    if (_resolved) return;
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx / (trackWidth / 2 - _puckSize / 2)).clamp(-1.0, 1.0);
    });
  }

  void _handleEnd(DragEndDetails details) {
    if (_resolved) return;
    if (_dragExtent >= _threshold) {
      setState(() => _resolved = true);
      widget.onAnswer();
    } else if (_dragExtent <= -_threshold) {
      setState(() => _resolved = true);
      widget.onDecline();
    } else {
      setState(() => _dragExtent = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final maxPuckTravel = trackWidth / 2 - _puckSize / 2 - 6;
            final puckOffset = _dragExtent * maxPuckTravel;
            final puckColor = _dragExtent > 0.08
                ? Colors.green
                : _dragExtent < -0.08
                    ? Colors.redAccent
                    : kBrandColor;
            final puckIcon = _dragExtent > 0.08
                ? Icons.call
                : _dragExtent < -0.08
                    ? Icons.call_end
                    : Icons.phone_in_talk;

            return AnimatedContainer(
              duration: _resolved ? Duration.zero : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 76,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(38),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.call_end, color: Colors.redAccent.withValues(alpha: 0.55)),
                        Icon(Icons.call, color: Colors.green.withValues(alpha: 0.55)),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    ignoring: true,
                    child: Text(
                      'Slide to decline or answer',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  AnimatedContainer(
                    duration: _resolved ? const Duration(milliseconds: 150) : Duration.zero,
                    transform: Matrix4.translationValues(puckOffset, 0, 0),
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) => _handleUpdate(details, trackWidth),
                      onHorizontalDragEnd: _handleEnd,
                      child: Container(
                        width: _puckSize,
                        height: _puckSize,
                        decoration: BoxDecoration(
                          color: puckColor,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Icon(puckIcon, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Decline',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _InCallActions extends ConsumerStatefulWidget {
  const _InCallActions({required this.bridge, required this.call});

  final TelecomBridge bridge;
  final ActiveCall call;

  @override
  ConsumerState<_InCallActions> createState() => _InCallActionsState();
}

class _InCallActionsState extends ConsumerState<_InCallActions> {
  bool _muted = false;
  bool _speaker = false;
  // Real Tier 0 signal (see RecordingStatusStore.kt) — whether THIS device
  // has ever confirmed a native-recorder match. Not re-fetched per call;
  // once true it stays true for the life of the screen.
  bool _nativeRecordingConfirmed = false;
  // Org's real autoRecordInbound/autoRecordOutbound policy (admin-set in
  // the web CRM), not a guess — see getCallRecordingOrgSettings's doc
  // comment. Null until the native cache answers.
  ({bool hasFetched, bool autoRecordInbound, bool autoRecordOutbound})? _orgSettings;

  @override
  void initState() {
    super.initState();
    widget.bridge.isNativeRecordingConfirmed().then((confirmed) {
      if (mounted) setState(() => _nativeRecordingConfirmed = confirmed);
    });
    widget.bridge.getCallRecordingOrgSettings().then((settings) {
      if (mounted) setState(() => _orgSettings = settings);
    });
  }

  bool get _orgWantsRecordingForThisCall {
    final settings = _orgSettings;
    if (settings == null || !settings.hasFetched) return false;
    return widget.call.isIncoming ? settings.autoRecordInbound : settings.autoRecordOutbound;
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await widget.bridge.setMuted(_muted);
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _speaker = !_speaker);
    await widget.bridge.setSpeaker(_speaker);
  }

  /// Play-safe by design (see the approved architecture decision) — this
  /// never captures audio itself, ever. The actual recording has to come
  /// from the phone's OWN native dialer's built-in call-recording feature
  /// (the one that plays the standard "this call is being recorded"
  /// announcement) — Dad-dialer can't switch that on for the user (that
  /// would need the Accessibility/RECORD_AUDIO surface this app
  /// deliberately never carries), so this opens that real app directly
  /// instead of a dead-end generic Settings screen.
  Future<void> _onRecordingTap() async {
    if (_nativeRecordingConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Native call recording is already working on this device.')),
      );
      return;
    }
    final orgSettings = _orgSettings;
    if (orgSettings != null && orgSettings.hasFetched && !_orgWantsRecordingForThisCall) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your org has call recording turned off for this direction — ask an admin to enable it in Call Settings.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final openedRealDialer = await widget.bridge.openOriginalDialerApp();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          openedRealDialer
              ? "Opened your phone's own dialer — look for a call-recording toggle in its settings."
              : "Couldn't find your phone's original dialer app — check its settings manually for a call-recording toggle.",
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Phase 1 carrier-merge feasibility spike only — see
  // Dad-dialer/CALL_RECORDING_SERVER_METHOD_PLAN.md. The equivalent trigger
  // lives in Settings too, but that screen is unreachable while a call is
  // full-screen — this is the one moment (call already ACTIVE) the spike
  // actually needs to be started from, so it has to live here.
  Future<void> _showMergeSpikeDialog() async {
    final controller = TextEditingController();
    final number = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Diagnostic: carrier merge test'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Bridge test number (a phone you can answer)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Run'),
          ),
        ],
      ),
    );
    if (number == null || number.isEmpty) return;
    final started = await widget.bridge.runMergeSpike(number);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          started
              ? 'Spike started — merge attempted once $number answers. Check the log in Settings after.'
              : 'Could not start (need an ACTIVE call, which this already should be — check Settings log).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHolding = widget.call.state == TelecomCallState.holding;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CallControlButton(icon: _muted ? Icons.mic_off : Icons.mic, label: 'Mute', active: _muted, onTap: _toggleMute),
            CallControlButton(icon: Icons.volume_up, label: 'Speaker', active: _speaker, onTap: _toggleSpeaker),
            CallControlButton(
              icon: isHolding ? Icons.play_arrow : Icons.pause,
              label: isHolding ? 'Resume' : 'Hold',
              active: isHolding,
              onTap: isHolding ? widget.bridge.resumeCall : widget.bridge.holdCall,
            ),
            CallControlButton(
              icon: Icons.fiber_manual_record,
              label: 'Recording',
              active: _nativeRecordingConfirmed,
              onTap: _onRecordingTap,
            ),
          ],
        ),
        const SizedBox(height: 24),
        CallControlButton(
          icon: Icons.call_end,
          label: 'End',
          color: Colors.redAccent.withValues(alpha: 0.2),
          onTap: widget.bridge.endCall,
        ),
        if (widget.call.state == TelecomCallState.active) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            icon: const Icon(Icons.science_outlined, size: 16),
            label: const Text('Merge test (debug)', style: TextStyle(fontSize: 12)),
            onPressed: _showMergeSpikeDialog,
          ),
        ],
      ],
    );
  }
}
