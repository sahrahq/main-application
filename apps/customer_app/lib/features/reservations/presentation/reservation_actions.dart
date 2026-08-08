import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/failure_copy.dart';
import '../../../shared/widgets/sahra_async_view.dart';
import '../domain/booking.dart';
import '../domain/my_reservation.dart';
import 'my_reservations_notifier.dart';

/// The two things a diner can do to a booking they hold — C-3.4 and C-3.5.
///
/// ─────────────────────────────────────────────────────────────────────────
/// NO `.jsx` FOR EITHER OF THESE
/// ─────────────────────────────────────────────────────────────────────────
///
/// `ProfileScreen.jsx` has no edit control and there is no modify or cancel
/// reference anywhere in the design package — the fourteen screens stop at the
/// confirmation. Rather than invent a visual language, both sheets are built
/// entirely from components that already exist and are already specified:
/// `SahraDateStrip`, `SahraPartyStepper` and `SahraChip` are the same three the
/// booking screen uses, in the same order, so moving a booking looks like
/// making one. Reported as a gap rather than presented as matching a reference.
///
/// BOTH ARE SHEETS, NOT ROUTES. A modify is a decision about a booking the
/// diner is looking at; pushing a screen would take the booking off-screen
/// while they choose, and coming back from a failed move would land them on a
/// detail page with no explanation of what happened.

/// Ask, then cancel. Never cancel on the first tap.
///
/// A CONFIRMATION IS NOT FRICTION HERE. Cancelling is irreversible, it happens
/// on a screen whose other button is one row away, and a mis-tap costs the
/// diner a table they wanted — the asymmetry between "one extra tap" and "your
/// booking is gone" is the whole argument.
///
/// The reason field is OPTIONAL and it is the only caller of the API's
/// `reason` parameter. A parameter accepted by the server and supplied by
/// nobody is indistinguishable from one that does not work, so it is either
/// used here or it should not exist.
Future<void> showCancelSheet(
  BuildContext context,
  WidgetRef ref, {
  required MyReservation reservation,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _CancelSheet(reservation: reservation),
  );
}

/// Pick a new day, party and time — then move the booking.
Future<void> showMoveSheet(
  BuildContext context,
  WidgetRef ref, {
  required MyReservation reservation,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _MoveSheet(reservation: reservation),
  );
}

class _CancelSheet extends ConsumerStatefulWidget {
  const _CancelSheet({required this.reservation});

  final MyReservation reservation;

  @override
  ConsumerState<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<_CancelSheet> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final id = widget.reservation.id;
    final action = ref.watch(reservationActionProvider(id));
    final busy = action is ReservationActionBusy;

