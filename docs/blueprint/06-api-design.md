# SAHRA Blueprint — 06: API Design

*REST, JSON, base URL `https://api.sahra.app/v1`. All examples abbreviated but production-shaped.*

---

## 1. Conventions

- **Versioning:** URI major version (`/v1/`). Additive changes don't bump; breaking changes ship `/v2` alongside `/v1` with a 12-month deprecation window signaled by `Deprecation` + `Sunset` headers. Mobile clients send `X-App-Version`; server can force-upgrade via 426 + Remote Config.
- **Auth:** `Authorization: Bearer <access JWT>` (15 min TTL). Refresh via rotating refresh tokens (30 d, revocable, reuse-detection). Scopes/roles embedded in JWT claims (`roles: ["customer"]`, `staff: [{restaurant_id, role}]`).
- **Idempotency:** all POST/PATCH/DELETE that mutate accept `Idempotency-Key` header (required on holds, confirms, payments).
- **Localization:** `Accept-Language: ar | en` selects localized fields; responses include both (`name_en`, `name_ar`) for client-side switching.
- **Pagination:** cursor-based — `?limit=20&cursor=...`; responses carry `next_cursor`.
- **Error envelope** (RFC 7807-inspired):

```json
{ "error": { "code": "slot_taken", "message": "This time is no longer available.",
  "message_ar": "هذا الموعد لم يعد متاحًا.", "details": [{"field": "starts_at", "issue": "conflict"}],
  "request_id": "req_9f8a" } }
```

- **Status codes:** 200 OK · 201 Created · 204 No Content · 400 validation · 401 unauthenticated · 403 forbidden · 404 not found · 409 conflict (slot taken, state transition) · 402 payment required · 422 semantic/idempotency conflict · 429 rate limited (`Retry-After`) · 5xx server.
- **Validation:** NestJS DTOs + class-validator; every field type/length/enum checked at the edge; unknown fields rejected (`whitelist: true, forbidNonWhitelisted: true`).
- **Rate limits (per user/IP, Redis sliding window):** auth endpoints 5/min; OTP send 3/10min; search 60/min; booking 10/min; general 300/min.

## 2. Authentication APIs

| Endpoint | Method | Body (req) | Success | Notes |
|---|---|---|---|---|
| `/auth/register` | POST | `{phone, email?, password?, full_name, locale}` | 201 `{user_id, otp_required: true}` | 409 `phone_exists` |
| `/auth/verify-otp` | POST | `{user_id, code, purpose?}` | 200 `{access_token, refresh_token, user}` | 5 attempts → 429 + **15-minute lock** |
| `/auth/login` | POST | `{identifier, password}` | 200 tokens | 401 `invalid_credentials` |
| `/auth/request-otp` | POST | `{phone}` | 202 `{user_id, otp_required: true}` | 401 `invalid_credentials` \| `account_unavailable`, 429 `otp_rate_limited` |
| `/auth/social` | POST | `{provider: google\|apple\|facebook, id_token}` | 200 tokens (creates account on first login) | |
| `/auth/refresh` | POST | `{refresh_token}` | 200 new pair (old refresh revoked) | reuse → revoke family, 401 |
| `/auth/logout` | POST | `{refresh_token, all_devices?}` | 204 | |
| `/auth/forgot-password` | POST | `{identifier}` | 202 always (no enumeration) | |
| `/auth/reset-password` | POST | `{token/otp, new_password}` | 204 | |
| `/auth/verify-email` | POST | `{token}` | 204 | |

### Why phone-OTP sign-in is its own route

**This table originally put `{phone}` → OTP flow on `/auth/login`. It is
`/auth/request-otp` in the implementation, and that is deliberate — do not
"correct" it back.**

The two branches return categorically different things: a **token pair**, or a
**handle to a challenge nobody has answered yet**. One endpoint returning
either is a union response, and a union response is a `Map<String, dynamic>` in
the generated Flutter client — every field optional, nothing checkable at
compile time. `packages/sahra_api_client` exists specifically to make a backend
change a Dart compile error at the call site, and `tool/generate_client.dart`
refuses to emit an untyped map for exactly this reason.

The rule postdates this document. Where they disagree, the rule wins, because
the doc's shape was written before there was a typed client to break.

`request-otp` returns the same `{user_id, otp_required}` shape as `/register`,
because it feeds the same next call.

### `purpose` on verify-otp

Challenges are keyed `otp:{purpose}:{user_id}`, so a **registration code cannot
sign anyone in** and a sign-in code cannot activate an account. `purpose`
defaults to `phone_verify`, so the registration flow is unchanged.

### The 15-minute lock

doc 11 flow 1 specifies "5 fails → Locked 15 min + resend option". The lock is
on the **user**, lives in its own key, and **`request-otp` does not reset it** —
without that, five wrong guesses locked only the challenge and a fresh code
bought five more, so the real budget was 3 codes × 5 attempts = 15 guesses per
10 minutes, indefinitely. `retry_after` carries the wait.

