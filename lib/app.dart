import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/providers/session_provider.dart';
import 'features/calls/presentation/screens/recents_screen.dart';
import 'features/contacts/presentation/screens/contacts_screen.dart';
import 'features/dialer/data/telecom_bridge.dart';
import 'features/dialer/domain/call_state.dart';
import 'features/dialer/presentation/widgets/dialer_keypad_sheet.dart';
import 'features/dialer/presentation/screens/in_call_screen.dart';
import 'features/dialer/providers/active_call_provider.dart';
import 'features/dialer/providers/call_guard.dart';
import 'features/favorites/presentation/screens/favorites_screen.dart';
import 'features/leads/domain/crm_lead.dart';
import 'features/leads/presentation/post_call_lead_sheet.dart';
import 'features/leads/providers/cached_leads_provider.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/settings/providers/post_call_note_preference_provider.dart';
import 'features/updates/presentation/widgets/update_checker_overlay.dart';

class App extends ConsumerWidget {
  const App({super.key});

  // A named key rather than relying on MaterialApp's own default navigator
  // is needed so UpdateCheckerOverlay — mounted as a *sibling* of the
  // Navigator via `builder` below, not a descendant of it — can still push
  // the Updates screen and find a dialog-hosting context when a new
  // release shows up, regardless of which tab is on top. Same pattern as
  // Dad-call-recorder's `CallRecorderApp`.
  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Pype Dialer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: _navigatorKey,
      builder: (context, child) => Stack(
        children: [
          ?child,
          UpdateCheckerOverlay(navigatorKey: _navigatorKey),
        ],
      ),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionControllerProvider);

    return sessionAsync.when(
      data: (session) => session == null ? const LoginScreen() : const _AuthenticatedShell(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const LoginScreen(),
    );
  }
}

/// Bottom-nav shell for a signed-in user, with an automatic full-screen
/// hand-off to [InCallScreen] whenever Telecom reports an ongoing call —
/// this is what actually renders the incoming/in-call UI, from wherever the
/// user happened to be in the app (or even if the app was backgrounded).
class _AuthenticatedShell extends ConsumerStatefulWidget {
  const _AuthenticatedShell();

  @override
  ConsumerState<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends ConsumerState<_AuthenticatedShell> with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  bool _showingInCallScreen = false;

  /// The last call seen while it was still ongoing — once it ends, this is
  /// who the post-call "Update lead" sheet is about.
  ActiveCall? _lastOngoingCall;
  String _dialedDigits = '';

  /// 0 = keypad hidden (FAB showing), 1 = keypad fully up. Driven both by
  /// the open/close animation and directly by a finger dragging the
  /// panel's handle, so the panel tracks the drag 1:1.
  late final AnimationController _keypad = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  static const _callsIndex = 0;

  @override
  void dispose() {
    _keypad.dispose();
    super.dispose();
  }

  bool get _keypadOpen => _keypad.value > 0.5;

  void _openKeypad() {
    setState(() => _tabIndex = _callsIndex);
    _keypad.animateTo(1, curve: Curves.easeOutCubic);
  }

  /// Hides the panel but keeps whatever was typed — the number stays at the
  /// top of the screen and reappears in the panel when the FAB reopens it.
  void _collapseKeypad() => _keypad.animateTo(0, curve: Curves.easeOutCubic);

  void _setDigits(String digits) => setState(() => _dialedDigits = digits);

