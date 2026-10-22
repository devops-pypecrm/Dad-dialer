import 'dart:async';

import 'package:flutter/material.dart';

/// Elapsed-time display for an active call — timer starts the moment this
/// widget is built (the caller only builds it once the call reaches ACTIVE),
/// not from any native timestamp, since Phase 1 doesn't plumb one through;
/// good enough for on-screen display, the CRM's own `durationSeconds` (sent
/// by `CallEventBridge`'s native-side timing) is the source of truth for
/// anything synced to the backend.
class CallTimer extends StatefulWidget {
  const CallTimer({super.key});

  @override
  State<CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<CallTimer> {
  late final DateTime _startedAt = DateTime.now();
  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text('$minutes:$seconds', style: Theme.of(context).textTheme.titleMedium);
  }
}
