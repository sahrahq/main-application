import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/failure_copy.dart';
import '../../../shared/widgets/sahra_async_view.dart';
import '../domain/booking.dart';
import 'booking_notifier.dart';
import 'pending_booking.dart';

/// `docs/design/ui_kits/app/BookingFlowScreen.jsx`.
///
/// WHAT IS NOT HERE:
///
///   - **The "notify me" bells on sold-out slots.** The reference draws
///     dashed, struck-through chips with a bell for full times. The waitlist
///     (C-3.6) is **P1** and `/waitlists` does not exist, so a bell here would
///     be a promise nothing keeps. Availability returns only free slots today,
///     so there are no sold-out chips to draw either — `Env.enableWaitlist`
///     gates this when the endpoints land.
///   - **Seating preference, occasion, special requests.** The API accepts all
///     three (C-3.2) and the domain passes them through; the review sheet that
///     collects them is the next screen, not this one.
class BookScreen extends ConsumerWidget {
  const BookScreen({required this.restaurantId, required this.venueName, super.key});

  final String restaurantId;

  /// Passed through the route so the screen has a title before the profile
  /// loads. A booking screen that says "Loading…" where the venue name goes
  /// makes the diner wonder what they are booking.
  final String venueName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final criteria = ref.watch(bookingSelectionProvider(restaurantId));
    final progress = ref.watch(bookingFlowProvider(restaurantId));

    // Confirmation is a screen, not a state of this one — a diner who reaches
    // it should not be able to swipe back into a half-finished booking form.
    ref.listen(bookingFlowProvider(restaurantId), (_, next) {
      if (next is BookingDone) {
        ConfirmedRoute(
          next.booking.code,
          venueName,
          next.booking.startsAt,
          next.booking.partySize,
          // The WALL CLOCK, carried out of the flow rather than recomputed.
          // `Booking` returns only absolute instants, so deriving it here from
          // `startsAt` is precisely the defect this argument exists to close.
          next.wallClock,
        ).go(context);
      }
      if (next is BookingNeedsSignIn) _signInRoundTrip(context, ref, next.selection);
    });

