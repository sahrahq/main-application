import { renderPush } from './notification-copy';

/**
 * Push copy is the ONE place the server owns wording. Everywhere else the
 * client owns it (§7), because everywhere else there is a client. A lock
 * screen has none.
 */
describe('renderPush', () => {
  const data = {
    venue: 'Layali Lounge',
    reason: 'Burst pipe in the kitchen',
    date: '2026-08-05',
    time: '21:00',
  };

  it('renders Arabic by default — the primary locale', () => {
    const ar = renderPush('reservation_cancelled_by_venue', data, 'ar');
    expect(ar.title).toContain('ألغى حجزك');
    expect(ar.body).toContain('Burst pipe in the kitchen');
  });

  it('renders English for an English handset', () => {
    const en = renderPush('reservation_cancelled_by_venue', data, 'en');
    expect(en.title).toContain('cancelled your table');
  });

  it('falls back to Arabic for an unknown locale, not to English', () => {
    // `supportedLocales.first` is `ar` on the client for the same reason: an
    // app that defaults an unrecognised device to English is a different
    // product.
    expect(renderPush('reservation_cancelled_by_venue', data, 'fr').title)
      .toBe(renderPush('reservation_cancelled_by_venue', data, 'ar').title);
  });

  it('ALWAYS includes the reason when there is one', () => {
    // A diner reading "cancelled" on a lock screen with no explanation assumes
    // it was us. The reason is the difference between an apology and an
    // accusation, and it is the whole argument for making it required.
    for (const locale of ['ar', 'en']) {
      expect(renderPush('reservation_cancelled_by_venue', data, locale).body)
        .toContain(data.reason);
    }
  });

  it('still says something useful with no reason', () => {
    const { venue, date, time } = data;
    for (const locale of ['ar', 'en']) {
      const out = renderPush('reservation_cancelled_by_venue', { venue, date, time }, locale);
      expect(out.body.trim().length).toBeGreaterThan(0);
      expect(out.title).toContain(venue);
    }
  });
});
