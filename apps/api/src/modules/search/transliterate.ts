/**
 * Cross-script matching for Arabic, franco-Arabic and English.
 *
 * Franco-Arabic ("Arabizi") — Latin letters plus digits for the sounds Latin
 * has no letter for (7 = ح, 3 = ع, 5 = خ, 2 = ء) — is a primary input mode on
 * an Egyptian phone keyboard, not a fallback. A diner looking for كشري types
 * "koshary", and someone else types "kushari", and neither expects to fail.
 *
 * Meilisearch typo tolerance cannot bridge this: it works within a script, and
 * even in Latin "ma7shy" → "mahshi" is two edits on a six-character word where
 * one is allowed.
 *
 * THE IDEA: reduce both scripts to a shared CONSONANT SKELETON. This is not a
 * trick — it is what Arabic script already does. Short vowels are unwritten,
 * so كشري carries k-sh-r and every romanisation of it (koshary, koshari,
 * kushari) carries those same consonants and differs only in the vowels nobody
 * agrees on. Drop the vowels and the disagreement disappears.
 *
 * Skeletons are lossy by design, so they are indexed in their own attribute,
 * ranked BELOW the real names — they widen recall without displacing an exact
 * match. Callers also drop skeletons shorter than MIN_SKELETON_LEN, because a
 * one-consonant key matches half the city.
 */

/** Below this a skeleton is noise, not a signal. */
export const MIN_SKELETON_LEN = 2;

/**
 * Internal single-character tokens for sounds Latin spells with two letters.
 * Single characters so that "k"+"h" (قهوة → k,h) can never be confused with
 * "kh" (خ). The letters chosen are ones the mapping never emits directly:
 * Latin q is dropped, w is a glide, c becomes k.
 */
const KH = 'q';
const SH = 'c';
const GH = 'w';

/** Arabic letter → consonant token. '' means "carries no consonant". */
const ARABIC: Record<string, string> = {
  ب: 'b', ت: 't', ث: 't', ج: 'g', ح: 'h', خ: KH, د: 'd', ذ: 'z',
  ر: 'r', ز: 'z', س: 's', ش: SH, ص: 's', ض: 'd', ط: 't', ظ: 'z',
  غ: GH, ف: 'f', ك: 'k', ل: 'l', م: 'm', ن: 'n', ه: 'h',
  // ع has no Latin consonant; franco writes it "3", which we also drop.
  ع: '',
  // Long vowels and glides. و and ي are read as oo/ee at least as often as
  // w/y, and Latin drops both, so dropping them keeps the two sides in step.
  و: '', ي: '', ى: '', ا: '', أ: '', إ: '', آ: '', ء: '', ؤ: '', ئ: '', ة: '',
  // Dialect letters used in loanwords.
  پ: 'b', چ: SH, ڤ: 'f', گ: 'g',
};

/**
 * ق is genuinely two-valued and no single choice is right.
 *
 * Cairene drops it to a glottal stop — قهوة is "ahwa" — while the same letter
 * is a hard k in طارق, "Tarek". Forcing one reading breaks the other, so the
 * INDEX carries both and the query picks the reading its own spelling implies.
 */
const QAF_READINGS = ['', 'k'] as const;

/** Arabizi digits. Applied before digraph scanning so "ma7shy" → "mahshy". */
const DIGITS: Record<string, string> = {
  '2': '', // ء / أ — a glottal stop, no consonant
  '3': '', // ع
  '4': SH, // ش (less common than 'sh')
  '5': KH, // خ
  '6': 't', // ط
  '7': 'h', // ح
  '8': GH, // غ
  '9': '', // ق — the Cairene reading; the index also holds the 'k' reading
};

const LATIN_DIGRAPHS: Record<string, string> = {
  kh: KH, sh: SH, ch: SH, gh: GH, th: 't', ph: 'f',
};

/** Latin letter → consonant token. '' means vowel or glide. */
const LATIN: Record<string, string> = {
  a: '', e: '', i: '', o: '', u: '', y: '', w: '', q: '',
  b: 'b', c: 'k', d: 'd', f: 'f', g: 'g', h: 'h', j: 'g', k: 'k',
  l: 'l', m: 'm', n: 'n', p: 'b', r: 'r', s: 's', t: 't', v: 'f',
  x: 'ks', z: 'z',
};

/** Harakat, shadda, sukun, superscript alef, tatweel — written, not sounded. */
const ARABIC_MARKS = /[ً-ْٰـ]/g;
const HAS_ARABIC = /[؀-ۿ]/;

/**
 * The consonant skeleton of ONE word.
 *
 * `qaf` selects the reading of ق for Arabic input; it has no effect on Latin
 * input, where the spelling has already committed ("tarek" vs "ahwa").
 */
export function skeleton(word: string, qaf: string = ''): string {
  const w = word.normalize('NFKC').replace(ARABIC_MARKS, '').trim();
  if (!w) return '';
  return collapse(HAS_ARABIC.test(w) ? fromArabic(w, qaf) : fromLatin(w));
}

function fromArabic(word: string, qaf: string): string {
  let out = '';
  for (const ch of word) {
    if (ch === 'ق') out += qaf;
    else out += ARABIC[ch] ?? '';
  }
  return out;
}

function fromLatin(word: string): string {
  const lower = word.toLowerCase();
  let out = '';

  for (let i = 0; i < lower.length; ) {
    const ch = lower[i];

    // Digits emit their token DIRECTLY rather than being substituted back into
    // the string. Substituting first would feed the internal tokens through
    // the Latin map on the next pass — "5an" would become "qan" and then lose
    // the q, because Latin q is a dropped letter.
    if (ch in DIGITS) {
      out += DIGITS[ch];
      i += 1;
      continue;
    }

    const pair = lower.slice(i, i + 2);
    if (pair.length === 2 && pair in LATIN_DIGRAPHS) {
      out += LATIN_DIGRAPHS[pair];
      i += 2;
      continue;
    }

    out += LATIN[ch] ?? '';
    i += 1;
  }
  return out;
}

/** "mohammed" and "mohamed" must not differ. */
function collapse(s: string): string {
  let out = '';
  for (const ch of s) if (ch !== out[out.length - 1]) out += ch;
  return out;
}

/**
 * Every skeleton a name should be findable by — the INDEX side.
 *
 * Per word, not per phrase: the array is stored as-is and Meilisearch matches
 * query tokens against its elements, so ambiguity costs one extra array entry
 * instead of a combinatorial explosion across a multi-word name.
 */
export function indexSkeletons(text: string): string[] {
  const out = new Set<string>();
  for (const word of words(text)) {
    for (const qaf of QAF_READINGS) {
      const s = skeleton(word, qaf);
      if (s) out.add(s);
    }
  }
  return [...out];
}

/**
 * The skeleton of a QUERY — the search side.
 *
 * One canonical reading, space-joined, because the index already carries every
 * variant. Words that reduce below MIN_SKELETON_LEN are dropped rather than
 * emitted: "3am shalaby" searches on the distinctive half and ignores the "m".
 * Returns '' when nothing survives, which tells the caller to skip the
 * transliteration pass entirely instead of running a wildcard.
 */
export function querySkeleton(query: string): string {
  return words(query)
    .map((w) => skeleton(w))
    .filter((s) => s.length >= MIN_SKELETON_LEN)
    .join(' ');
}

/** All skeletons of a phrase, joined — for tests and diagnostics. */
export function skeletonize(text: string): string {
  return words(text)
    .map((w) => skeleton(w))
    .filter(Boolean)
    .join(' ');
}

function words(text: string): string[] {
  return text.split(/[\s\p{P}]+/u).filter(Boolean);
}
