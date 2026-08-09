import { displayName } from './reviews.service';

/**
 * WHAT A STRANGER SEES UNDER A REVIEW.
 *
 * `users.full_name` is whatever the diner typed at registration, and for most
 * Egyptian accounts that is a full legal name with a father's and a
 * grandfather's name in it. Publishing it attaches a real person to a place
 * they were, on a given evening, on a page anyone can open.
 *
 * The rule is the design package's own — `AvatarStack` in the reference shows
 * "Nour H" — so this is the product's convention rather than a privacy measure
 * invented at the last minute. A unit test rather than an e2e one because the
 * interesting cases are the shapes of names, and spinning up Postgres to check
 * that «محمد» is left alone would mean checking one of them instead of nine.
 */
describe('displayName', () => {
  it('keeps the first name and the initial of the second', () => {
    expect(displayName('Nour Hassan')).toBe('Nour H.');
    expect(displayName('Omar Abdelrahman')).toBe('Omar A.');
  });

  it('works in Arabic, where the initial is an Arabic letter', () => {
    expect(displayName('نور حسن')).toBe('نور ح.');
    expect(displayName('عمر عبد الرحمن')).toBe('عمر ع.');
  });

  it('uses only the SECOND name, however many follow', () => {
    // «محمد أحمد علي حسن» is four names, which is ordinary here. Taking the
    // last one would publish the family name — the opposite of the point.
    expect(displayName('Mohamed Ahmed Ali Hassan')).toBe('Mohamed A.');
    expect(displayName('محمد أحمد علي حسن')).toBe('محمد أ.');
  });

  it('leaves a single name alone', () => {
    // A dot after it would invent an initial that does not exist, and "Kareem."
    // reads as a typo.
    expect(displayName('Kareem')).toBe('Kareem');
    expect(displayName('كريم')).toBe('كريم');
  });

  it('survives the whitespace a real form produces', () => {
    expect(displayName('  Nour   Hassan  ')).toBe('Nour H.');
    expect(displayName('')).toBe('');
    expect(displayName('   ')).toBe('');
  });

  it('never returns the full surname, for any of the above', () => {
    // The property, stated once rather than implied by six examples — this is
    // what would fail if somebody "simplified" the function to a trim.
    for (const name of [
      'Nour Hassan',
      'Omar Abdelrahman',
      'نور حسن',
      'Mohamed Ahmed Ali Hassan',
    ]) {
      const surname = name.trim().split(/\s+/)[1];
      expect(displayName(name)).not.toContain(surname);
    }
  });
});