    return Scaffold(
      appBar: SahraAppBar(
        title: Text(l10n.bookTitle),
        leading: IconButton(
          icon: const SahraIcon('arrow-back'),
          tooltip: l10n.venueBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SahraPageWidth(
        child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ONE scroll view over the header AND the slots.
            //
            // This was a fixed header above `Expanded(slots)`. At 320x568 with
            // 200% text the header alone is taller than the body, so Expanded
            // was handed nothing and the Column overflowed by 101px — on the
            // smallest phone we support, at the text size a lot of Egyptian
            // users on mid-range Androids actually run.
            //
            // The footer stays OUTSIDE it: the confirm button and the
            // cancellation policy must not scroll away from the thing they
            // confirm.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
            Padding(
              padding: SahraSpace.all(SahraSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SahraSectionLabel(l10n.bookDate),
                  const SizedBox(height: SahraSpace.s2),
                  SahraDateStrip(
                    days: _nextWeek(context, ref),
                    selectedId: criteria.date,
                    onSelected:
                        ref.read(bookingSelectionProvider(restaurantId).notifier).setDate,
                  ),
                  const SizedBox(height: SahraSpace.s5),
                  SahraSectionLabel(l10n.bookParty),
                  const SizedBox(height: SahraSpace.s2),
                  SahraPartyStepper(
                    value: criteria.partySize,
                    onChanged:
                        ref.read(bookingSelectionProvider(restaurantId).notifier).setPartySize,
                    unitLabel: l10n.bookGuestsUnit(criteria.partySize),
                    decreaseLabel: l10n.bookDecreaseParty,
                    increaseLabel: l10n.bookIncreaseParty,
                  ),
                  const SizedBox(height: SahraSpace.s5),
                  SahraSectionLabel(l10n.bookTime),
                ],
              ),
            ),
                    _Slots(restaurantId: restaurantId, progress: progress),
                  ],
                ),
              ),
            ),
            _Footer(restaurantId: restaurantId, venueName: venueName, progress: progress),
          ],
        ),
        ),
      ),
    );
  }

  /// The C-1.6 detour: park the selection, go and sign in, come back to it.
  ///
  /// FIVE THINGS THIS HAS TO GET RIGHT, and each of them has a test:
  ///
  ///   1. A guest tapping a slot is sent to sign-in with the selection parked,
  ///      not shown a 401.
  ///   2. Coming back, the same slot on the same date for the same party is
  ///      still selected. The restore below is explicit rather than trusting
  ///      the providers to have survived underneath a pushed route.
  ///   3. The hold is re-attempted automatically. If the table went in the
  ///      meantime the diner lands on a REFRESHED grid with the conflict
  ///      banner — the existing `BookingSlotTaken` path, reached the ordinary
  ///      way, not a second dead-end error.
  ///   4. Backing out of sign-in leaves the selection on screen and attempts
  ///      NOTHING. `push` returning anything other than `true` is the whole
  ///      test — no flag, no timer, no "did they maybe sign in" heuristic.
  ///   5. An app restart loses the selection, and because nothing here runs on
  ///      build, a restart cannot re-attempt anything.
  ///
  /// The ORDER of the restore matters: `ChosenSlot` clears itself whenever the
  /// date or party size changes, so the slot has to be chosen last or it is
  /// wiped by the two lines above it.
  Future<void> _signInRoundTrip(
    BuildContext context,
    WidgetRef ref,
    PendingSelection selection,
  ) async {
    ref.read(pendingBookingProvider(restaurantId).notifier).remember(selection);

    final signedIn = await SignInRoute(restaurantId).push(context);
    if (!context.mounted) return;

    final pending = ref.read(pendingBookingProvider(restaurantId));
    if (pending == null) return;

    ref.read(bookingSelectionProvider(restaurantId).notifier).setDate(pending.date);
    ref.read(bookingSelectionProvider(restaurantId).notifier).setPartySize(pending.partySize);
    ref.read(chosenSlotProvider(restaurantId).notifier).choose(pending.startsAt);

    if (signedIn != true) {
      // Backed out. The selection stays on screen — they may sign in on the
      // second try — but the flow returns to idle so the sign-in sheet does not
      // reopen the moment this widget rebuilds.
      ref.read(bookingFlowProvider(restaurantId).notifier).reset();
      return;
    }

    // Cleared BEFORE the re-attempt, not after. If the re-attempt itself 401s
    // (a token that expired between the two calls) it produces a fresh
    // `BookingNeedsSignIn` carrying the same selection, and leaving the old one
    // parked would make that indistinguishable from a stale one.
    ref.read(pendingBookingProvider(restaurantId).notifier).clear();
    await ref.read(bookingFlowProvider(restaurantId).notifier).book(
          startsAt: pending.startsAt,
          partySize: pending.partySize,
          selection: pending,
        );
  }

  /// Seven days from today. The first reads "Tonight" rather than a weekday,
  /// as the reference does.
  List<SahraDay> _nextWeek(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final weekday = DateFormat.E(locale);
    final full = DateFormat.yMMMMEEEEd(locale);
    final today = ref.watch(todayProvider);

    return List<SahraDay>.generate(7, (i) {
      final day = DateTime(today.year, today.month, today.day + i);
      final id = DateFormat('yyyy-MM-dd').format(day);
      return SahraDay(
        id: id,
        label: i == 0 ? l10n.bookToday : weekday.format(day),
        // Latin digits in both locales (DESIGN-RULES.md), so an explicit 'en'
        // locale rather than the ambient one — `DateFormat.d('ar')` renders
        // Arabic-Indic numerals, which is the exact defect wave 3 found in
        // test data.
        number: DateFormat('d', 'en').format(day),
        semanticLabel: full.format(day),
      );
    });
  }
}

class _Slots extends ConsumerWidget {
  const _Slots({required this.restaurantId, required this.progress});

  final String restaurantId;
  final BookingProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final criteria = ref.watch(bookingSelectionProvider(restaurantId));

