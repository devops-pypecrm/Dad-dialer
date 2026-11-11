import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../leads/domain/crm_lead.dart';

/// Shared dark card row for a phone-number-bearing entity (device contact or
/// favorite) — avatar with a favorite-ring + star badge, name/number, an
/// optional CRM status pill, and a 4-icon quick-action row (copy, SMS,
/// WhatsApp, call). Used by both `ContactsScreen` and `FavoritesScreen` so
/// the two stay visually identical without duplicating this much layout.
class ContactActionCard extends StatelessWidget {
  const ContactActionCard({
    super.key,
    required this.displayName,
    required this.number,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onCall,
    this.matchedLead,
  });

  final String displayName;
  final String number;
  final bool isFavorite;

  /// Toggling on the Contacts screen; removing (always-on star) on the
  /// Favorites screen — same tap target, different semantics for the caller.
  final VoidCallback onToggleFavorite;
  final VoidCallback onCall;
  final CrmLead? matchedLead;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number copied'), duration: Duration(seconds: 1)));
  }

  Future<void> _sms() => launchUrl(Uri.parse('sms:$number'));

  Future<void> _whatsapp() {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    return launchUrl(Uri.parse('https://wa.me/$digits'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : '#';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarWithStar(
                initial: initial,
                ringColor: isFavorite ? kBrandColor : scheme.onSurfaceVariant.withValues(alpha: 0.35),
                starFilled: isFavorite,
                onStarTap: onToggleFavorite,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(number, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    if (matchedLead != null) ...[
                      const SizedBox(height: 6),
                      _CrmBadge(lead: matchedLead!),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionIcon(icon: Icons.copy_outlined, tooltip: 'Copy number', onTap: () => _copy(context)),
              _ActionIcon(icon: Icons.sms_outlined, tooltip: 'SMS', onTap: _sms),
              _ActionIcon(icon: Icons.chat_bubble_outline, tooltip: 'WhatsApp', onTap: _whatsapp),
              _ActionIcon(icon: Icons.call, tooltip: 'Call', onTap: onCall, accent: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarWithStar extends StatelessWidget {
  const _AvatarWithStar({
    required this.initial,
    required this.ringColor,
    required this.starFilled,
    required this.onStarTap,
  });

  final String initial;
  final Color ringColor;
  final bool starFilled;
  final VoidCallback onStarTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 2),
            ),
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              backgroundColor: scheme.surfaceContainerHigh,
              child: Text(initial, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: onStarTap,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(
                  starFilled ? Icons.star : Icons.star_border,
                  size: 13,
                  color: starFilled ? kBrandColor : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrmBadge extends StatelessWidget {
  const _CrmBadge({required this.lead});

  final CrmLead lead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kBrandColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(lead.isLead ? Icons.person_search : Icons.contacts, size: 12, color: kBrandColor),
          const SizedBox(width: 4),
          Text(
            lead.isLead ? (lead.status ?? 'Lead') : 'Contact',
            style: const TextStyle(color: kBrandColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.tooltip, required this.onTap, this.accent = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent ? kBrandColor.withValues(alpha: 0.15) : Colors.transparent,
          ),
          child: Icon(icon, size: 19, color: accent ? kBrandColor : scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
