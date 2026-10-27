import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/lead_update_repository.dart';
import '../domain/crm_lead.dart';
import '../providers/cached_leads_provider.dart';

/// Shown right after a call with a CRM lead ends: a note for the call plus
/// an optional status change, saved straight to the CRM. Both are optional —
/// "Skip" just closes it.
Future<void> showPostCallLeadSheet(BuildContext context, CrmLead lead, {required bool wasIncoming}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PostCallLeadSheet(lead: lead, wasIncoming: wasIncoming),
  );
}

class _PostCallLeadSheet extends ConsumerStatefulWidget {
  const _PostCallLeadSheet({required this.lead, required this.wasIncoming});

  final CrmLead lead;
  final bool wasIncoming;

  @override
  ConsumerState<_PostCallLeadSheet> createState() => _PostCallLeadSheetState();
}

class _PostCallLeadSheetState extends ConsumerState<_PostCallLeadSheet> {
  final _note = TextEditingController();
  String? _status;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.lead.status;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _statusChanged => _status != null && _status != widget.lead.status;
  bool get _canSave => !_saving && (_note.text.trim().isNotEmpty || _statusChanged);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(leadUpdateRepositoryProvider);
    try {
      final note = _note.text.trim();
      if (note.isNotEmpty) await repo.addNote(widget.lead.id, note);
      if (_statusChanged) {
        await repo.updateStatus(widget.lead.id, _status!);
        // Keep the local lead list (caller-ID / match index) in step.
        ref.invalidate(cachedLeadsProvider);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${widget.lead.displayName} in the CRM.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save — check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusesAsync = ref.watch(leadStatusOptionsProvider);
    final statuses = statusesAsync.valueOrNull ?? const <LeadStatusOption>[];
    // The lead's current status must be selectable even if the org has
    // since removed it from its pipeline.
    final options = [
      ...statuses,
      if (_status != null && !statuses.any((s) => s.id == _status)) (id: _status!, label: _status!),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: kBrandColor.withValues(alpha: 0.12),
                child: Icon(widget.wasIncoming ? Icons.call_received : Icons.call_made, color: kBrandColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Call ended', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    Text(
                      widget.lead.displayName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'What happened on this call?', labelText: 'Note'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: options.any((o) => o.id == _status) ? _status : null,
            decoration: InputDecoration(
              labelText: 'Status (optional)',
              suffixIcon: statusesAsync.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
            items: [for (final o in options) DropdownMenuItem(value: o.id, child: Text(o.label))],
            onChanged: _saving ? null : (value) => setState(() => _status = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save to CRM'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
