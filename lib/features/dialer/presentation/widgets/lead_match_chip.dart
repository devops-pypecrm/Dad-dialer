import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../leads/domain/crm_lead.dart';

/// Shown above the dial pad / on the in-call screen once the typed or
/// calling number matches a CRM lead/contact (see
/// `cached_leads_provider.dart`'s `matchLead`).
class LeadMatchChip extends StatelessWidget {
  const LeadMatchChip({super.key, required this.lead});

  final CrmLead lead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kBrandColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(lead.isLead ? Icons.person_search : Icons.contacts, color: kBrandColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lead.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  lead.isLead ? (lead.status ?? 'CRM Lead') : 'Contact',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
