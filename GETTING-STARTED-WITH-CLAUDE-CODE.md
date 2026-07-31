# SAHRA — Getting Started with Claude Code (Step by Step)

*This file answers two questions directly, then walks through exactly what to do, in order, with real commands and example prompts.*

---

## Quick answers

**One repo or two?** → **One repo (a monorepo).** Both apps share one backend, one database, one API contract, and one design-system package. Splitting into two repos means publishing `sahra_api_client` and `sahra_design_system` as versioned packages and keeping them in sync across repos manually — real overhead for a 2-person team with no payoff at this stage. Split later only if you bring on separate teams per app with genuinely independent release cadences.

**Which app first?** → **Backend core first, then the customer app, then the management app.** Reasons: (1) both apps depend on the same auth + reservation API, so there's nothing for either app to call until it exists; (2) the customer app's flow (search → book → cancel) is simpler than the management app's (reservation book + admin), so it validates the API and the reservation engine fastest; (3) once the customer app can book a table, the management app just needs to *display* what's already being created — much less new logic. Order: **API core → customer app → management app.**

---

## Step 1 — Install Claude Code

**macOS / Linux / WSL:**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://claude.ai/install.ps1 | iex
```

Verify it worked:
```bash
claude --version
claude doctor      # checks install health
```

You need a Claude **Pro, Max, or Team** account to use Claude Code — the free plan doesn't include it. Log in the first time you run `claude`; it opens a browser to authenticate.

**Both developers repeat this step on their own machine, with their own account.**

## Step 2 — Create the repository

```bash
mkdir sahra && cd sahra
git init
gh repo create sahra --private --source=. --remote=origin   # or create it on GitHub's website and add the remote manually
```

One person (probably you, as founder) creates the repo and adds the other developer as a collaborator on GitHub (Settings → Collaborators). Protect `main`: Settings → Branches → require PR before merge.

## Step 3 — Drop in the planning docs

Copy these into the repo before writing any code:

```
sahra/
├── CLAUDE.md                      # pointer file — put at repo root
├── DEVELOPMENT.md                 # the full dev guide — repo root
└── docs/
    └── blueprint/
        ├── 00-blueprint-index.md
        ├── 01-product-and-business.md
        ├── 02-functional-requirements.md
        ├── 03-system-architecture.md
        ├── 04-database-design.md
        ├── 05-reservation-engine.md
        ├── 06-api-design.md
        ├── 07-flutter-architecture.md
        ├── 08-tech-stack.md
        ├── 09-security-and-scalability.md
        └── 10-devops-roadmap-cto.md
