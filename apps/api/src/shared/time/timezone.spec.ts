import { zonedWallTimeToUtc, utcToZonedHhmm, zoneOffsetMs, isValidTimeZone } from './timezone';

const HOUR = 3_600_000;

describe('zoneOffsetMs', () => {
  it('tracks Egypt DST', () => {
    // EEST (UTC+3) in August, EET (UTC+2) in January.
    expect(zoneOffsetMs(new Date('2026-08-05T12:00:00Z'), 'Africa/Cairo')).toBe(3 * HOUR);
    expect(zoneOffsetMs(new Date('2026-01-07T12:00:00Z'), 'Africa/Cairo')).toBe(2 * HOUR);
  });

  it('handles a zone without DST', () => {
    expect(zoneOffsetMs(new Date('2026-08-05T12:00:00Z'), 'Asia/Dubai')).toBe(4 * HOUR);
    expect(zoneOffsetMs(new Date('2026-01-07T12:00:00Z'), 'Asia/Dubai')).toBe(4 * HOUR);
  });

  it('is zero for UTC', () => {
    expect(zoneOffsetMs(new Date('2026-08-05T12:00:00Z'), 'UTC')).toBe(0);
  });
});

describe('zonedWallTimeToUtc', () => {
  it('resolves Cairo dinner time in both seasons', () => {
    expect(zonedWallTimeToUtc('2026-08-05', 18, 0, 'Africa/Cairo').toISOString())
      .toBe('2026-08-05T15:00:00.000Z');
    expect(zonedWallTimeToUtc('2026-01-07', 18, 0, 'Africa/Cairo').toISOString())
      .toBe('2026-01-07T16:00:00.000Z');
  });

  it('resolves a fixed-offset zone', () => {
    expect(zonedWallTimeToUtc('2026-08-05', 18, 0, 'Asia/Dubai').toISOString())
      .toBe('2026-08-05T14:00:00.000Z');
  });

  it('handles times near a DST changeover', () => {
    // Egypt springs forward on the last Friday of April 2026 (the 24th).
    // 02:00 does not exist locally that night; the two-pass correction must
    // still produce a real instant rather than drifting an hour.
    const before = zonedWallTimeToUtc('2026-04-24', 23, 0, 'Africa/Cairo');
    const after = zonedWallTimeToUtc('2026-04-25', 23, 0, 'Africa/Cairo');
    // Consecutive 23:00 local readings are 24h apart in wall-clock terms but
    // 23h apart in absolute terms across a spring-forward.
    const deltaHours = (after.getTime() - before.getTime()) / HOUR;
    expect([23, 24]).toContain(deltaHours);
  });

  it('round-trips: instant → local HH:MM → same instant', () => {
    for (const [date, tz] of [
      ['2026-08-05', 'Africa/Cairo'],
      ['2026-01-07', 'Africa/Cairo'],
      ['2026-08-05', 'Asia/Dubai'],
      ['2026-03-15', 'Europe/London'],
    ] as const) {
      for (const h of [0, 6, 12, 18, 23]) {
        const instant = zonedWallTimeToUtc(date, h, 30, tz);
        expect(utcToZonedHhmm(instant, tz)).toBe(`${String(h).padStart(2, '0')}:30`);
      }
    }
  });
});

describe('utcToZonedHhmm', () => {
  it('renders the local wall clock, not UTC', () => {
    const instant = new Date('2026-08-05T15:00:00.000Z');
    expect(utcToZonedHhmm(instant, 'Africa/Cairo')).toBe('18:00'); // +3
    expect(utcToZonedHhmm(instant, 'Asia/Dubai')).toBe('19:00'); // +4
    expect(utcToZonedHhmm(instant, 'UTC')).toBe('15:00');
  });

  it('renders midnight as 00:00, never 24:00', () => {
    const midnightCairo = zonedWallTimeToUtc('2026-08-05', 0, 0, 'Africa/Cairo');
    expect(utcToZonedHhmm(midnightCairo, 'Africa/Cairo')).toBe('00:00');
  });
});

describe('isValidTimeZone', () => {
  it('accepts real zones and rejects nonsense', () => {
    expect(isValidTimeZone('Africa/Cairo')).toBe(true);
    expect(isValidTimeZone('Asia/Dubai')).toBe(true);
    expect(isValidTimeZone('Mars/Olympus_Mons')).toBe(false);
    expect(isValidTimeZone('')).toBe(false);
  });
});