### Registration reclaims an UNVERIFIED number

`/auth/register` answers **409 `phone_exists` only for a VERIFIED account.** A
`pending` registration nobody ever confirmed is replaced and a fresh code
issued, because the person holding the phone is overwhelmingly likely to be its
owner — and the previous behaviour told real diners their own number was taken.
The response is byte-identical in shape and status to a first-time
registration, so it is not an enumeration oracle. Unverified rows are swept
after 24 hours (PDPL data minimisation).

Example — login response:

```json
{ "access_token": "eyJ...", "expires_in": 900, "refresh_token": "rt_...",
  "user": { "id": "u_...", "full_name": "Geno", "locale": "en", "roles": ["customer"] } }
```

## 3. Customer APIs

### Search & discovery
| Endpoint | Method | Notes |
|---|---|---|
| `/restaurants/search` | GET | `?q&cuisine&neighborhood&price_band&rating_min&lat&lng&radius_km&available_at&party_size&amenities&sort&cursor` → Meilisearch + availability post-filter |
| `/restaurants/:idOrSlug` | GET | Full profile: photos, hours, policies, rating, amenities |
| `/restaurants/:id/menus` | GET | Menus → categories → items |
| `/restaurants/:id/reviews` | GET | Paginated, published only |
| `/restaurants/:id/availability` | GET | `?date&party_size` → `{slots: [{time, zones: ["indoor","outdoor"]}], alternatives?}` |
| `/collections` / `/collections/:slug` | GET | Curated + featured (labeled `"sponsored": true`) |
| `/favorites` | GET/POST/DELETE `/favorites/:restaurantId` | 204 on toggle |

Search response item:

```json
{ "id": "r_...", "slug": "sequoia-zamalek", "name_en": "Sequoia", "name_ar": "سيكويا",
  "cuisines": ["egyptian","mediterranean"], "neighborhood": "Zamalek", "price_band": 3,
  "rating": 4.6, "rating_count": 812, "cover_image": "https://cdn...", "distance_km": 1.2,
  "next_available": ["19:30","21:45"] }
```

### Reservations
| Endpoint | Method | Body | Success | Errors |
|---|---|---|---|---|
| `/reservations/holds` | POST | `{restaurant_id, starts_at, party_size, seating_pref?}` + Idempotency-Key | 201 `{hold_id, expires_at}` | 409 `slot_taken` + `alternatives` |
| `/reservations/holds/:id/confirm` | POST | `{special_requests?, occasion?, coupon_code?}` | 200 reservation | 409 `hold_expired`, 402 `deposit_required` |
| `/reservations` | GET | `?status=upcoming\|past` | 200 list | |
| `/reservations/:id` | GET/PATCH | PATCH `{starts_at?, party_size?}` re-runs allocation atomically | 200 | 409 if new slot unavailable (original kept). **GET answers 404 for another diner's reservation — never 403** |
| `/reservations/:id/acknowledge-cancellation` | POST | | 204 (idempotent) | 404 |
| `/reservations/:id` | DELETE | | 200 `{status, refund?}` | 409 if already seated/completed |
| `/waitlists` | POST/GET, DELETE `/waitlists/:id` | `{restaurant_id, desired_date, window_start, window_end, party_size}` | 201 `{position}` | 409 duplicate |
| `/waitlists/:id/claim` | POST | | 201 hold | 409 `offer_expired` |

### A restaurant-initiated cancellation must be SEEN, not merely recorded

**`/reservations/:id/acknowledge-cancellation` is not in the original table.**
It exists because of an asymmetry the `?status=upcoming|past` split hides:

- a diner who **cancels** knows they cancelled, so the booking can leave their
  upcoming list immediately;
- a diner whose **restaurant cancels** does not. If it leaves on a date
  comparison, the booking silently disappears and they arrive at a venue that
  is not expecting them, in front of their guests.

So a `cancelled_by_restaurant` reservation stays in **upcoming regardless of
date** until acknowledged. It leaves because the diner saw it, not because the
date passed — the person who opens the app three days late is exactly the one
who most needs telling.

`reservation_status` already distinguishes `cancelled_by_user` from
`cancelled_by_restaurant`, so nothing is inferred; `cancellation_seen_at`
(migration `20260802000000`) records the acknowledgement.

Acknowledgement is a POST rather than a side effect of the GET, because a read
that acknowledged would be acknowledged by a prefetch, a retry or a list
render — none of which is a human reading the notice.

Responses carry `cancelled_by`, `cancelled_at`, `cancel_reason` and
`needs_acknowledgement`, the last derived server-side so no client has to
re-implement the rule.

