import 'package:flutter/widgets.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../reservations/presentation/reservation_copy.dart';
import '../domain/app_notification.dart';

/// A notification's `type` + `data` → the two lines a diner reads.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE CLIENT OWNS EVERY WORD, AND THAT IS WHY THIS FILE EXISTS
/// ─────────────────────────────────────────────────────────────────────────
///
/// doc 06 §7's rule, the same one the error envelope follows: the server sends
/// a machine-readable kind and the values to substitute, and the sentence is
/// assembled here from the ARB. Switching the app to Arabic re-renders
/// notifications recorded months ago in English — copy baked in at write time
/// could not do that.
///
/// The server DOES render finished text in one place, `notification-copy.ts`,
/// and only for a lock screen, where the OS draws the notification and there is
/// no client to localise anything.
///
/// ── EVERY FIELD IS TREATED AS ABSENT UNTIL PROVEN OTHERWISE ──────────────
///
/// `data` is a free-shaped map from a server that may be a release ahead. A
/// missing `venue` must produce a slightly vaguer sentence, never an empty row
/// and never a crash — this screen is where a diner goes to find out their
/// table was cancelled, and it has to render on the day something is wrong.
class NotificationCopy {
  const NotificationCopy({
    required this.title,
    required this.body,
    required this.icon,
    this.quote,
  });

  final String title;

  /// Empty when the kind has nothing more to say. The row draws no second line
  /// rather than an empty one.
  final String body;

  /// A whole clause somebody at the venue TYPED — today, only a cancellation
  /// reason. Its own line, in its own direction.
  ///
  /// ── WHY IT IS NOT JUST INTERPOLATED INTO [body] ─────────────────────────
  ///
  /// It was, and the Arabic golden showed the cost: an English reason inside an
  /// Arabic line wraps mid-phrase, so «… — A burst pipe in the» ends one line
  /// and «kitchen» begins the next at the opposite edge. Correct per Unicode
  /// and unreadable in practice.
  ///
  /// A clause of somebody else's prose is a PARAGRAPH of user content, which is
  /// what `contentDirection` exists for — the same call the reviews list makes.
  /// An isolate cannot help, because the problem is not a run inside our
  /// sentence; it is a sentence that is not ours.
  final String? quote;

  /// A `SahraIcon` name, and it must be one the set actually HAS.
  ///
  /// `SahraIcon` falls back to `Icons.help_outline` for a name it does not
  /// know, so an invented name renders as a question mark in a circle — beside
  /// a cancellation, that reads "we don't know what happened". The first draft
  /// used `x-circle` and `info`, neither of which exists, and the Arabic golden
  /// is where it showed.
  ///
  /// `test/features/notifications_test.dart` now checks every kind's icon against
  /// `SahraIcon.drawnIcons + SahraIcon.fallbackIcons`, so the next invented
  /// name fails in CI rather than in a picture somebody has to notice.
  final String icon;
}

/// Null when there is nothing sensible to draw — an unrecognised kind from a
/// newer server. The row is skipped rather than shown blank.
NotificationCopy? notificationCopy(AppNotification n, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final ar = Localizations.localeOf(context).languageCode == 'ar';

  // BOTH NAMES TRAVEL IN `data`, because the notification was recorded before
  // anyone knew which language it would be read in — and a diner who switches
  // the app to Arabic must not find their history still in English.
  //
  // `isolate`, not `ltrRun`: the venue names ITSELF, so it may be in either
  // script, and a left-to-right isolate around «ليالي لاونج» would lay it out
  // backwards. U+2068 lets the run pick its own direction and keeps its
  // punctuation from escaping into our sentence.
  final String venue = isolate(
    _pick(n.data, ar ? 'venue_ar' : 'venue', ar ? 'venue' : 'venue_ar') ?? l10n.notifFallbackVenue,
  );

  final String date = _date(n.data['date'], context);
  // `ltrRun` — a clock time is Latin digits with a colon inside Arabic prose,
  // and without the isolate the bidi algorithm moves it to the wrong end.
  final String time = ltrRun(n.data['time'] ?? '');
  final String party = ltrRun(n.data['party'] ?? '');
  final String code = ltrRun(n.data['code'] ?? '');
  // NOT isolated and NOT interpolated — see [NotificationCopy.quote]. A whole
  // clause the venue typed gets its own line and its own direction.
  final String? reason = _nonEmpty(n.data['reason']);

  return switch (n.kind) {
    NotificationKind.reservationCancelledByVenue => NotificationCopy(
        title: l10n.notifCancelledTitle(venue),
        body: l10n.notifCancelledBody(date, time),
        // The reason, when there is one. A diner reading "cancelled" with no
        // explanation assumes it was us — the same argument as the push copy.
        quote: reason,
        icon: 'x',
      ),
    NotificationKind.reservationConfirmed => NotificationCopy(
        title: l10n.notifConfirmedTitle(venue),
        body: l10n.notifConfirmedBody(date, time, party, code),
        icon: 'calendar',
      ),
    NotificationKind.reservationReminder24h => NotificationCopy(
        title: l10n.notifReminder24hTitle(venue),
        body: l10n.notifReminder24hBody(time),
        icon: 'clock',
      ),
    NotificationKind.reservationReminder2h => NotificationCopy(
        title: l10n.notifReminder2hTitle(venue),
        body: l10n.notifReminder2hBody(time, party, code),
        icon: 'clock',
      ),
    NotificationKind.waitlistOffer => NotificationCopy(
        title: l10n.notifWaitlistOfferTitle(venue),
        // "First come, first served", not doc 11's "claim in 10 minutes". The
        // table is NOT held for them — see
        // `docs/decisions/2026-08-09-group-g-split.md` §3.1. Sending a diner to
        // a slot somebody else already took is worse than never telling them.
        body: l10n.notifWaitlistOfferBody(date, time),
        icon: 'bell',
      ),
    NotificationKind.waitlistOfferExpired => NotificationCopy(
        title: l10n.notifWaitlistExpiredTitle(venue),
        // They ARE still on the list — the entry returns to `waiting`. If the
        // server ever moves it to `expired` instead, this line becomes a lie
        // and has to change in the same commit.
        body: l10n.notifWaitlistExpiredBody(date),
        icon: 'bell',
      ),
    // A kind this build has never heard of. Skipped, not drawn blank: the app
    // on a diner's phone is whatever they last updated to, and a type added
    // next month must not put an empty row in their history.
    NotificationKind.unknown => null,
  };
}

/// First non-empty of [first] then [fallback].
String? _pick(Map<String, String> data, String first, String fallback) =>
    _nonEmpty(data[first]) ?? _nonEmpty(data[fallback]);

String? _nonEmpty(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

/// `2026-08-10` → `10 August`, falling back to whatever was sent.
String _date(String? iso, BuildContext context) =>
    iso == null || iso.isEmpty ? '' : dayAndMonth(iso, context);
