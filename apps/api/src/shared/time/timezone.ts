/**
 * Wall-clock ↔ absolute-instant conversion for a named IANA timezone.
 *
 * doc 04 §3: "restaurant-local logic derives from the restaurant's `timezone`".
 * Shifts store TIME — 18:00 means six in the evening *there* — so turning that
 * into a bookable instant needs the venue's zone and the DST rules in force on
 * that particular date. Egypt reinstated DST in 2023 (last Friday of April →
 * last Thursday of October), so a fixed +02:00 is wrong for half the year.
 *
 * Implemented on `Intl` rather than a date library: Node 22 ships full ICU, the
 * IANA database is kept current by the runtime, and adding a dependency would
 * need sign-off per CLAUDE.md.
 */

/**
 * How far the zone's wall clock runs ahead of UTC at a given instant, in ms.
 * Cairo in August → +3h. Cairo in January → +2h.
 */
export function zoneOffsetMs(instant: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(instant);

  const get = (type: string): number => Number(parts.find((p) => p.type === type)?.value ?? 0);

  const wallAsIfUtc = Date.UTC(
    get('year'),
    get('month') - 1,
    get('day'),
    get('hour') % 24, // some locales render midnight as 24
    get('minute'),
    get('second'),
  );

  return wallAsIfUtc - instant.getTime();
}

/**
 * Resolve a wall-clock time in `timeZone` to the absolute instant.
 *
 * Two passes: the offset depends on the instant, and the instant depends on
 * the offset. The first pass guesses using the offset at the naive reading;
 * the second corrects it when that guess landed on the other side of a DST
 * transition. Without the second pass, times within an hour of a changeover
 * come out an hour wrong.
 */
export function zonedWallTimeToUtc(
  /** YYYY-MM-DD, as written on the restaurant's calendar */
  date: string,
  hours: number,
  minutes: number,
  timeZone: string,
): Date {
  const [y, m, d] = date.split('-').map(Number);
  const naive = Date.UTC(y, m - 1, d, hours, minutes, 0, 0);

  const firstGuess = zoneOffsetMs(new Date(naive), timeZone);
  let instant = new Date(naive - firstGuess);

  const corrected = zoneOffsetMs(instant, timeZone);
  if (corrected !== firstGuess) instant = new Date(naive - corrected);

  return instant;
}

/** Render an instant as HH:MM on the zone's wall clock. */
export function utcToZonedHhmm(instant: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    hour12: false,
    hour: '2-digit',
    minute: '2-digit',
  }).formatToParts(instant);

  const get = (type: string): string => parts.find((p) => p.type === type)?.value ?? '00';
  const hh = String(Number(get('hour')) % 24).padStart(2, '0');
  return `${hh}:${get('minute')}`;
}

/** True when the zone name is one this runtime's ICU actually knows. */
export function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone }).format(new Date());
    return true;
  } catch {
    return false;
  }
}