  void _onDragUpdate(DragUpdateDetails details) {
    _keypad.value -= (details.primaryDelta ?? 0) / DialerKeypadSheet.height;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300 || (velocity > -300 && _keypad.value < 0.6)) {
      _collapseKeypad();
    } else {
      _keypad.animateTo(1, curve: Curves.easeOutCubic);
    }
  }

  Future<void> _call(int? simIndex) async {
    final number = _dialedDigits;
    if (number.isEmpty) return;
    if (!await ensureCanPlaceCall(ref, context)) return;
    await ref.read(telecomBridgeProvider).placeCall(number, simIndex: simIndex);
  }

  /// After a call with a number that matches a CRM lead, offer to log a
  /// note and change the lead's status right away (unless turned off in
  /// Settings). Contacts aren't offered — status is a lead-only field.
  Future<void> _maybeAskForLeadUpdate(ActiveCall ended) async {
    final number = ended.number;
    if (number == null) return;
    final enabled = await ref.read(askNoteAfterCallProvider.future);
    if (!enabled || !mounted) return;
    final lead = ref.read(cachedLeadsProvider.notifier).matchLead(number);
    if (lead == null || !lead.isLead) return;
    // Let the in-call screen's pop transition finish first.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await showPostCallLeadSheet(context, lead, wasIncoming: ended.isIncoming);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeCallProvider, (previous, next) {
      final call = next.valueOrNull ?? ActiveCall.none;
      if (call.isOngoing && call.number != null) _lastOngoingCall = call;
      if (call.isOngoing && !_showingInCallScreen) {
        _showingInCallScreen = true;
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const InCallScreen()))
            .then((_) => _showingInCallScreen = false);
      } else if (!call.isOngoing && _showingInCallScreen) {
        // The call ended (native CALL_REMOVED -> ActiveCall.none) — pop the
        // in-call screen automatically. Without this it just re-renders
        // itself with an empty/"none" call state forever, since nothing
        // else ever navigates back on its own (this was the actual bug:
        // the screen "stuck" showing full call controls with no timer/data
        // after either side hung up).
        _showingInCallScreen = false;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
        final ended = _lastOngoingCall;
        _lastOngoingCall = null;
        if (ended != null) _maybeAskForLeadUpdate(ended);
      }
    });

    final onCalls = _tabIndex == _callsIndex;

    return AnimatedBuilder(
      animation: _keypad,
      builder: (context, _) {
        final t = _keypad.value;
        // Back first hides the keypad, then clears the typed number, and
        // only then leaves the app — same order as the stock dialer.
        final interceptBack = onCalls && (_keypadOpen || _dialedDigits.isNotEmpty);
        return PopScope(
          canPop: !interceptBack,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_keypadOpen) {
              _collapseKeypad();
            } else {
              _setDigits('');
            }
          },
          child: Scaffold(
            // No app bar on the Calls tab — it builds its own header (the big
            // "Calls" title + All/Missed segmented control). The other tabs
            // keep a plain title bar.
            appBar: onCalls ? null : AppBar(title: Text(_titleFor(_tabIndex))),
            body: onCalls
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: RecentsScreen(
                          dialedDigits: _dialedDigits,
                          bottomInset: DialerKeypadSheet.height * t,
                        ),
                      ),
                      // The keypad slides up from behind the bottom nav bar
                      // and sits on top of the list — the list stays visible
                      // and scrollable above it, no scrim.
                      if (t > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: -DialerKeypadSheet.height * (1 - t),
                          child: DialerKeypadSheet(
                            hasDigits: _dialedDigits.isNotEmpty,
                            onDigit: (d) => _setDigits(_dialedDigits + d),
                            onBackspace: () {
                              if (_dialedDigits.isEmpty) return;
                              _setDigits(_dialedDigits.substring(0, _dialedDigits.length - 1));
                            },
                            onClear: () => _setDigits(''),
                            onCollapse: _collapseKeypad,
                            onCall: _call,
                            onDragUpdate: _onDragUpdate,
                            onDragEnd: _onDragEnd,
                          ),
                        ),
                    ],
                  )
                : [const ContactsScreen(), const FavoritesScreen(), const SettingsScreen()][_tabIndex - 1],
            // The FAB shrinks away as the keypad rises and pops back as it
            // drops — the two are never on screen at the same time.
            floatingActionButton: Transform.scale(
              scale: onCalls ? 1 - t : 1,
              child: FloatingActionButton(
                onPressed: _openKeypad,
                backgroundColor: kBrandColor,
                shape: const CircleBorder(),
                child: const Icon(Icons.dialpad, color: Colors.white),
              ),
            ),
            bottomNavigationBar: _BottomNavBar(
              selectedIndex: _tabIndex,
              onSelected: (index) {
                if (index != _callsIndex) _keypad.value = 0;
                setState(() => _tabIndex = index);
              },
            ),
          ),
        );
      },
    );
  }

  String _titleFor(int index) => switch (index) {
        1 => 'Contacts',
        2 => 'Favorites',
        _ => 'Settings',
      };
}

/// Labeled bottom bar matching the reference: icon + text label per tab,
/// both tinted brand-green on the selected tab and a muted gray otherwise.
/// A plain [Row] rather than Material's [NavigationBar]/[BottomNavigationBar]
/// so the floating dial-pad FAB (added in the Scaffold above) can overlap
/// its top-right corner exactly like the reference, without fighting
/// Material's built-in notch/docking behavior made for a FAB that's
/// actually part of the bar.
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (icon: Icons.call, label: 'Calls'),
    (icon: Icons.person, label: 'Contacts'),
    (icon: Icons.star, label: 'Favorites'),
    (icon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavTab(
                  icon: _items[i].icon,
                  label: _items[i].label,
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kBrandColor : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
