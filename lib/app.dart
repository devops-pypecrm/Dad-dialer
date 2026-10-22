import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/providers/session_provider.dart';
import 'features/calls/presentation/screens/recents_screen.dart';
import 'features/contacts/presentation/screens/contacts_screen.dart';
import 'features/dialer/domain/call_state.dart';
import 'features/dialer/presentation/screens/dial_pad_screen.dart';
import 'features/dialer/presentation/screens/in_call_screen.dart';
import 'features/dialer/providers/active_call_provider.dart';
import 'features/favorites/presentation/screens/favorites_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
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

class _AuthenticatedShellState extends ConsumerState<_AuthenticatedShell> {
  int _tabIndex = 0;
  bool _showingInCallScreen = false;
  bool _dialerOpen = false;
  String _dialedDigits = '';

  @override
  Widget build(BuildContext context) {
    ref.listen(activeCallProvider, (previous, next) {
      final call = next.valueOrNull ?? ActiveCall.none;
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
      }
    });

    // Matches the reference layout: Calls/Contacts/Favorites/Settings as
    // labeled bottom-nav tabs, with the dial pad promoted to its own
    // floating action button (not a 5th tab) — tapping it pushes
    // DialPadScreen full-screen rather than swapping tabs.
    final screens = [
      RecentsScreen(dialerOpen: _dialerOpen, dialedDigits: _dialedDigits),
      const ContactsScreen(),
      const FavoritesScreen(),
      const SettingsScreen(),
    ];
    const callsIndex = 0;

    return Scaffold(
      // No app bar on the Calls tab — it builds its own header (the big
      // "Calls" title + All/Missed segmented control), matching the
      // reference exactly. The other tabs keep a plain title bar.
      appBar: _tabIndex == callsIndex ? null : AppBar(title: Text(_titleFor(_tabIndex))),
      body: screens[_tabIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
          if (_dialerOpen) {
            _dialerOpen = false;
            _dialedDigits = '';
          } else {
            _dialerOpen = true;
          }
        }),
        backgroundColor: kBrandColor,
        shape: const CircleBorder(),
        child: Icon(_dialerOpen ? Icons.keyboard_arrow_down : Icons.dialpad, color: Colors.white),
      ),
      // Scaffold's own `bottomSheet` (not a modal `showModalBottomSheet`)
      // is what gives this the reference's "overlays the body, nav bar
      // stays visible and tappable, no scrim blocking the list above it"
      // behavior for free — a modal sheet draws over the whole screen
      // including the nav bar and blocks the body with a barrier, which
      // isn't what was asked for here.
      bottomSheet: _dialerOpen
          ? _DialerDrawer(
              onDigitsChanged: (digits) => setState(() => _dialedDigits = digits),
              onClose: () => setState(() {
                _dialerOpen = false;
                _dialedDigits = '';
              }),
            )
          : null,
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _tabIndex,
        onSelected: (index) => setState(() => _tabIndex = index),
      ),
    );
  }

  String _titleFor(int index) => switch (index) {
        1 => 'Contacts',
        2 => 'Favorites',
        _ => 'Settings',
      };
}

/// Half-screen dial pad drawer anchored above the bottom nav bar, via
/// `Scaffold.bottomSheet` in [_AuthenticatedShellState] rather than
/// `showModalBottomSheet` -- see that call site's comment for why.
class _DialerDrawer extends StatelessWidget {
  const _DialerDrawer({required this.onDigitsChanged, required this.onClose});

  final ValueChanged<String> onDigitsChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // 0.5 of screen height was too tight for the keypad screen's actual
    // content (lead-match chip space + number display + a 4-row keypad +
    // the call button row all assume roughly this much room) -- squeezed
    // into half the screen it rendered as overlapping/clipped digits
    // instead of a readable keypad. 0.72 leaves the keypad legible while
    // still reading as a drawer, not a full-screen takeover; clamped so it
    // never shrinks below a usable floor on short screens or grows to
    // swallow the status bar / nav bar area on tall ones.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = (screenHeight * 0.72).clamp(420.0, screenHeight - 120.0);
    return GestureDetector(
      // Swipe the handle down to dismiss, same gesture a real bottom sheet
      // would give you for free -- `bottomSheet` doesn't add that on its
      // own since it's non-modal and not draggable by default.
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 200) onClose();
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          height: height,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: DialPadScreen(showSuggestionsPanel: false, onNumberChanged: onDigitsChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
