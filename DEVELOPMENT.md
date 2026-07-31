# SAHRA — Development Guide

*One self-contained file with everything needed to start building. Read this first; the deeper rationale for every decision here lives in `docs/blueprint/*.md` if you want it, but you don't need to open those to start coding.*

---

## 1. What we're building

SAHRA is a Resy-class restaurant reservation platform for Egypt/MENA. **Two Flutter apps, one backend:**

1. **SAHRA (customer app)** — discover restaurants, real-time table booking, favorites, reviews, notifications. iOS + Android.
2. **SAHRA for Business (restaurant management app)** — everything a restaurant owner/staff needs to run their reservation book, *plus* a hidden admin section for the SAHRA team (restaurant approvals, moderation, platform monitoring) gated by role. Android-first (tablet-friendly for host-stand use), iOS later.

No separate admin web app for now — admin lives inside the management app behind an `admin` role check. Revisit as a separate web dashboard once the platform team outgrows a phone/tablet UI.

**Both apps share one backend and one source of truth.** There is exactly one NestJS API, one PostgreSQL database, and one OpenAPI contract (§6). `customer_app` and `management_app` both consume that contract through the same `sahra_api_client` package — a booking made in the customer app and the same reservation appearing on the restaurant's live book in the management app are the same row in the same database, not two systems being kept in sync. Never build app-local business logic that duplicates something the backend already owns (e.g., don't compute availability client-side in either app — always call the API).

Full bilingual Arabic (RTL) + English from day one. Full product/business context: `docs/blueprint/01-product-and-business.md`.

## 2. Tech stack (decided — don't re-litigate)

| Layer | Choice |
|---|---|
| Customer app | Flutter, Riverpod 2 (codegen), GoRouter |
| Restaurant management app | Flutter, same stack, role-gated admin section |
| Backend | NestJS (TypeScript), modular monolith — no microservices yet |
| ORM | Prisma |
| Database | PostgreSQL via Supabase (+ PostGIS for geo) |
| Cache / locks / queues | Redis + BullMQ |
| Search | Meilisearch |
| Push / analytics / crash | Firebase — **FCM, Analytics, Crashlytics, Remote Config only.** Not Firestore, not Firebase Auth. |
| Payments | Paymob + Fawry (Egypt rails) |
| Messaging | WhatsApp Business API + SMS fallback |
| Hosting / IaC | ECS Fargate + Terraform, Cloudflare in front |
| Object storage | Supabase Storage → CDN |

Reasoning for every choice above (including the 6-option backend comparison) is in `docs/blueprint/08-tech-stack.md` — read it if you want to challenge a decision, otherwise just build against this table.

## 3. Repository structure

```
sahra/
├── docs/
│   ├── blueprint/                 # the 11 deep-dive design docs (architecture, DB, API, security…)
│   └── decisions/                 # NEW decisions made during dev that aren't in the blueprint — log them here
├── apps/
│   ├── api/                       # NestJS backend
│   │   ├── src/
│   │   │   ├── modules/
│   │   │   │   ├── auth/
│   │   │   │   ├── users/
│   │   │   │   ├── restaurants/
│   │   │   │   ├── availability/
│   │   │   │   ├── reservations/
│   │   │   │   ├── waitlist/
│   │   │   │   ├── payments/
│   │   │   │   ├── reviews/
│   │   │   │   ├── notifications/
│   │   │   │   ├── search/
│   │   │   │   ├── analytics/
│   │   │   │   └── admin/
│   │   │   ├── shared/            # guards, interceptors, pipes, decorators
│   │   │   └── main.ts
│   │   ├── prisma/schema.prisma
│   │   └── test/
│   ├── customer_app/              # Flutter — diners
│   └── management_app/            # Flutter — owners, staff, admin (role-gated)
├── packages/
│   ├── sahra_api_client/          # generated from OpenAPI, shared by both Flutter apps
│   └── sahra_design_system/       # shared tokens, colors, widgets (from sahra-design-system-v1)
├── infra/                         # Terraform (VPC, ECS, RDS/Supabase config, Redis)
├── .github/workflows/             # CI/CD
└── CLAUDE.md                      # short pointer file for Claude Code sessions
```

Both Flutter apps share `sahra_design_system` and `sahra_api_client` as local packages (path dependencies), so a booking-flow bugfix in shared widgets or a new API field only needs to be written once.

### Design workflow

UI/UX work is done with Claude (design iteration, mockups, component specs) and flows into the codebase through one place: `packages/sahra_design_system`, which implements the tokens and rules in the project's `sahra-design-system-v1` doc (colors, type scale, spacing, light/dark, RTL mirroring rules). The flow is:

1. Design a screen or component with Claude → get the spec (colors, spacing, states, RTL behavior).
2. If it introduces a new token or shared component (not just a one-off screen layout), add it to `sahra_design_system`, not to the individual app — that's what keeps the customer app and the management app visually consistent without copy-pasting.
3. If the design changes something already documented in `sahra-design-system-v1`, update that doc (or log the change in `docs/decisions/`) so it doesn't silently drift from what's actually in the code.
4. One-off screen-specific layout stays in that app's `presentation/` folder; only genuinely shared visual language goes into the shared package.

