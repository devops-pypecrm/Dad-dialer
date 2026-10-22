import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'default_dialer_role_provider.dart';

/// Shared guard for every "tap to call" entry point (dial pad, Recents,
/// Contacts) — `CALL_PHONE` is only ever granted via the "Set as default
/// dialer" flow, so a tap before that's done would otherwise hit
/// `MainActivity`'s `placeCall` `permission_denied` error with no
/// explanation. Checking here means never even attempting the call.
Future<bool> ensureCanPlaceCall(WidgetRef ref, BuildContext context) async {
  final isDefault = await ref.read(defaultDialerRoleProvider.future);
  if (isDefault) return true;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Set Pype Dialer as your default Phone app first (see Settings).')),
    );
  }
  return false;
}
