import type { NotificationType } from './notification.ports';

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
 * Arabic is UNREVIEWED, like every other Arabic string in the repo.
 */
type Rendered = { title: string; body: string };

const COPY: Record<NotificationType, Record<'ar' | 'en', (d: Record<string, string>) => Rendered>> = {
  reservation_cancelled_by_venue: {
    en: (d) => ({
      title: `${d.venue ?? 'The restaurant'} cancelled your table`,
      // The reason is included, not summarised. A diner reading "cancelled" on
      // a lock screen with no explanation will assume it was us.
      body: d.reason
        ? `${d.date ?? ''} ${d.time ?? ''} — ${d.reason}`.trim()
        : `Your booking for ${d.date ?? ''} ${d.time ?? ''} is no longer held.`.trim(),
    }),
    ar: (d) => ({
      title: `${d.venue ?? 'المطعم'} ألغى حجزك`,
      body: d.reason
        ? `${d.date ?? ''} ${d.time ?? ''} — ${d.reason}`.trim()
        : `حجزك يوم ${d.date ?? ''} الساعة ${d.time ?? ''} مابقاش محجوز.`.trim(),
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
