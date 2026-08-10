import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../core/error/failure.dart';
import '../../../localization/generated/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/failure_copy.dart';
import '../domain/report_reason.dart';

/// C-4.4 — reporting a review.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE ONE LINE THAT MAKES THIS HONEST
/// ─────────────────────────────────────────────────────────────────────────
///
/// > "Reporting doesn't hide the review. A person reads it and decides."
///
/// It is above the button, not after it, and it is the most important thing on
/// the sheet. A report has **no visible effect**: the review stays on the page,
/// the venue's rating does not move, and nobody reads the report until A-3
/// builds the queue. A diner who expects the review to disappear and watches it
/// stay concludes the control is broken — and they are not wrong to, unless we
/// said so first.
///
/// The alternative was hiding the review on a single report. That would let one
/// account silence any review, with no moderator to release it, which is worse
/// than the honesty problem it solves.
///
/// ── AND NO REFERENCE, AGAIN ──────────────────────────────────────────────
///
/// Nothing in the design package contains a report flow. Plain and boring, per
/// the standing instruction: `SahraChip` for the reasons, `SahraInput` for the
/// note, `SahraButton` to send. Nothing drawn here is new.
Future<bool> showReportReviewSheet(
  BuildContext context, {
  required String reviewId,
}) async {
  final bool? sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReportSheet(reviewId: reviewId),
  );
  return sent ?? false;
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.reviewId});

  final String reviewId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final TextEditingController _note = TextEditingController();

  bool _sending = false;
  Failure? _failure;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _label(ReportReason reason, AppLocalizations l10n) => switch (reason) {
        ReportReason.spam => l10n.reviewReportReasonSpam,
        ReportReason.abusive => l10n.reviewReportReasonAbusive,
        // The one that is about US rather than the reviewer, so it is reachable
        // rather than folded into "something else".
        ReportReason.notMyVisit => l10n.reviewReportReasonNotMyVisit,
        ReportReason.wrongVenue => l10n.reviewReportReasonWrongVenue,
        ReportReason.other => l10n.reviewReportReasonOther,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return SahraPageWidth(
      child: Padding(
        // The keyboard, for the note field.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: SahraSpace.all(SahraSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: s.line,
                    borderRadius: BorderRadius.circular(SahraRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: SahraSpace.s5),
              Text(
                l10n.reviewReportTitle,
                style: text.headlineSmall?.copyWith(color: s.textBody),
              ),

              const SizedBox(height: SahraSpace.s5),
              SahraSectionLabel(l10n.reviewReportWhy),
              const SizedBox(height: SahraSpace.s2),
              Wrap(
                spacing: SahraSpace.s2,
                runSpacing: SahraSpace.s2,
                children: <Widget>[
                  for (final reason in ReportReason.values)
                    SahraChip(
                      label: _label(reason, l10n),
                      active: _reason == reason,
                      // SINGLE SELECT, and tapping the active one does NOT
                      // clear it — unlike the cuisine filter. A report with no
                      // reason is not a state worth being able to return to;
                      // the way out of this sheet is to close it.
                      onPressed: () => setState(() => _reason = reason),
                    ),
                ],
              ),

              const SizedBox(height: SahraSpace.s4),
              SahraInput(
                label: l10n.reviewReportNoteLabel,
                hint: l10n.reviewReportNoteHint,
                controller: _note,
                maxLines: 3,
                // 1000 matches the CHECK constraint.
                maxLength: 1000,
              ),

              if (_failure != null) ...<Widget>[
                const SizedBox(height: SahraSpace.s3),
                Text(
                  failureMessage(_failure!, l10n),
                  style: text.bodySmall?.copyWith(color: s.error),
                ),
              ],

              const SizedBox(height: SahraSpace.s4),
              // ABOVE THE BUTTON. A disclosure placed after the action is a
              // disclosure nobody reads, and this one is the difference between
              // a control that seems broken and one that did what it said.
              Text(
                l10n.reviewReportHonest,
                style: text.bodySmall?.copyWith(color: s.textFaint),
              ),
              const SizedBox(height: SahraSpace.s3),
              SizedBox(
                width: double.infinity,
                child: SahraButton(
                  label: _sending
                      ? l10n.reviewReportSubmitting
                      : l10n.reviewReportSubmit,
                  // Disabled until a reason is picked, rather than enabled and
                  // then refused by the server.
                  onPressed: _reason == null || _sending ? null : _send,
                ),
              ),
              if (_reason == null) ...<Widget>[
                const SizedBox(height: SahraSpace.s2),
                Center(
                  child: Text(
                    l10n.reviewReportNoReasonYet,
                    // NOT `textFaint`, and not the default weight.
                    //
                    // This sentence is the only explanation of why the primary
                    // button is dead, and it was the faintest, thinnest text on
                    // the sheet. `textContrastGuideline` failed it at 2.10:1 in
                    // ARABIC ONLY — and the measurement was of an anti-aliased
                    // edge, not of the colour: `textFaint` on `surfaceCard` is
                    // 5.82:1, and once the sampler picks a 50% edge even PURE
                    // BLACK scores 3.92, so no colour could have passed.
                    //
                    // What it was really reporting is that Arabic at 13pt in a
                    // thin weight has more anti-aliased edge than glyph core.
                    // That is true, and it is a legibility fact rather than a
                    // measurement artefact — so the fix is more ink, which is
                    // also the right call for the one line that explains a
                    // disabled action.
                    style: text.bodySmall?.copyWith(
                      color: s.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: SahraSpace.s3),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _failure = null;
    });

    try {
      await ref.read(restaurantRepositoryProvider).reportReview(
            reviewId: widget.reviewId,
            reason: _reason!,
            note: _note.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Failure catch (e) {
      // IN THE SHEET, not behind it. The two real failures here — you have
      // already reported this, and it is your own review — are both things the
      // diner needs to read while looking at what they were doing.
      if (!mounted) return;
      setState(() {
        _failure = e;
        _sending = false;
      });
    }
  }
}
