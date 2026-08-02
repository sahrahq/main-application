import 'dart:math';

/// A UUID v4, for the `Idempotency-Key` header every mutation requires
/// (doc 06 §1, CLAUDE.md rule 2).
///
/// Fifteen lines instead of a dependency. `uuid` is not in the doc 08 stack
/// table, and CLAUDE.md says stop and ask before adding one — asking to import
/// a package to call `Random.secure()` four times is not a good use of that.
///
/// `Random.secure()` rather than `Random()`: the key is what makes a retry
/// safe, so two clients generating the same one would let a network retry
/// silently return somebody else's reservation. The API validates the v4
/// shape, so the version and variant bits below are not cosmetic.
String newIdempotencyKey() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));

  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
      '-${hex.substring(16, 20)}-${hex.substring(20)}';
}
