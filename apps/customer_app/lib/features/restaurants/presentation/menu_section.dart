import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../shared/widgets/venue_image_provider.dart';
import '../domain/menu.dart';
import 'menu_copy.dart';
import 'menu_notifier.dart';

/// R-2.3 / C-2.6 — the menu, on the venue page and in a sheet.
///
/// ─────────────────────────────────────────────────────────────────────────
/// PART OF THIS HAS A REFERENCE AND PART OF IT DOES NOT
/// ─────────────────────────────────────────────────────────────────────────
///
/// `VenueDetailScreen.jsx` lines 42–53 draw the PREVIEW: a heading, a "Full
/// menu" affordance opposite it, and four rows of dish / category / price with
/// a hairline between them. That is matched here row for row.
///
/// **The full menu screen has no reference.** In the reference, "Full menu" is
/// a `<div>` with `cursor:pointer` and no `onClick` — it opens nothing there
/// either. Fourteen `.jsx` screens and none of them is a menu.
///
/// So the sheet below is invented, under the instruction for exactly this
/// case: keep it plain and boring, compose it from components that already
/// exist, and do not introduce a visual language a later reference would have
/// to contradict. It is the preview's own row, repeated, under section labels
/// that are the same `SahraSectionLabel` every other screen uses.
///
/// ── AND THE PDF ──────────────────────────────────────────────────────────
///
/// R-2.3's fallback, for the venues whose whole menu is one scanned file. No
/// PDF is rendered in-app: no PDF package is in the doc 08 stack table, and
/// asking for one to display a document the phone already opens would be the
/// wrong trade. Same handoff shape as the map decision.

/// The preview block for the venue page. Draws nothing at all when the venue
/// has no menu — a heading over an empty state, on a page that already has
/// content, is worse than the absence.
class MenuSection extends ConsumerWidget {
  const MenuSection({required this.idOrSlug, super.key});

  final String idOrSlug;

  /// Four, as the reference draws.
  static const int previewCount = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final menus = ref.watch(venueMenusProvider(idOrSlug));

    // NOT SahraAsyncView. That widget owns the whole screen's four states, and
    // this is a section inside a page that has already loaded: a full-page
    // spinner or failure view here would replace a venue profile the diner is
    // reading because a secondary request is slow. Absent while loading,
    // absent on failure, present when there is something to show.
    final list = menus.valueOrNull;
    if (list == null || list.isEmpty) return const SizedBox.shrink();

    final primary = list.first;
    final preview = primary.preview(previewCount);
    if (preview.isEmpty && primary.pdfUrl == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.venueMenuTitle,
                style: text.titleLarge?.copyWith(color: s.textBody),
              ),
            ),
            // "Full menu" — the reference sets `--gold-dark` here, which
            // measures 2.5–2.8:1 as text. AA wins over the reference without
            // asking, so it ships as `accentOnSurface`, same as Discover's
            // "See all".
            _TextAction(
              label: l10n.venueMenuFull,
              onPressed: () => showMenuSheet(context, list),
            ),
          ],
        ),
        const SizedBox(height: SahraSpace.s2),
        for (final row in preview)
          _MenuRow(item: row.item, category: row.category, showImage: false),
        if (preview.isEmpty && primary.pdfUrl != null)
          Padding(
            padding: SahraSpace.inset(top: SahraSpace.s2),
            child: Text(
              l10n.menuPdfNote,
              style: text.bodySmall?.copyWith(color: s.textFaint),
            ),
          ),
      ],
    );
  }
}

/// The full menu. Every menu, every category, every available item.
Future<void> showMenuSheet(BuildContext context, List<Menu> menus) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MenuSheet(menus: menus),
  );
}

class _MenuSheet extends StatelessWidget {
  const _MenuSheet({required this.menus});