> **Two P0 gaps this depends on:** nothing yet SETS `cancelled_by_restaurant`
> (there is no owner cancel endpoint), and nothing can notify a diner who is
> not looking at the app. Both are tracked in
> `docs/decisions/2026-08-02-open-p0-gaps.md` as CANCEL-1 and NOTIFY-1.

### Reviews, payments, profile
| Endpoint | Method | Notes |
|---|---|---|
| `/reviews` | POST | `{reservation_id, rating, food_rating?, service_rating?, ambience_rating?, body?, photo_ids?}` → 201; 403 unless own completed reservation; 409 duplicate |
| `/payments/intents` | POST | `{reservation_id}` + Idempotency-Key → 201 `{payment_id, provider: "paymob", client_params}` |
| `/payments/:id` | GET | Poll status: pending → captured/failed |
| `/payments/methods` | GET/POST/DELETE | Tokenized cards/wallets |
| `/me` | GET/PATCH | Profile, prefs, notification settings |
| `/me/loyalty` | GET | Balance + transactions |
| `/me/referral` | GET | Code + stats |
| `/notifications` | GET, POST `/notifications/read` | In-app center |
| `/devices` | POST/DELETE | FCM token registration |

## 4. Restaurant Owner APIs (`/owner/...`, role: owner/staff)

| Endpoint | Method | Notes |
|---|---|---|
| `/owner/restaurants` | POST/GET | Create (201 draft) / list mine |
| `/owner/restaurants/:id` | GET/PATCH | Profile, policies, amenities |
| `/owner/restaurants/:id/submit` | POST | draft → pending_review |
| `/owner/restaurants/:id/images` | POST/PATCH/DELETE | Presigned upload → attach; reorder |
| `/owner/restaurants/:id/menus` (+categories/items) | CRUD | Bilingual fields validated |
| `/owner/restaurants/:id/shifts` | CRUD | Weekly + special dates + `is_ramadan` |
| `/owner/restaurants/:id/tables` | CRUD | 409 if deactivating a table with future bookings |
| `/owner/restaurants/:id/reservations` | GET | `?date&status` — the book; realtime via WebSocket/SSE channel `restaurant:{id}:reservations` |
| `/owner/restaurants/:id/reservations` | POST | Walk-in/phone entry `{guest_name, guest_phone?, party_size, starts_at}` |
| `/owner/reservations/:id/accept` / `decline` | POST | request-mode |
| `/owner/reservations/:id/seat` / `no-show` / `complete` / `transfer` | POST | State machine guarded; 409 invalid transition |
| `/owner/restaurants/:id/waitlist` | GET, POST `.../offer` | Console view |
| `/owner/restaurants/:id/staff` | CRUD | Invite by phone; roles manager/host/viewer |
| `/owner/restaurants/:id/analytics` | GET | `?from&to&metrics=covers,occupancy,no_show_rate,lead_time` (Pro gates depth) |
| `/owner/restaurants/:id/promotions` | CRUD | |
| `/owner/restaurants/:id/reviews/:reviewId/reply` | POST | |
| `/owner/subscription` | GET/POST/PATCH | Plan, invoices |

## 5. Admin APIs (`/admin/...`, role: admin/support/moderator; every call audit-logged)

| Endpoint | Method | Notes |
|---|---|---|
| `/admin/users` | GET | Search/filter; `/admin/users/:id` GET/PATCH (suspend, roles) |
| `/admin/restaurants` | GET | `?status=pending_review` queue |
| `/admin/restaurants/:id/approve` / `reject` | POST | `{reason?}`; triggers notifications + indexing |
| `/admin/moderation/queue` | GET | Reviews/photos flagged; POST `.../resolve` |
| `/admin/payments` | GET | Filters; `/admin/payments/:id/refund` POST |
| `/admin/settlements` | GET/POST | Restaurant payout runs, reconciliation report |
| `/admin/plans` | CRUD | Subscription plans, commission overrides |
| `/admin/reports` | POST | `{type, range, format}` → 202 async job → download URL |
| `/admin/analytics/overview` | GET | Marketplace KPIs |
| `/admin/monitoring/health` | GET | Aggregated service health (proxies Grafana alerts) |
| `/admin/audit-logs` | GET | Filterable, read-only |
| `/admin/flags` | GET/PATCH | Feature flags / kill switches |

## 6. Error Handling & Contract Discipline

- Machine-readable `error.code` enum is the contract; messages are display-only and bilingual.
- 409s on booking always include `alternatives` (nearest 4 available slots) — turn failure into conversion.
- All 5xx carry `request_id` correlating to server traces (Sentry/Loki).
- OpenAPI 3.1 spec generated from NestJS decorators is the single source of truth; Flutter DTOs code-generated from it (`openapi-generator` → freezed models) so client/server can't drift.
- Contract tests in CI: the generated spec is diffed against the committed spec; breaking diffs fail the build unless the version is bumped.
