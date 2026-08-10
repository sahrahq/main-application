import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../core/error/failure.dart';
import '../../../localization/generated/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/failure_copy.dart';
import '../domain/my_reservation.dart';
import 'my_reservations_notifier.dart';
import 'reservation_copy.dart';

/// C-4.4 — writing a review, from a visit that happened.
///
/// ─────────────────────────────────────────────────────────────────────────
/// NO REFERENCE, AND THE MOST INVENTED THING IN GROUP D
/// ─────────────────────────────────────────────────────────────────────────
///
/// There is no composer in any of the fourteen screen references, and
/// `RatingStars.d.ts` is display-only. So this is deliberately the plainest
/// form that could work: a heading that names the visit, one required rating,
/// three optional ones, a text field, a button. `SahraStarInput`,
/// `SahraInput` and `SahraButton` — nothing drawn here that is not already in
/// the design system.
///
/// ── THE SUBMIT BUTTON IS DISABLED UNTIL A RATING IS PICKED ───────────────
///
/// Rather than enabled-and-then-refused. The server requires 1–5 and would
/// answer 400; a button that looks ready and then fails teaches a diner that
/// the app is unreliable, when the app knew all along.
///
/// ── AND THE NAME NOTICE IS NOT SMALL PRINT ───────────────────────────────
///
/// "Your first name and the initial of your surname will be shown." That is a
/// consequence a diner cannot undo — a review is public and attached to a place
/// they were, on a night they were there. It sits above the button, not under
/// it, because a disclosure placed after the action is a disclosure nobody
/// reads.
Future<bool> showWriteReviewSheet(
  BuildContext context,
  MyReservation reservation,
) async {
  final posted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WriteReviewSheet(reservation: reservation),
  );
  return posted ?? false;
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet({required this.reservation});

  final MyReservation reservation;

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  int _rating = 0;
  int _food = 0;
  int _service = 0;
  int _ambience = 0;

  final TextEditingController _body = TextEditingController();

  bool _submitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final r = widget.reservation;

    return SahraPageWidth(
      child: Padding(
        // The keyboard. Without this the text field is behind it on every
        // phone in the matrix, and the diner types blind.
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
                l10n.writeReviewTitle,
                style: text.headlineSmall?.copyWith(color: s.textBody),
              ),
              const SizedBox(height: SahraSpace.s1),
              // WHICH VISIT. A diner with three past bookings at the same
              // venue has to be able to tell which one this is about.
              Text(
                l10n.writeReviewVenue(
                  venueName(r.venue, context),
                  dayAndMonth(r.date, context),
                ),
                style: text.bodySmall?.copyWith(color: s.textFaint),
              ),

              const SizedBox(height: SahraSpace.s5),
              SahraSectionLabel(l10n.writeReviewOverall),
              const SizedBox(height: SahraSpace.s1),
              SahraStarInput(
                value: _rating,
                onChanged: (v) => setState(() => _rating = v),
                semanticLabelFor: l10n.writeReviewStar,
              ),

              const SizedBox(height: SahraSpace.s4),
              SahraSectionLabel(l10n.writeReviewDetail),
              const SizedBox(height: SahraSpace.s1),
              _SubRatingRow(
                label: l10n.reviewFood,
                value: _food,
                onChanged: (v) => setState(() => _food = v),
              ),
              _SubRatingRow(
                label: l10n.reviewService,
                value: _service,
                onChanged: (v) => setState(() => _service = v),
              ),
              _SubRatingRow(
                label: l10n.reviewAmbience,
                value: _ambience,
                onChanged: (v) => setState(() => _ambience = v),
              ),

              const SizedBox(height: SahraSpace.s4),
              SahraInput(
                label: l10n.writeReviewBodyLabel,
                hint: l10n.writeReviewBodyHint,
                controller: _body,
                maxLines: 4,
                // 2000 matches the CHECK constraint. Enforced here as well so
                // the limit is felt as a limit rather than met as an error.
                maxLength: 2000,
              ),

              if (_failure != null) ...<Widget>[
                const SizedBox(height: SahraSpace.s3),
                Text(
                  failureMessage(_failure!, l10n),
                  style: text.bodySmall?.copyWith(color: s.error),
                ),
              ],

              const SizedBox(height: SahraSpace.s4),
              Text(
                l10n.reviewPublicNote,
                style: text.bodySmall?.copyWith(color: s.textFaint),
              ),
              const SizedBox(height: SahraSpace.s3),
              SizedBox(
                width: double.infinity,
                child: SahraButton(
                  label: _submitting
                      ? l10n.writeReviewSubmitting
                      : l10n.writeReviewSubmit,
                  // DISABLED, not enabled-and-refused. Null is how
                  // `SahraButton` renders its disabled state, and a screen
                  // reader announces it.
                  onPressed: _rating == 0 || _submitting ? null : _submit,
                ),
              ),
              if (_rating == 0) ...<Widget>[
                const SizedBox(height: SahraSpace.s2),
                Center(
                  child: Text(
                    l10n.writeReviewNeedsRating,
                    // Same treatment as the report sheet's equivalent. This one
                    // passes `textContrastGuideline` today and would start
                    // failing on a copy edit that changed its length — the
                    // check is length-sensitive because it is sampling
                    // anti-aliased edges. The line explaining a disabled button
                    // should not be the faintest text on the screen either way.
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

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _failure = null;
    });

    try {
      await ref.read(reservationRepositoryProvider).createReview(
            reservationId: widget.reservation.id,
            rating: _rating,
            // ZERO MEANS UNSET, and unset means absent. Sending 0 would fail
            // the 1–5 CHECK; sending a 3 the diner never chose would be worse
            // — it would put a number in the venue's average that nobody
            // meant.
            foodRating: _food == 0 ? null : _food,
            serviceRating: _service == 0 ? null : _service,
            ambienceRating: _ambience == 0 ? null : _ambience,
            body: _body.text,
          );

      // The bookings list carries `canReview`, which the server has just
      // flipped. Invalidated rather than patched locally: the flag is the
      // server's answer and re-deriving it here would be the second copy this
      // whole design avoids.
      ref.invalidate(myReservationsProvider);
      ref.invalidate(reservationDetailProvider(widget.reservation.id));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Failure catch (e) {
      // SHOWN IN THE SHEET, not as a SnackBar behind a sheet that closed. The
      // three real failures here — already reviewed, not eligible, too early —
      // are all things the diner needs to read while looking at what they
      // wrote.
      if (!mounted) return;
      setState(() {
        _failure = e;
        _submitting = false;
      });
    }
  }
}

class _SubRatingRow extends StatelessWidget {
  const _SubRatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    // WRAP, not Row. At 200% text on a 320pt screen the label and five 44pt
    // targets do not fit on one line, and a Row would overflow silently in a
    // release build — the defect class that is invisible to the person it
    // breaks for.
    return Padding(
      padding: SahraSpace.symmetric(vertical: SahraSpace.s1),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: SahraSpace.s2,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: s.textSoft),
            ),
          ),
          SahraStarInput(
            value: value,
            onChanged: onChanged,
            semanticLabelFor: l10n.writeReviewStar,
            size: 22,
          ),
        ],
      ),
    );
  }
}
