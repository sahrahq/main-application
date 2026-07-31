/**
 * Turn time — how long a party of size N occupies a table.
 *
 * Shifts store this as `default_turn_minutes` JSONB in the shape
 * {"1-2":90,"3-4":105,"5+":120} (doc 04 §2 `shifts`, doc 05 §2).
 * Bands are inclusive ranges; the "N+" form is an open upper bound.
 */

export const DEFAULT_TURN_MINUTES: Record<string, number> = {
  '1-2': 90,
  '3-4': 105,
  '5+': 120,
};

/** Parse one band key into [min, max]. `"5+"` → [5, Infinity]. */
function parseBand(key: string): [number, number] | null {
  const plus = /^(\d+)\+$/.exec(key);
  if (plus) return [Number(plus[1]), Number.POSITIVE_INFINITY];

  const range = /^(\d+)-(\d+)$/.exec(key);
  if (range) return [Number(range[1]), Number(range[2])];

  const exact = /^(\d+)$/.exec(key);
  if (exact) return [Number(exact[1]), Number(exact[1])];

  return null;
}

/**
 * Minutes a party of `partySize` holds a table.
 *
 * Falls back to the widest matching band, then to the largest configured
 * value — never returns 0, because a 0-minute turn would produce an empty
 * tstzrange and silently defeat the EXCLUDE constraint.
 */
export function turnMinutes(
  partySize: number,
  config: Record<string, number> = DEFAULT_TURN_MINUTES,
): number {
  const entries = Object.entries(config)
    .map(([k, v]) => ({ band: parseBand(k), minutes: v }))
    .filter((e): e is { band: [number, number]; minutes: number } => e.band !== null);

  if (entries.length === 0) return DEFAULT_TURN_MINUTES['5+'];

  const hit = entries.find(({ band }) => partySize >= band[0] && partySize <= band[1]);
  if (hit && hit.minutes > 0) return hit.minutes;

  // No band matched (misconfigured shift) — be conservative, hold the table
  // for the longest configured turn rather than the shortest.
  return Math.max(...entries.map((e) => e.minutes), DEFAULT_TURN_MINUTES['5+']);
}

/** Booking window [startsAt, endsAt) for a party. */
export function bookingWindow(
  startsAt: Date,
  partySize: number,
  config?: Record<string, number>,
): { startsAt: Date; endsAt: Date; minutes: number } {
  const minutes = turnMinutes(partySize, config);
  return {
    startsAt,
    endsAt: new Date(startsAt.getTime() + minutes * 60_000),
    minutes,
  };
}