    return SahraAsyncView<SlotBoard>(
      value: ref.watch(availableSlotsProvider(restaurantId)),
      onRetry: () => ref.invalidate(availableSlotsProvider(restaurantId)),
      isEmpty: (board) => board.slots.isEmpty,
      loading: (_) => Padding(
        padding: SahraSpace.symmetric(horizontal: SahraSpace.s5),
        child: Wrap(
          spacing: SahraSpace.s2,
          runSpacing: SahraSpace.s2,
          children: <Widget>[
            for (var i = 0; i < 8; i++)
              const SahraSkeleton(width: 84, height: 40, radius: SahraRadius.pill),
          ],
        ),
      ),
      // Scrollable, because at 200% text this empty state is taller than the
      // Expanded it sits in — and a RenderFlex overflow is SILENT in release
      // builds, so the person it breaks for is a diner running large text on
      // a mid-range Android, which is a large share of this market.
      // Found by textScaleMatrix in all four cells.
      // No scroll view of its own: the whole screen body is one, and nesting
      // two gives the inner one unbounded height.
      empty: (context) => Padding(
        padding: SahraSpace.symmetric(horizontal: SahraSpace.s5),
        child: SahraEmptyState(
          icon: 'lantern',
          title: l10n.bookNoSlotsTitle,
          message: l10n.bookNoSlotsMessage(criteria.partySize),
        ),
      ),
      content: (context, board) => Padding(
        padding: SahraSpace.symmetric(horizontal: SahraSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The conflict banner sits ABOVE the refreshed slots, so the
            // diner reads what happened and sees the alternatives in one
            // glance (11-user-flows §3, node M → B).
            if (progress is BookingSlotTaken || progress is BookingHoldExpired)
              Padding(
                padding: SahraSpace.inset(bottom: SahraSpace.s4),
                child: _ConflictBanner(progress: progress),
              ),
            Wrap(
              spacing: SahraSpace.s2,
              runSpacing: SahraSpace.s2,
              children: <Widget>[
                for (final slot in board.slots)
                  SahraChip(
                    label: slot.label,
                    active: ref.watch(chosenSlotProvider(restaurantId)) == slot.startsAt,
                    onPressed: () => ref
                        .read(chosenSlotProvider(restaurantId).notifier)
                        .choose(slot.startsAt),
                  ),
              ],
            ),
            const SizedBox(height: SahraSpace.s5),
          ],
        ),
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.progress});

  final BookingProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final expired = progress is BookingHoldExpired;
    final title = expired ? l10n.bookHoldExpiredTitle : l10n.bookSlotTakenTitle;
    final body = expired ? l10n.bookHoldExpiredMessage : l10n.bookSlotTakenMessage;

    return Container(
      width: double.infinity,
      padding: SahraSpace.all(SahraSpace.s4),
      decoration: BoxDecoration(
        color: s.tintFor(s.warning),
        borderRadius: SahraRadius.allOf(SahraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            // body-s at 700, NOT the 11px overline: a coloured micro-label
            // fails contrast at 11px and fails in Arabic first
            // (ENGINEERING-STANDARDS, "Small COLOURED text").
            style: text.bodySmall?.copyWith(
              color: s.warningOnTint,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SahraSpace.s1),
          Text(body, style: text.bodySmall?.copyWith(color: s.warningOnTint)),
        ],
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({
    required this.restaurantId,
    required this.venueName,
    required this.progress,
  });

  final String restaurantId;

  /// Only so a parked selection can name the venue on the sign-in screen. The
  /// footer itself never shows it.
  final String venueName;

  final BookingProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final criteria = ref.watch(bookingSelectionProvider(restaurantId));
    final chosen = ref.watch(chosenSlotProvider(restaurantId));
    final board = ref.watch(availableSlotsProvider(restaurantId)).valueOrNull;
    final inFlight = progress is BookingInFlight;

    final slot = board?.slots.where((s) => s.startsAt == chosen).firstOrNull;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surfacePage,
        border: Border(top: BorderSide(color: s.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: SahraSpace.all(SahraSpace.s5),
          child: Column(
            children: <Widget>[
              // A non-conflict failure — offline, 500 — belongs here, next to
              // the button that failed, not over the slot list.
              if (progress is BookingFailed) ...<Widget>[
                Text(
                  failureMessage((progress as BookingFailed).failure, l10n),
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: s.error),
                ),
                const SizedBox(height: SahraSpace.s3),
              ],
              SahraButton(
                label: inFlight
                    ? l10n.bookHolding
                    : l10n.bookConfirmFor(criteria.partySize, slot?.label ?? '—'),
                // Disabled until a slot is chosen AND while the hold is in
                // flight. A second tap during the round trip is the classic
                // double-booking attempt; the idempotency key would make it
                // harmless, but not offering it is better than relying on that.
                onPressed: slot == null || inFlight
                    ? null
                    : () => ref.read(bookingFlowProvider(restaurantId).notifier).book(
                          startsAt: slot.startsAt,
                          partySize: criteria.partySize,
                          // Built HERE, at the tap, not reconstructed later
                          // from whatever the providers hold after a detour.
                          // `slotLabel` in particular exists nowhere else: the
                          // board that produced it is refetched on return and
                          // may not contain this time any more, which is
                          // exactly the case where the sign-in screen still has
                          // to be able to say which table is waiting.
                          selection: PendingSelection(
                            restaurantId: restaurantId,
                            venueName: venueName,
                            startsAt: slot.startsAt,
                            slotLabel: slot.label,
                            date: criteria.date,
                            partySize: criteria.partySize,
                          ),
                        ),
              ),
              const SizedBox(height: SahraSpace.s3),
              Text(
                l10n.bookCancellationPolicy,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: s.textSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
