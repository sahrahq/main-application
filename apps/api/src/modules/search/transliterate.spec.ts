/**
 * Cross-script matching: Arabic ⇄ franco-Arabic ⇄ English.
 *
 * Franco-Arabic ("Arabizi") is how a large share of Egyptians type on a phone:
 * Latin letters plus digits for the Arabic sounds Latin has no letter for —
 * 7 = ح, 3 = ع, 5 = خ, 2 = ء. It is a primary input mode, not a fallback.
 *
 * Meilisearch typo tolerance cannot bridge this. It operates within a script,
 * and even in Latin "ma7shy" → "mahshi" is two edits on a six-character word
 * where one is allowed. So both sides are reduced to a shared CONSONANT
 * SKELETON, which is what Arabic script already encodes: short vowels are
 * unwritten, so "كشري" carries k-sh-r and every romanisation of it — koshary,
 * kushari, koshari — carries the same consonants and differs only in the
 * vowels nobody agrees on.
 *
 * The production contract is asymmetric on purpose: the INDEX stores every
 * reading of a name, the QUERY commits to the one its own spelling implies.
 */
import { skeleton, indexSkeletons, querySkeleton, MIN_SKELETON_LEN } from './transliterate';

describe('skeleton: franco-Arabic reduces to the same key as Arabic', () => {
  const pairs: [string, string, string][] = [
    ['كشري', 'koshary', 'the vowels nobody agrees on are dropped'],
    ['كشري', 'koshari', 'same name, different romanisation'],
    ['كشري', 'kushari', 'and another'],
    ['محشي', 'ma7shy', '7 is ح'],
    ['محشي', 'mahshi', 'the plain-Latin spelling agrees'],
    ['زوبا', 'zooba', 'و as a long vowel is dropped, not read as w'],
    ['شاورما', 'shawarma', 'shawarma'],
    ['فطير', 'fiteer', 'fiteer / fatir'],
    ['محمد', 'mohamed', 'mohamed'],
    ['محمد', 'mohammed', 'doubled letters collapse'],
    ['محمد', 'mo7amed', 'and the digit form'],
    ['خان', '5an', '5 is خ'],
    ['عم', '3am', '3 is ع'],
  ];

  it.each(pairs)('%s ≡ %s (%s)', (arabic, latin) => {
    expect(skeleton(latin)).toBe(skeleton(arabic));
    expect(skeleton(arabic).length).toBeGreaterThan(0);
  });

  it('collapses every romanisation of one name to a single key', () => {
    const keys = new Set(['koshary', 'koshari', 'kushari', 'كشري'].map((f) => skeleton(f)));
    expect(keys.size).toBe(1);
  });

  it('keeps خ and a k+h sequence apart', () => {
    // خان is not "k-h-a-n". A two-letter Latin digraph must not collide with
    // the two separate consonants it looks like.
    expect(skeleton('خان')).not.toBe(skeleton('كهان'));
  });

  it('normalises Arabic orthography that carries no sound', () => {
    expect(skeleton('احمد')).toBe(skeleton('أحمد')); // hamza forms
    expect(skeleton('قهوه')).toBe(skeleton('قهوة')); // ta marbuta
    expect(skeleton('مصطفي')).toBe(skeleton('مصطفى')); // alef maqsura
    expect(skeleton('مُحَمَّد')).toBe(skeleton('محمد')); // harakat and shadda
  });

  it('keeps genuinely different names apart', () => {
    expect(skeleton('كشري')).not.toBe(skeleton('شاورما'));
    expect(skeleton('zooba')).not.toBe(skeleton('sequoia'));
  });

  it('returns empty when there is no consonant to key on', () => {
    // An all-vowel query must never become a wildcard.
    expect(skeleton('aeiou')).toBe('');
    expect(skeleton('123')).toBe('');
    expect(skeleton('')).toBe('');
  });
});

/**
 * ق is genuinely two-valued: Cairene drops it (قهوة → "ahwa") while the same
 * letter is a hard k in طارق → "Tarek". Neither reading can be forced, so the
 * index carries both.
 */
describe('ق: the index carries both readings so either spelling finds it', () => {
  it('finds قهوة from "ahwa" (glottal) and "qahwa" (literal)', () => {
    const forms = indexSkeletons('قهوة');
    expect(forms).toContain(skeleton('ahwa'));
    expect(forms).toContain(skeleton('qahwa'));
  });

  it('finds طارق from "tarek" — the reading that keeps the k', () => {
    expect(indexSkeletons('طارق')).toContain(skeleton('tarek'));
  });

  it('one name, both readings indexed', () => {
    expect(indexSkeletons('طارق').length).toBe(2);
    // A name without ق is unambiguous and costs exactly one entry.
    expect(indexSkeletons('كشري').length).toBe(1);
  });
});

describe('the index/query contract', () => {
  it('every query token for a name is present in that name\'s index tokens', () => {
    const indexed = indexSkeletons('كشري أبو طارق');
    for (const token of querySkeleton('koshary abou tarek').split(' ')) {
      expect(indexed).toContain(token);
    }
  });

  it('matches an Arabic query against a Latin-branded name', () => {
    // Cairo venues often carry Latin branding in both columns; an Arabic
    // speaker typing it phonetically must still land on it.
    const indexed = indexSkeletons('Flamenco Grill');
    expect(indexed).toContain(querySkeleton('فلامنكو'));
  });

  it('drops query tokens too short to be a signal', () => {
    // "3am" alone reduces to one consonant, which would match half the city.
    expect(querySkeleton('3am')).toBe('');
    // In a phrase the distinctive half survives and the noise is dropped.
    expect(querySkeleton('3am shalaby')).toBe(skeleton('شلبي'));
  });

  it('returns empty rather than a wildcard when nothing survives', () => {
    expect(querySkeleton('aeiou')).toBe('');
    expect(querySkeleton('')).toBe('');
    expect(MIN_SKELETON_LEN).toBeGreaterThanOrEqual(2);
  });
});