```

Commit and push:
```bash
git add CLAUDE.md DEVELOPMENT.md docs/
git commit -m "docs: add SAHRA blueprint and development guide"
git push -u origin main
```

Both developers `git clone` from here.

## Step 4 — First Claude Code session (either developer)

```bash
cd sahra
claude
```

Claude Code auto-reads `CLAUDE.md`, which tells it to read `DEVELOPMENT.md`. Your **first prompt** should be exactly this kind of thing — don't just say "start building," give it the concrete first task:

> "Read CLAUDE.md and DEVELOPMENT.md. Scaffold the monorepo structure described in DEVELOPMENT.md section 3: an empty NestJS app in apps/api, empty Flutter projects in apps/customer_app and apps/management_app, and empty local packages in packages/sahra_api_client and packages/sahra_design_system. Don't implement any features yet — just get the skeleton building and running, then stop and show me what you did."

Review what it built (`git diff`, run the apps) before moving on — don't approve blind.

## Step 5 — Backend core (Dev A, or both if solo-ish)

Work through these prompts **one at a time**, reviewing and committing between each — don't chain them into one giant request:

1. > "Set up the Prisma schema in apps/api per docs/blueprint/04-database-design.md, but only the P0 tables: users, roles, user_roles, restaurant_owners, restaurants, tables, shifts, reservations, reservation_tables. Include the indexes and the EXCLUDE USING GIST constraint on reservation_tables described in that doc. Run a migration and confirm it applies cleanly."

2. > "Build the auth module (register, phone OTP verify, login, refresh token rotation) per docs/blueprint/06-api-design.md section 2. Include the DTOs, validation, and unit tests."

3. > "Now build the availability + booking hold/confirm endpoints from docs/blueprint/05-reservation-engine.md. Before writing the endpoint logic, first write the concurrency stress test described in DEVELOPMENT.md section 5 — many simultaneous requests for the same last table, asserting exactly one succeeds. Get that test passing, then build the endpoint to match."

4. > "Add restaurant CRUD + submit-for-approval endpoints, and a simple role-gated admin approve/reject endpoint, per docs/blueprint/06-api-design.md."

5. > "Generate the OpenAPI spec from the NestJS decorators, and set up packages/sahra_api_client to generate a Dart client from it, per DEVELOPMENT.md section 6."

**Checkpoint:** you should be able to hit the API with a REST client (or the auto-generated Swagger UI at `/api/docs`) and register a user, create a restaurant, and book a table without a double-booking bug.

## Step 6 — Customer app (Dev B)

Can start as soon as the OpenAPI spec exists (step 5.5), even before every endpoint is finished, by building against a mocked client first.

1. > "Bootstrap apps/customer_app with Riverpod (codegen) and GoRouter per docs/blueprint/07-flutter-architecture.md. Set up the feature-first folder structure described there for the authentication feature."

2. > "Build the phone OTP registration and login screens in customer_app, wired to the real auth API via packages/sahra_api_client. Both Arabic (RTL) and English — test both."

3. > "Build restaurant search (list view) and restaurant detail screens, consuming the search and availability endpoints."

4. > "Build the booking flow: slot picker → hold → confirm, and the cancel flow, per the sequence diagrams in docs/blueprint/03-system-architecture.md."

**Checkpoint:** a real person can register, search, and book a table end-to-end in the customer app, and that reservation exists in the database from Step 5.

## Step 7 — Management app (Dev B or whichever of you is free)

1. > "Bootstrap apps/management_app the same way as customer_app, sharing packages/sahra_design_system and packages/sahra_api_client."

2. > "Build the restaurant owner onboarding flow: register as owner, create restaurant, submit for approval."

3. > "Build today's reservation book (list view, not the floor-plan editor) with manual walk-in entry, per docs/blueprint/02-functional-requirements.md R-3.1 to R-3.3."

4. > "Add a hidden admin tab, visible only when the logged-in user has the admin role, with just the restaurant approval queue for now."

**Checkpoint (Sprint 0 done):** a customer books through the customer app → the restaurant sees it appear on their live book in the management app → an admin can approve a new restaurant from inside the same app.

## Step 8 — Ongoing workflow, day to day

- **Start of session:** `cd sahra && git pull && claude` — Claude Code re-reads `CLAUDE.md`/`DEVELOPMENT.md` fresh each session, so anything committed to `docs/decisions/` since your last session is automatically picked up.
- **One task per prompt**, reviewed before the next — this is what keeps output correct instead of compounding a wrong assumption across five features.
- **When Claude Code makes an architectural call not already in the blueprint**, ask it explicitly: *"Log that decision in docs/decisions/ before we continue."* That's what keeps your two Claude Code sessions (yours and your developer's) in sync without a meeting.
- **Before merging:** run `flutter analyze` / `pnpm run test` locally, open a PR, let CI run (lint, tests, contract diff), then merge — don't push straight to `main`.
- **Weekly sync (5–10 min):** the two of you compare what's in `docs/decisions/` and what's still open in the Sprint 0 checklist (DEVELOPMENT.md section 11) — this replaces a lot of what a scrum standup would do, since the decision log already carries most of the "what changed" information.

## Step 9 — After Sprint 0

Move to the next block in `docs/blueprint/02-functional-requirements.md`: payments (Paymob/Fawry integration), reviews, waitlist, promotions — in that order, same one-prompt-at-a-time discipline. Don't jump ahead to these while the core booking path still has open bugs; a reservation platform's whole value is that the core loop is bulletproof.
