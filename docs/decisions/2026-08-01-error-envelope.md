# The error envelope: one global filter, doc 06 §1 shape

**Date:** 2026-08-01
**Status:** Accepted
**Applies to:** every endpoint — doc 06 §1
**Supersedes:** the "Known deviation: the error envelope" entry previously in
`2026-08-01-search-availability-postfilter.md`

---

## Context

doc 06 §1 specifies:

```json
{ "error": { "code": "slot_taken", "message": "This time is no longer available.",
  "message_ar": "هذا الموعد لم يعد متاحًا.", "details": [{"field": "starts_at", "issue": "conflict"}],
  "request_id": "req_9f8a" } }
```

The API was returning a bare `{ code, message, message_ar }` with the correct
HTTP status and no `request_id`. Nothing enforced the shape, and unhandled
exceptions fell through to Nest's default 500 handler.

## Why this landed BEFORE the Flutter apps

Every screen that shows a failure parses this shape. Building the client first
and changing the envelope after would mean rewriting error handling in every
screen instead of in one file. It also touches the existing test suite, which
is far cheaper with the backend feature-complete for MVP and the client not yet
started than at any later point.

## Decision

A single `@Catch()` filter — `AllExceptionsFilter` — is the only place an error
becomes a response body. No controller shapes its own errors. `@Catch()` with
no argument is the point: it catches the failures nobody anticipated, which are
exactly the ones that leak.

**Statuses are unchanged.** This is a shape change only, asserted directly by
`does not change status codes — this is a shape change only`.

### The server never picks the language

`message` and `message_ar` both travel on every error. The app's locale lives
in its own settings, and a bilingual user may well run the phone in one
language and prefer the other. An `Accept-Language` header is not a good enough
reason for the server to decide.

### Deliberate errors speak; raw errors say nothing

An `HttpException` was thrown by our code and its message was written to be
read by a diner, so it passes through intact. Anything else — a raw `Error`, a
`PrismaClientKnownRequestError`, a thrown string — becomes a flat
`internal_error` with generic bilingual text. No stack, no file path, no
connection string, no SQL fragment, no Prisma body.

The detail is genuinely useful, so it goes to the server log under the **same
`request_id` the client is holding** — that pairing is what makes a generic
message supportable. Tests assert both halves: nothing forbidden in the body,
and `ECONNREFUSED` plus the request id present in the log.

### Errors without a code of their own

An unmatched route, `ParseUUIDPipe`, a guard — these are thrown by Nest and
carry no `code`. The status supplies one (`bad_request`, `not_found`,
`forbidden`, …) with bilingual text, because a client cannot branch on an empty
string.

### Validation keeps the field

`details: [{ field, issue }]`, with dotted paths for nested DTOs so a client
can highlight `address.city` rather than guessing. `issue` is a stable slug
(`required`, `too_short`, `unknown_field`, …), not class-validator's internal
constraint name, so the client renders its own localised text. **No rejected
value is ever echoed** — a bad password would otherwise land in the response
body and in whatever logs it.

### request_id on every error, and in a header

Generated per request, echoed as `X-Request-Id`. A client-supplied id is
honoured so a mobile client can correlate its telemetry with ours — after being
**sanitised**, because it is written straight back into a response header and
an unfiltered CR/LF would allow header injection.

### Retry-After is promoted to a header

`retry_after` in an exception payload (429 rate limits per doc 06 §1; the 503
under lock contention per doc 05 §3) is also set as the standard `Retry-After`
header. A client obeying HTTP semantics should not have to parse our body to
learn how long to wait. It stays in the body too, because the existing
reservation contract carries it there.

## Why the filter and the pipe are PROVIDERS, not bootstrap config

Both are registered via `APP_FILTER` / `APP_PIPE` in `ErrorsModule`, and the
`ValidationPipe` was moved out of `main.ts`.

`app.useGlobalFilters()` in `bootstrap()` applies only to the bootstrapped app,
so an e2e test booting `AppModule` would exercise a **differently configured
application than production**. The code that decides what a failure looks like
is the last place that difference should exist. As providers, tests and
production share one pipeline — and the new suite boots `AppModule` and asserts
against it.

The pipe sits next to the filter because the shape of a validation failure is
part of the error contract.

## Test coverage

`apps/api/test/error-envelope.e2e-spec.ts` — 18 tests, written before the
implementation. Real endpoints for domain, framework, 404, and validation
errors; a minimal module with a deliberately leaky controller for the cases a
real endpoint cannot be made to produce on demand (raw `Error` with a stack and
an internal path, a Prisma error, a SQL fragment, a bare thrown string).

## Note on the existing suite

Only one existing assertion needed updating — the API's own test suite is
mostly service-level, asserting on the thrown exception rather than on an HTTP
body, so the reshaping did not reach it. That assertion was **tightened** to
the exact envelope rather than loosened. The thin HTTP-level coverage this
revealed is now filled by the new suite.