  final List<Menu> menus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return SahraPageWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: SahraSpace.s3),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: s.line,
              borderRadius: BorderRadius.circular(SahraRadius.pill),
            ),
          ),
          // FLEXIBLE, not a fixed fraction of the screen. A one-item menu
          // should not open a sheet three quarters of the way up an empty
          // panel, and a forty-item one has to be able to fill it.
          Flexible(
            child: ListView(
              padding: SahraSpace.all(SahraSpace.s5),
              shrinkWrap: true,
              children: <Widget>[
                Text(
                  l10n.menuSheetTitle,
                  style: text.headlineSmall?.copyWith(color: s.textBody),
                ),
                for (final menu in menus) ...<Widget>[
                  const SizedBox(height: SahraSpace.s5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          menu.name,
                          style: text.titleLarge?.copyWith(color: s.textBody),
                        ),
                      ),
                      if (menu.itemCount > 0)
                        Text(
                          l10n.menuItemCount(menu.itemCount),
                          style: text.bodySmall?.copyWith(color: s.textFaint),
                        ),
                    ],
                  ),
                  if (menu.pdfUrl != null) ...<Widget>[
                    const SizedBox(height: SahraSpace.s3),
                    _PdfHandoff(url: menu.pdfUrl!),
                  ],
                  for (final category in menu.categories) ...<Widget>[
                    const SizedBox(height: SahraSpace.s4),
                    SahraSectionLabel(category.name),
                    const SizedBox(height: SahraSpace.s2),
                    for (final item in category.items)
                      _MenuRow(item: item, category: null, showImage: true),
                  ],
                ],
                const SizedBox(height: SahraSpace.s5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One dish. The reference's row: name and category on the start side, price on
/// the end, a hairline underneath.
class _MenuRow extends ConsumerWidget {
  const _MenuRow({
    required this.item,
    required this.category,
    required this.showImage,
  });

  final MenuItem item;

  /// Shown on the PREVIEW, where rows come from different categories and the
  /// label is what tells them apart. Null inside the sheet, where the section
  /// heading above already says it.
  final String? category;

  final bool showImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final tags = <String>[
      for (final key in item.dietaryTags)
        if (dietaryLabel(key, l10n) != null) dietaryLabel(key, l10n)!,
    ];

    return Container(
      padding: SahraSpace.symmetric(vertical: SahraSpace.s3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showImage && item.image != null) ...<Widget>[
            SizedBox(
              width: 56,
              child: SahraPhoto(
                height: 56,
                radius: SahraRadius.md,
                image: venueImageProvider(context, ref, item.image, slotWidth: 56),
              ),
            ),
            const SizedBox(width: SahraSpace.s3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  // Venue-typed content: a venue that filled in only `name_en`
                  // shows Latin text on the Arabic page, and its comma or full
                  // stop would change sides.
                  textDirection: contentDirection(item.name),
                  style: text.bodyMedium?.copyWith(
                    color: s.textBody,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (category != null)
                  Text(
                    category!,
                    style: text.labelSmall?.copyWith(color: s.textFaint),
                  ),
                if (item.description != null)
                  Padding(
                    padding: SahraSpace.inset(top: SahraSpace.s1),
                    child: Text(
                      item.description!,
                      textDirection: contentDirection(item.description!),
                      style: text.bodySmall?.copyWith(color: s.textSoft),
                    ),
                  ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: SahraSpace.inset(top: SahraSpace.s2),
                    child: Wrap(
                      spacing: SahraSpace.s1,
                      runSpacing: SahraSpace.s1,
                      children: <Widget>[
                        for (final label in tags) SahraBadge(label: label),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SahraSpace.s3),
          // ISOLATED. "320.00 EGP" is a number followed by a Latin run, and in
          // an Arabic paragraph the two swap sides — the price would read
          // «ج.م 320.00» in English word order and «EGP» would jump the number.
          // Same defect class as the phone number and the rating chip, and now
          // caught by `bidi_neutral_test.dart` if the copy ever grows a sign.
          Text(
            ltrRun(l10n.menuPrice(item.price, currencyLabel(item.currency, l10n))),
            style: SahraTypography.numeric(
              text.bodyMedium!.copyWith(
                color: s.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// R-2.3's fallback: hand the document to whatever the phone already has.
class _PdfHandoff extends StatelessWidget {
  const _PdfHandoff({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SahraButton(
          label: l10n.menuPdfOpen,
          variant: SahraButtonVariant.secondary,
          onPressed: () => unawaited(
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
        ),
        const SizedBox(height: SahraSpace.s1),
        // SAID BEFORE IT HAPPENS. A tap that throws the diner out of the app
        // into a browser is a surprise unless the control admits it will.
        Text(
          l10n.menuPdfNote,
          style: text.bodySmall?.copyWith(color: s.textFaint),
        ),
      ],
    );
  }
}

/// A text-only action with a real touch target around it.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SahraRules.minTouchTarget),
        child: Align(
          child: Text(
            label,
            style: text.bodySmall?.copyWith(
              // AA over the reference's gold, without asking.
              color: s.accentOnSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