    return _SheetFrame(
      title: l10n.cancelSheetTitle,
      children: <Widget>[
        Text(
          l10n.cancelSheetBody,
          style: text.bodyMedium?.copyWith(color: s.textSoft),
        ),
        const SizedBox(height: SahraSpace.s5),
        SahraInput(
          label: l10n.cancelSheetReasonLabel,
          hint: l10n.cancelSheetReasonHint,
          variant: SahraInputVariant.line,
          controller: _reason,
        ),
        if (action is ReservationActionFailed) ...<Widget>[
          const SizedBox(height: SahraSpace.s4),
          Text(
            failureMessage(action.failure, l10n),
            style: text.bodySmall?.copyWith(color: s.error),
          ),
        ],
        const SizedBox(height: SahraSpace.s6),
        SahraButton(
          label: busy ? l10n.cancelSheetWorking : l10n.cancelSheetConfirm,
          // PRIMARY, NOT A DESTRUCTIVE VARIANT — because there isn't one.
          // `SahraButtonVariant` is primary | secondary | ghost | gold, and
          // adding a fifth is a design-token decision (CLAUDE.md: stop and ask
          // before deviating from a token). So the danger signal is carried by
          // the copy — the title asks a question, the body says it cannot be
          // undone — and the way out sits below with more visual weight than a
          // ghost button usually gets on a screen it is not the point of.
          //
          // Flagged for the product owner: a destructive variant is a real gap
          // in the design system, and this is the first screen to need one.
          onPressed: busy ? null : _confirm,
        ),
        const SizedBox(height: SahraSpace.s3),
        SahraButton(
          label: l10n.cancelSheetKeep,
          variant: SahraButtonVariant.ghost,
          // The way OUT is the plain one and it is second, so the destructive
          // button is never the one a thumb lands on by reflex.
          onPressed: busy ? null : () => unawaited(Navigator.of(context).maybePop()),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    final reason = _reason.text.trim();
    final ok = await ref
        .read(reservationActionProvider(widget.reservation.id).notifier)
        .cancel(reason: reason.isEmpty ? null : reason);

    // CLOSES ONLY ON SUCCESS. A sheet that pops on failure takes the error
    // message with it, and the diner is returned to a booking that still looks
    // live with no account of why.
    if (ok && mounted) await Navigator.of(context).maybePop();
  }
}

class _MoveSheet extends ConsumerWidget {
  const _MoveSheet({required this.reservation});

  final MyReservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final id = reservation.id;

    // Seeded from the booking, so the sheet opens where the diner already is.
    final draft = ref.watch(
      moveDraftProvider(id, reservation.date, reservation.partySize),
    );
    final notifier = ref.read(
      moveDraftProvider(id, reservation.date, reservation.partySize).notifier,
    );
    final action = ref.watch(reservationActionProvider(id));
    final busy = action is ReservationActionBusy;

    // Nothing picked yet is nothing to submit. Enabled-but-refusing is how a
    // form teaches people that its buttons lie.
    final changed = draft.startsAt != null || draft.partySize != reservation.partySize;

    return _SheetFrame(
      title: l10n.moveSheetTitle,
      children: <Widget>[
        SahraSectionLabel(l10n.bookDate),
        const SizedBox(height: SahraSpace.s2),
        SahraDateStrip(
          days: _nextWeek(context, ref),
          selectedId: draft.date,
          onSelected: busy ? (_) {} : notifier.setDate,
        ),
        const SizedBox(height: SahraSpace.s5),
        SahraSectionLabel(l10n.bookParty),
        const SizedBox(height: SahraSpace.s2),
        SahraPartyStepper(
          value: draft.partySize,
          onChanged: busy ? (_) {} : notifier.setPartySize,
          unitLabel: l10n.bookGuestsUnit(draft.partySize),
          decreaseLabel: l10n.bookDecreaseParty,
          increaseLabel: l10n.bookIncreaseParty,
        ),
        const SizedBox(height: SahraSpace.s5),
        SahraSectionLabel(l10n.bookTime),
        const SizedBox(height: SahraSpace.s2),
        SahraAsyncView<SlotBoard>(
          value: ref.watch(movableSlotsProvider(id, draft.date, draft.partySize)),
          onRetry: () => ref.invalidate(
            movableSlotsProvider(id, draft.date, draft.partySize),
          ),
          isEmpty: (board) => board.slots.isEmpty,
          loading: (_) => Wrap(
            spacing: SahraSpace.s2,
            runSpacing: SahraSpace.s2,
            children: <Widget>[
              for (var i = 0; i < 6; i++)
                const SahraSkeleton(width: 84, height: 40, radius: SahraRadius.pill),
            ],
          ),
          empty: (context) => SahraEmptyState(
            icon: 'lantern',
            title: l10n.bookNoSlotsTitle,
            message: l10n.bookNoSlotsMessage(draft.partySize),
          ),
          content: (context, board) => Wrap(
            spacing: SahraSpace.s2,
            runSpacing: SahraSpace.s2,
            children: <Widget>[
              for (final slot in board.slots)
                SahraChip(
                  label: slot.label,
                  active: draft.startsAt == slot.startsAt,
                  onPressed: busy ? null : () => notifier.choose(slot.startsAt),
                ),
            ],
          ),
        ),
        if (action is ReservationActionFailed) ...<Widget>[
          const SizedBox(height: SahraSpace.s4),
          Text(
            failureMessage(action.failure, l10n),
            style: text.bodySmall?.copyWith(color: s.error),
          ),
        ],
        const SizedBox(height: SahraSpace.s6),
        SahraButton(
          label: busy ? l10n.moveSheetWorking : l10n.moveSheetConfirm,
          onPressed: !changed || busy
              ? null
              : () async {
                  final ok = await ref.read(reservationActionProvider(id).notifier).modify(
                        startsAt: draft.startsAt,
                        // Sent only when it actually changed, so a diner
                        // moving the time alone does not re-assert a party
                        // size and re-run allocation for no reason.
                        partySize:
                            draft.partySize == reservation.partySize ? null : draft.partySize,
                      );
                  if (ok && context.mounted) await Navigator.of(context).maybePop();
                },
        ),
      ],
    );
  }

  /// Seven days AROUND THE BOOKING, not seven days from today.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// WHY THIS DIFFERS FROM THE BOOKING SCREEN
  /// ─────────────────────────────────────────────────────────────────────────
  ///
  /// The booking screen offers the next seven days, which is right: a new
  /// booking starts from now. A MOVE starts from the booking, and the two are
  /// not the same window. Copying the booking screen's strip verbatim produced
  /// a sheet whose date row could not contain the reservation's own date —
  /// caught in the walk-through, where a booking eleven days out opened on a
  /// strip of today..+6 with nothing selected at all.
  ///
  /// So the window is centred three days before the booking, clamped so it
  /// never offers a day in the past. "Same week, one evening later" is what a
  /// move almost always is, and that is now the middle of the row.
  ///
  /// A booking further out than the strip is still reachable one hop at a
  /// time — but note the LIMIT honestly: this cannot jump months. Moving a
  /// booking a long way is a cancel and a re-book, and that is the shape of
  /// this feature until somebody asks for a calendar.
  List<SahraDay> _nextWeek(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final weekday = DateFormat.E(locale);
    final full = DateFormat.yMMMMEEEEd(locale);

    final now = ref.watch(todayProvider);
    final today = DateTime(now.year, now.month, now.day);

    final booked = DateTime.tryParse(reservation.date) ?? today;
    // Three days of run-up, and never before today — an offered day that the
    // server would refuse is a slot picker that lies.
    final centred = DateTime(booked.year, booked.month, booked.day - 3);
    final start = centred.isBefore(today) ? today : centred;

    return List<SahraDay>.generate(7, (i) {
      final day = DateTime(start.year, start.month, start.day + i);
      return SahraDay(
        id: DateFormat('yyyy-MM-dd').format(day),
        label: day == today ? l10n.bookToday : weekday.format(day),
        // Latin figures in both locales (DESIGN-RULES.md) — an explicit 'en'
        // locale, or `DateFormat.d('ar')` renders Arabic-Indic numerals.
        number: DateFormat('d', 'en').format(day),
        semanticLabel: full.format(day),
      );
    });
  }
}

/// The shell both sheets share: a grabber, a title, and a scrolling body.
///
/// SCROLLABLE, and that is not optional. At 200% text a party stepper, a date
/// strip and a slot grid are taller than a phone, and a `RenderFlex` overflow
/// is SILENT in release builds — the person it breaks for is a diner running
/// large text on a mid-range Android, which is a large share of this market.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    // THE SCROLL VIEW IS THE OUTERMOST THING, and the order is the whole fix.
    //
    // `isScrollControlled: true` is needed so the keyboard does not cover the
    // reason field, and it lets the sheet grow to the full height of the
    // screen. `SahraPageWidth` is an `Align`, and an Align takes every point
    // its parent offers — so with it on the outside the sheet was always full
    // height, and the first cancel-sheet golden was a phone-tall panel with
    // two-thirds of it empty below the buttons.
    //
    // Inside the scroll view instead, the Align is handed UNBOUNDED height, so
    // it sizes to the column; `SingleChildScrollView` then takes the smaller of
    // that and the screen. Short content hugs, tall content scrolls, and at
    // 200% text it still scrolls rather than overflowing — which in a release
    // build would be silent.
    return SingleChildScrollView(
      // The keyboard, when the cancel sheet's reason field has focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SahraPageWidth(
        child: Padding(
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
              Text(title, style: text.headlineSmall?.copyWith(color: s.textBody)),
              const SizedBox(height: SahraSpace.s3),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