## 4. Local environment setup

**Prerequisites:** Node.js 22 LTS, Flutter 3.x (stable channel), Docker + Docker Compose, a Supabase project (free tier is enough for local dev), pnpm.

```bash
# 1. Clone and install
git clone <repo-url> sahra && cd sahra
pnpm install                        # installs workspace deps for apps/api

# 2. Local infra (Postgres via Supabase CLI, Redis, Meilisearch)
docker compose up -d                # redis, meilisearch — Postgres comes from Supabase (local or hosted dev project)

# 3. Backend
cd apps/api
cp .env.example .env                # fill in DATABASE_URL, REDIS_URL, JWT secrets, Paymob/Fawry test keys
pnpm prisma migrate dev             # applies schema, generates client
pnpm run start:dev                  # http://localhost:3000, Swagger at /api/docs

# 4. Flutter apps
cd apps/customer_app
flutter pub get
flutter run --dart-define-from-file=env/dev.json

cd apps/management_app
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

**Environment files** (never commit real secrets — `.env` and `env/*.json` are gitignored, `.example` versions are committed):
- `apps/api/.env.example` — DB URL, Redis URL, JWT signing keys, Paymob/Fawry sandbox keys, Firebase service account, WhatsApp API token.
- `apps/customer_app/env/{dev,staging,prod}.json` and same for `management_app` — API base URL, Firebase config, Sentry DSN, feature flags.

## 5. Database & the reservation engine — read before touching

The schema (`apps/api/prisma/schema.prisma`) mirrors `docs/blueprint/04-database-design.md` exactly, including index names. Do not add/drop indexes without checking that doc — each one is there for a specific query path.

**The one rule that matters most: a table can never be double-booked.** Every booking write goes through three layers (all detailed with pseudocode in `docs/blueprint/05-reservation-engine.md`):
1. Per-`(restaurant_id, date)` lock — serializes writes for one restaurant.
2. Transactional re-check of table availability inside the lock.
3. A Postgres `EXCLUDE USING GIST` constraint on `reservation_tables(table_id, during)` as a hard backstop.

**Before building any UI on top of booking, write the concurrency test:** spin up N concurrent requests for the same last table and assert exactly one succeeds. This test must pass and stay in CI forever — it's the platform's core promise to restaurants.

## 6. API contract workflow

The backend is the source of truth for the contract:

1. NestJS controllers + DTOs (class-validator decorators) generate an OpenAPI 3.1 spec automatically (`/api/docs-json`).
2. `packages/sahra_api_client` is generated from that spec (`openapi-generator` → Dart/freezed models + Dio client). Run `pnpm run generate:client` from repo root after any API change.
3. Both Flutter apps depend on `sahra_api_client` as a local package — never hand-write a model that talks to the API.
4. CI fails the build if the committed spec and the live-generated spec diverge (contract test) — this is what lets two people build client and server in parallel without drifting apart.

Full endpoint-by-endpoint reference (request/response/status codes for every route): `docs/blueprint/06-api-design.md`.

## 7. Coding conventions

**Backend (NestJS/TypeScript):**
- One module per bounded context (see folder list in §3); no cross-module direct repository access — go through the module's service.
- DTOs validated with `class-validator`, `whitelist: true, forbidNonWhitelisted: true` globally.
- All mutating endpoints require `Idempotency-Key`; server dedupes via a unique index or Redis key (24h TTL).
- Money: `Decimal` (Prisma) / `NUMERIC(12,2)` in DB, always paired with a `currency` field (default `EGP`). Never use JS floats for money.
- Every table/API text field that's user-facing exists in both `_en` and `_ar` — no translation-table indirection.
- Errors follow the envelope in `docs/blueprint/06-api-design.md` §1 — machine-readable `error.code`, bilingual `message`/`message_ar`.
- Lint/format: ESLint + Prettier, enforced in CI and pre-commit hook.

**Flutter (both apps):**
- Clean Architecture, feature-first folders: `data/`, `domain/`, `presentation/` per feature (full structure in `docs/blueprint/07-flutter-architecture.md`).
- Riverpod: one `@riverpod` notifier per screen; no side effects inside widgets.
- Never hardcode `left`/`right` — use `EdgeInsetsDirectional`/`Alignment.*Start/*End` so RTL works automatically.
- All new screens get an Arabic (RTL) pass before merge, not after — this is a review checklist item, not a backlog item.
- `flutter analyze` + `dart format --set-exit-if-changed` clean before every PR.

## 8. Git workflow (two developers)

- `main` is protected — no direct pushes. Feature branches: `feat/<short-desc>`, `fix/<short-desc>`.
- Suggested split to avoid stepping on each other:
  - **Dev A:** `apps/api` — schema, auth, reservation engine, payments.
  - **Dev B:** `apps/customer_app` and later `apps/management_app` — screens, consuming `sahra_api_client` against mocks until the real backend endpoint lands.
  - Meet at the OpenAPI spec: agree the shape of an endpoint (even before it's implemented) so client work isn't blocked on server work.
- PRs: small, one module or one screen. CI must pass (lint, unit tests, contract diff) before merge. Squash-merge into `main`.
- **Decision log:** any architectural choice made during development that isn't already in `docs/blueprint/` gets a short entry in `docs/decisions/YYYY-MM-DD-topic.md` — so both of you (and Claude Code, in either of your sessions) stay in sync without a meeting.
- Commit messages: imperative mood, one logical change per commit (`add phone OTP verification endpoint`, not `wip`).

## 9. Testing

| Layer | Tool | What |
|---|---|---|
| Backend unit | Jest | Services, especially the allocation algorithm and state machine transitions |
| Backend concurrency | Jest + a real Postgres test container | The double-booking stress test (§5) — non-negotiable, keep it green |
| Backend integration | Jest + Supertest | Full request→DB round trip per module |
| API contract | Spectral / custom diff script | Committed OpenAPI spec vs. generated spec |
| Flutter unit | `flutter_test` + `mocktail` | Domain use cases, notifiers |
| Flutter widget | `flutter_test` golden tests | Both LTR and RTL variants of key screens |
| Flutter integration | `integration_test` | Golden path: search → book → cancel (customer app); accept → seat → no-show (management app) |

Run everything locally with `pnpm run test` (backend) and `flutter test` (each app) before pushing; CI re-runs all of it plus the contract diff.

## 10. CI/CD (GitHub Actions)

On every PR: lint → unit/widget tests → contract diff → build → security scan (Trivy/gitleaks) → preview environment deploy. On merge to `main`: auto-deploy to staging, manual approval gate, then rolling production deploy with a synthetic booking probe that auto-rolls-back on failure. Mobile builds go to Firebase App Distribution for internal testing, then staged store rollout (10% → 50% → 100%). Full pipeline diagram: `docs/blueprint/10-devops-roadmap-cto.md` §1.

## 11. Sprint 0 — first two weeks, task by task

Scope discipline: **do not start payments, reviews, waitlist, loyalty, or promotions** (all P1/P2) until the path below works end-to-end. Full priority list: `docs/blueprint/02-functional-requirements.md`.

1. Scaffold the monorepo per §3 (empty NestJS app, empty `customer_app` and `management_app` Flutter projects, empty shared packages). *(either dev)*
2. Prisma schema for P0 tables only: `users`, `roles`, `user_roles`, `restaurant_owners`, `restaurants`, `tables`, `shifts`, `reservations`, `reservation_tables`. *(Dev A)*
3. Auth module: register, phone OTP verify, login, refresh token rotation — per `docs/blueprint/06-api-design.md` §2. *(Dev A)*
4. Availability + booking hold/confirm endpoints, **with the concurrency stress test written first**. *(Dev A)*
5. Restaurant CRUD + submit-for-approval endpoints; simple admin approve/reject endpoint (role-gated, no UI yet). *(Dev A)*
6. `customer_app`: bootstrap Riverpod + GoRouter + design system package; build auth screens (phone OTP) against the real API. *(Dev B)*
7. `customer_app`: restaurant search (list only, no map yet) + restaurant detail + availability slot picker + book/cancel. *(Dev B)*
8. `management_app`: bootstrap same as above; restaurant onboarding flow (create → submit); today's reservation book (list view) with manual walk-in entry. *(Dev B, once customer app's core flow is stable)*
9. `management_app`: hidden admin tab (role-gated) — restaurant approval queue only, nothing else yet. *(Dev A or B, whoever's free — it's small)*
10. CI pipeline (lint, test, contract diff) wired up early, not as an afterthought. *(either dev)*

**Definition of done for Sprint 0:** a person can register on the customer app, search a restaurant, book a table; a restaurant owner can register on the management app, get approved by an admin (inside the same app), and see that booking appear on their live reservation book.

## 12. Where to look for more detail

| Question | Doc |
|---|---|
| Full functional requirements, all priorities | `docs/blueprint/02-functional-requirements.md` |
| Every diagram (system, sequence, data flow) | `docs/blueprint/03-system-architecture.md` |
| Full database schema, every table, every index | `docs/blueprint/04-database-design.md` |
| Reservation engine internals, pseudocode | `docs/blueprint/05-reservation-engine.md` |
| Full API reference | `docs/blueprint/06-api-design.md` |
| Flutter architecture deep-dive, testing strategy | `docs/blueprint/07-flutter-architecture.md` |
| Why this tech stack, alternatives considered | `docs/blueprint/08-tech-stack.md` |
| Security, PCI/PDPL, scaling stages | `docs/blueprint/09-security-and-scalability.md` |
| Roadmap, costs, team plan, CTO rationale | `docs/blueprint/10-devops-roadmap-cto.md` |

## 13. When Claude Code should stop and ask instead of proceeding

- Before deviating from any schema, index, or API contract defined above or in the blueprint docs.
- Before adding a new third-party dependency not in the stack table (§2).
- Before touching reservation locking/transaction logic without the concurrency test passing first.
- Before merging admin functionality changes that aren't role-gated behind an `admin` check.
