/// Everything that can go wrong, as ONE sealed hierarchy.
///
/// ENGINEERING-STANDARDS §7. Sealed, so `switch` over a `Failure` is checked
/// by the compiler — which is the entire reason `OfflineFailure` is a member
/// rather than a special case. Egyptian connectivity is the reason doc 07 §3
/// puts offline in the architecture at all; a hierarchy that let a developer
/// forget it would be decorative.
///
/// No screen ever sees a `DioException`. The transport parses the doc 06 §1
/// envelope and throws `ApiException`; `mapFailure` turns that into one of
/// these; `failureMessage` turns THAT into a sentence. Three steps, each in
/// one file.
library;

sealed class Failure {
  const Failure({this.code, this.requestId});

  /// The backend's machine-readable `code` (doc 06 §1) when there was one.
  /// The ONLY field a client is allowed to branch on.
  final String? code;

  /// Shown in the error state's fine print so a diner can quote it to support.
  final String? requestId;
}

/// The request never reached a server: no route to host, DNS, socket closed.
///
/// Distinct from [NetworkFailure] because the recovery is different — "check
/// your connection" is useless advice when the connection is fine and the
/// server took eleven seconds.
class OfflineFailure extends Failure {
  const OfflineFailure({super.requestId});
}

/// Reached the network and it went wrong anyway — timeout, connection reset.
class NetworkFailure extends Failure {
  const NetworkFailure({super.code, super.requestId});
}

/// 401/403. The action needs an account, or this account is not allowed.
class AuthFailure extends Failure {
  const AuthFailure({super.code, super.requestId});
}

/// 409. The one that matters most here: `slot_taken` and `hold_expired`.
///
/// Carries [alternatives] because doc 06 §6 says a booking 409 always offers
/// the nearest available slots — "turn failure into conversion". A conflict
/// with nowhere to go is the dead end the design rules forbid.
class ConflictFailure extends Failure {
  const ConflictFailure({super.code, super.requestId, this.alternatives = const <String>[]});

  /// ISO-8601 UTC instants, bookable directly. Not display strings.
  final List<String> alternatives;
}

/// 400/422 with `details: [{field, issue}]`, carried through so the offending
/// field can be highlighted instead of a banner appearing above an unchanged
/// form.
class ValidationFailure extends Failure {
  const ValidationFailure({super.code, super.requestId, this.details = const <FieldIssue>[]});

  final List<FieldIssue> details;
}

/// 5xx, and 503 in particular — which is what a Meilisearch outage looks like
/// from here (`search_unavailable`).
class ServerFailure extends Failure {
  const ServerFailure({super.code, super.requestId, this.retryAfterSeconds});

  final int? retryAfterSeconds;
}

/// Anything unrecognised. Deliberately last, and deliberately not a dumping
/// ground: reaching it in a screen that matters is a bug report.
class UnknownFailure extends Failure {
  const UnknownFailure({super.code, super.requestId});
}

class FieldIssue {
  const FieldIssue(this.field, this.issue);
  final String field;
  final String issue;
}
