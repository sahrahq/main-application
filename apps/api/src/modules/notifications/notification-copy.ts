import { NOTIFICATION_TYPES, type NotificationType } from './notification.ports';

/**
 * Server-side push copy, in both languages.
 *
 * THIS IS THE ONE PLACE THE SERVER OWNS COPY, and it is worth being explicit
 * about why, because everywhere else the rule is the opposite (§7: the client
 * owns its copy, keyed by a machine-readable code).
 *
 * A push notification is rendered by the OPERATING SYSTEM, on a locked screen,
 * possibly while the app has never been opened. There is no client there to
 * localise anything. So the server must send finished text — and must choose
 * the language from the DEVICE's locale, not the account's, because a shared
 * handset and a traveller are both real.
 *
 * The in-app notification centre reads `type` + `data` and localises normally.
 * These strings exist only for the lock screen.
 *
 * ── AND NOT ONE OF THEM HAS REACHED A HUMAN ──────────────────────────────
 *
 * `LoggingPushDelivery` is still the bound adapter, so every string below is
 * written to a log and nowhere else. That is the state until the Firebase
 * project exists (`docs/decisions/2026-08-09-firebase-handover.md`). Worth
 * knowing before treating any of this wording as reviewed by use.
 *
 * Arabic is UNREVIEWED, like every other Arabic string in the repo.
 */
type Rendered = { title: string; body: string };

/** `d.date` and `d.time` as one phrase, with neither leaving a stray dash. */
function when(d: Record<string, string>): string {
  return [d.date, d.time].filter(Boolean).join(' ').trim();
}

const COPY: Record<NotificationType, Record<'ar' | 'en', (d: Record<string, string>) => Rendered>> = {
  reservation_cancelled_by_venue: {
    en: (d) => ({
      title: `${d.venue ?? 'The restaurant'} cancelled your table`,
      // The reason is included, not summarised. A diner reading "cancelled" on
      // a lock screen with no explanation will assume it was us.
      body: d.reason
        ? `${when(d)} — ${d.reason}`.trim()
        : `Your booking for ${when(d)} is no longer held.`.trim(),
    }),
    ar: (d) => ({
      title: `${d.venue ?? 'المطعم'} ألغى حجزك`,
      body: d.reason
        ? `${when(d)} — ${d.reason}`.trim()
        : `حجزك يوم ${d.date ?? ''} الساعة ${d.time ?? ''} مابقاش محجوز.`.trim(),
    }),
  },

  // THE CODE IS IN THE BODY, not only in the app. A diner standing at a door
  // with a locked phone can read a lock-screen notification; opening the app
  // needs a passcode and a signal.
  reservation_confirmed: {
    en: (d) => ({
      title: `Booked — ${d.venue ?? 'your table'}`,
      body: `${when(d)}${d.party ? ` · ${d.party} people` : ''}${
        d.code ? ` · ${d.code}` : ''
      }`.trim(),
    }),
    ar: (d) => ({
      title: `تم الحجز — ${d.venue ?? 'مطعمك'}`,
      body: `${when(d)}${d.party ? ` · ${d.party} أفراد` : ''}${
        d.code ? ` · ${d.code}` : ''
      }`.trim(),
    }),
  },

  reservation_reminder_24h: {
    en: (d) => ({
      title: `Tomorrow: ${d.venue ?? 'your booking'}`,
      // "Can't make it? Cancel" is not politeness. C-3.9 exists to reduce
      // no-shows, and the cheapest way to turn a no-show into a freed table is
      // to make cancelling the obvious second option in the reminder itself.
      body: `${when(d)}. Can't make it? Cancel in the app so the table goes to someone else.`,
    }),
    ar: (d) => ({
      title: `بكرة: ${d.venue ?? 'حجزك'}`,
      body: `${when(d)}. مش هتقدر تيجي؟ الغِ الحجز من التطبيق عشان الترابيزة تروح لحد تاني.`,
    }),
  },

  reservation_reminder_2h: {
    en: (d) => ({
      title: `In 2 hours: ${d.venue ?? 'your booking'}`,
      body: `${when(d)}${d.party ? ` · ${d.party} people` : ''}${
        d.code ? ` · ${d.code}` : ''
      }`.trim(),
    }),
    ar: (d) => ({
      title: `بعد ساعتين: ${d.venue ?? 'حجزك'}`,
      body: `${when(d)}${d.party ? ` · ${d.party} أفراد` : ''}${
        d.code ? ` · ${d.code}` : ''
      }`.trim(),
    }),
  },

  // ── THE COPY THAT IS NOT DOC 11's, AND MUST NOT BE ──────────────────────
  //
  // doc 11 §4 draws this as "Table available — claim in 10 min". It does not
  // say that, because the table is NOT held for them: the offer confers a
  // queue position, not a claim, until the withholding decision in
  // `docs/decisions/2026-08-09-group-g-split.md` §3.1 is taken. Promising a
  // ten-minute claim we do not enforce would send a diner to a slot somebody
  // else has already booked — which is a worse outcome than never telling
  // them, because they made a journey to the app for it.
  waitlist_offer: {
    en: (d) => ({
      title: `A table opened up at ${d.venue ?? 'a place you were waiting for'}`,
      body: `${when(d)}. Book now — it's first come, first served.`,
    }),
    ar: (d) => ({
      title: `فضيت ترابيزة في ${d.venue ?? 'مكان كنت مستنيه'}`,
      body: `${when(d)}. احجز دلوقتي — اللي يسبق يكسب.`,
    }),
  },

  waitlist_offer_expired: {
    en: (d) => ({
      title: `That table went at ${d.venue ?? 'the restaurant'}`,
      // Still on the list. Without this line the notification reads as "you
      // lost, goodbye", and a diner who thinks they have been dropped rejoins
      // — creating the duplicate the partial unique index then refuses, which
      // looks to them like the app is broken.
      body: `You're still on the list for ${d.date ?? 'that night'}.`,
    }),
    ar: (d) => ({
      title: `الترابيزة اتحجزت في ${d.venue ?? 'المطعم'}`,
      body: `لسه اسمك في القائمة ${d.date ? `ليوم ${d.date}` : 'لليلة دي'}.`,
    }),
  },
};

/** Render for a device's locale, falling back to Arabic — the primary. */
export function renderPush(
  type: NotificationType,
  data: Record<string, string>,
  locale: string,
): Rendered {
  const lang = locale.toLowerCase().startsWith('en') ? 'en' : 'ar';
  return COPY[type][lang](data);
}

/**
 * THE COPY TABLE IS ENUMERATED FROM THE TYPE LIST, not typed beside it.
 *
 * `Record<NotificationType, …>` makes the compiler demand an entry per type,
 * which is the real guard. This exists for the other direction and for the
 * runtime: a test walks `NOTIFICATION_TYPES` and renders every one in both
 * languages, so a type added with an entry that throws on missing `data` fails
 * in CI rather than on a lock screen.
 */
export function everyRenderableType(): readonly NotificationType[] {
  return NOTIFICATION_TYPES;
}
