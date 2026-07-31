import { turnMinutes, bookingWindow, DEFAULT_TURN_MINUTES } from './turn-time';

describe('turnMinutes', () => {
  it('maps party size to the configured band', () => {
    expect(turnMinutes(1)).toBe(90);
    expect(turnMinutes(2)).toBe(90);
    expect(turnMinutes(3)).toBe(105);
    expect(turnMinutes(4)).toBe(105);
    expect(turnMinutes(5)).toBe(120);
    expect(turnMinutes(12)).toBe(120); // open upper bound
  });

  it('honours a restaurant-specific config', () => {
    const cfg = { '1-2': 60, '3+': 90 };
    expect(turnMinutes(2, cfg)).toBe(60);
    expect(turnMinutes(8, cfg)).toBe(90);
  });

  it('never returns 0 — a 0-minute turn would make an empty range and defeat the EXCLUDE constraint', () => {
    expect(turnMinutes(2, {})).toBeGreaterThan(0);
    expect(turnMinutes(2, { garbage: 0 })).toBeGreaterThan(0);
    expect(turnMinutes(99, { '1-2': 60 })).toBeGreaterThan(0);
  });

  it('falls back to the longest turn when no band matches, not the shortest', () => {
    // A 6-top under a config that only describes small parties must not be
    // given the 30-minute turn — that would release the table too early.
    expect(turnMinutes(6, { '1-2': 30 })).toBeGreaterThanOrEqual(DEFAULT_TURN_MINUTES['5+']);
  });
});

describe('bookingWindow', () => {
  it('produces a half-open window matching the tstzrange the DB stores', () => {
    const start = new Date('2026-08-01T21:00:00.000Z');
    const w = bookingWindow(start, 2);

    expect(w.startsAt.toISOString()).toBe('2026-08-01T21:00:00.000Z');
    expect(w.endsAt.toISOString()).toBe('2026-08-01T22:30:00.000Z');
    expect(w.minutes).toBe(90);
  });

  it('always ends strictly after it starts', () => {
    for (const n of [1, 2, 3, 4, 5, 10, 50]) {
      const w = bookingWindow(new Date('2026-08-01T21:00:00.000Z'), n);
      expect(w.endsAt.getTime()).toBeGreaterThan(w.startsAt.getTime());
    }
  });
});
