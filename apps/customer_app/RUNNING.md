# Running the customer app against a local backend

Windows, PowerShell, from the repo root. Four terminals — the first three stay
open.

## 0. Once, if you have not already

```powershell
pnpm install
cd apps\customer_app
flutter pub get
cd ..\..
```

`apps\api\.env` must exist with a working `DATABASE_URL` / `DIRECT_URL`
(Supabase) — copy `apps\api\.env.example` and fill it in. `env\web.json` is
already written for you and points at `http://localhost:3000`.

---

## 1. Infrastructure — Redis and Meilisearch

```powershell
docker compose up -d
```

Postgres is **not** here; it comes from Supabase. Expect two containers,
`sahra-redis` and `sahra-meilisearch`, both healthy:

```powershell
docker ps --format "{{.Names}}`t{{.Status}}"
```

> **If you skip Meilisearch**, everything still runs — and search answers
> **503**, which is the correct outage behaviour and one of the four states the
> app is built to show. Worth doing once on purpose.

## 2. Seed five Cairo restaurants

```powershell
cd apps\api
pnpm seed
```

Expect:

```
  Layali Lounge  6 tables, 1 shift(s)  4f743baa-…
  Sequoia        7 tables, 2 shift(s)  81edce98-…
  Zooba          4 tables, 1 shift(s)  27de39d3-…
  Kazoku         1 tables, 1 shift(s)  83d5701d-…
  El Fishawy     5 tables, 1 shift(s)  781119c8-…
Indexed 5 venue(s) for search.

5 venues ready.
```

It is **idempotent** — re-run it any time. `pnpm seed --reset` additionally
deletes those five venues' reservations, which is how you get your tables back
after an evening of testing.

The five are chosen so the screens differ, not to fill a list:

| Venue | What it is there to show |
|---|---|
| **Layali Lounge** (Zamalek) | The ordinary case. Six tables, dinner 18:00–23:30 |
| **Sequoia** (Zamalek) | Lunch AND dinner as separate shifts on the same day |
| **Zooba** (Downtown) | **Closed on Mondays** — pick a Monday and see the empty state |
| **Kazoku** (Maadi) | **ONE two-top.** Book it, then try again → `slot_taken`. Open **Tue–Sat only** |
| **El Fishawy** (Khan el-Khalili) | Runs to 02:00, past midnight |

Checked against the running API rather than asserted: Sequoia returns **15
slots** on a Tuesday (12:00–22:00 — lunch and dinner unioned, not just the
first shift), and Kazoku returns **none** on a Monday and six on a Tuesday.

## 3. The API

```powershell
cd apps\api
pnpm start:dev
```

Wait for `SAHRA API on :3000 — docs at /api/docs`. Sanity check in a browser:
<http://localhost:3000/v1/restaurants/search?q=layali>

## 4. The app, in Chrome

```powershell
cd apps\customer_app
flutter run -d chrome --dart-define-from-file=env/web.json
```

Chrome opens on the search screen, **drawn inside a phone-sized frame centred
on the page** — 375 × 812 with a 40px corner radius, the exact shell
`docs/design/ui_kits/app/index.html` renders the reference screens in. A
375-point screen stretched across a 1440-point browser window shows you
something that will never ship.

To look at wide layouts deliberately:

```powershell
flutter run -d chrome --dart-define-from-file=env/web.json --dart-define=DEVICE_FRAME=false
```

> **The frame is cosmetic.** It makes what you see match what ships; it does not
> make the app correct at any size. That comes from
> `flutter test test/layout/viewport_matrix_test.dart`, which renders every
> screen at six real device sizes including **320 × 568 at 200% text** — the
> worst case, and where all five real overflows were found. A green frame is
> not evidence.

> The `--dart-define-from-file` matters. Without it the app uses the Android
> emulator's host alias `10.0.2.2`, and in a browser every request fails as
> "offline".

---

## 5. Signing in — WHERE THE OTP CODE IS

**No SMS is sent.** Real delivery is the open launch blocker (OPS-1); the API
runs `LoggingOtpDelivery`, which writes the code to its own console.

After you tap **Send me a code**, look at the terminal running `pnpm start:dev`
(step 3). The code is in a box of its own:

```
[Nest] WARN [OtpDelivery]
[Nest] WARN [OtpDelivery] ┌─────────────────────────────────────────────┐
[Nest] WARN [OtpDelivery] │  OTP CODE:  296745                          │
[Nest] WARN [OtpDelivery] │  for +201158806644                          │
[Nest] WARN [OtpDelivery] │  purpose: login                             │
[Nest] WARN [OtpDelivery] │  STUB DELIVERY — no SMS was sent (OPS-1)    │
[Nest] WARN [OtpDelivery] └─────────────────────────────────────────────┘
```

If the terminal has scrolled, grep the same thing:

```powershell
# PowerShell, against a captured log
Select-String -Path api.log -Pattern 'OTP CODE' | Select-Object -Last 1
```

Two things that will otherwise cost you ten minutes:

- **`purpose` matters.** `phone_verify` is issued when an account is created;
  `login` when a known number signs in. They are separate challenges under
  separate keys, so a `phone_verify` code from earlier will not answer a
  `login` prompt. Take the code whose purpose matches the box you are looking
  at — in practice, the **last** one.
- **Three codes per number per ten minutes**, then the phone limiter refuses.
  Six wrong entries locks the account for fifteen minutes, and asking for a new
  code does not clear the lock — that is the behaviour, not a bug.

The sign-in screen says all of this on the code step too, in one line. That
note is **debug-only**: `showsOtpDevHint()` is false in any release build
regardless of `--dart-define`, and `otp_dev_hint_test.dart` asserts the whole
truth table.

---

# What to expect, screen by screen

### Search — `/`

Opens on **"Where are you eating tonight?"** with a lantern. That is the
"you have not searched yet" state, deliberately different from "nothing
matched".

Type `layali`, or `zooba`, or `sushi`. Also try:

- **`كشري`** — Arabic
- **`koshary`** — the same thing in Latin
- **`5an`** — franco-Arabic; `5` is the Arabic خ

Each result row shows `★ 4.8 (312) · Levantine · $$$ · Zamalek`. Tap **Tonight**
and the list is re-filtered by **real availability** — venues with nothing free
disappear entirely, and the survivors gain a terracotta `Next: 21:00` badge. The
header changes from "5 places" to "3 places open tonight", and it only says
"open tonight" when the server actually did the availability pass.

**To see it in Arabic**, restart with the locale pinned:

```powershell
flutter run -d chrome --dart-define-from-file=env/web.json --dart-define=FORCE_LOCALE=ar
```

The whole app mirrors right-to-left, the type switches to Reem Kufi and IBM
Plex Sans Arabic, and the venue names come back in Arabic **from the same
response** — the API sends both and the client picks. `FORCE_LOCALE=en` pins
the other way; omit it and the app follows the browser, which is what a real
build does.

Worth noticing while you are there: the phone number and the opening hours on
a venue page read left-to-right inside the Arabic text. That is not free — see
`ltrRun` in the design system, and the note in ENGINEERING-STANDARDS about what
they looked like before.

### Venue detail — `/r/layali-lounge-zamalek`

The URL is the real deep link (doc 07 §3), so you can paste it straight into the
address bar.

A 280px hero with a mashrabiya-latticed placeholder — **that is the designed
no-photo state, not a broken image**. Under it: description, amenity badges,
tonight's hours, address, phone, and a sticky **Book a table** bar.

### Booking — tap "Book a table"

A seven-day strip starting at **Tonight**, a party stepper, and the real
bookable times for that venue, date and party size. Pick a time; the button
becomes **Confirm for 2 at 19:30**.

### Confirmation

A perforated ticket with the venue, date, time, party size and a code like
`SAH-7K2M`. That reservation is **really in Postgres** — check it:

```powershell
curl "http://localhost:3000/v1/owner/restaurants/<id>/reservations?date=2026-08-03"
```

---

# The four failures worth provoking

These are the ones users actually hit, so they are worth seeing rather than
trusting.

**1. Nothing found** — search `zzz no such venue`. A lantern, "Nothing matches
that", "Try a nearby area, or a different night", and a **Start over** button.
Not a spinner, not a blank list.

**2. Search is down** — `docker stop sahra-meilisearch`, then search anything.
"SAHRA is having a moment" with a **Try again** button and a `req_…` reference
in the fine print you could quote to support. Note it does **not** say "nothing
found": an outage and an empty result are different facts.
`docker start sahra-meilisearch` to recover.

**3. The slot is taken while you are choosing** — the one the type system
cannot prevent. Two browser windows side by side:

1. Both on **Kazoku** (one two-top), same date, same time. Pick a
   **Tuesday–Saturday** — Kazoku does not open Sunday or Monday, and an empty
   slot list is the wrong experiment.
2. Confirm in window A.
3. Confirm in window B.

Window B gets **"Just booked by someone else — that time went while you were
choosing. These are still open."**, and the slot list **behind the banner has
already refreshed**, so the alternatives offered are real. It does not dead-end.

**4. Offline mid-booking** — Chrome DevTools → Network → **Offline**, then
Confirm. The failure appears next to the button that failed. Do it *between* the
hold and the confirm and you get a **hold, not a booking** — the table is off the
market for five minutes and then released by the sweeper. The customer app
deliberately does not queue bookings (doc 07 §3): a booking that syncs later is
a promise the engine never made.

---

# What will NOT work yet

Stated plainly so you are not hunting for it:

> **This table went stale once and it is the worst place in the repo for that
> to happen** — it is the page you read before deciding whether something is
> broken or simply unbuilt. On 2026-08-09 it still said photos, favourites,
> waitlist and sign-in were missing; all four had shipped in Groups B and C.
> Re-read it at the end of every batch.

| | Why |
|---|---|
| **Menu, prices** | No menu tables (R-2.3). Group D |
| **Reviews** | No reviews table (C-4.4). Group D |
| **Map** | The reference uses Leaflet; C-2.4 is P1 and no map package is in the doc 08 stack. Group H is an address plus a handoff to the phone's own map app |
| **Photo GALLERY on the venue page** | The hero photo works. The reference's four-thumbnail strip does not — `VenueProfile.images` is fetched and only its first entry is drawn |
| **Most venues having a photograph at all** | The image table is real (R-2.2) but every upload is manual and admin-only, so a venue nobody has photographed shows the mashrabiya placeholder — the reference's own no-photo state |
| **The Collections / Lists / Events chips** | P1/P2. Only `Tonight` ships, and it is wired to the real filter |
| **Being OFFERED a table from a waitlist** | You can join one (C-3.6). Nothing notifies you when a table frees — only the join half is built |
| **Distance filter and distance sort** | C-2.2/C-2.3. The app collects no location, so the controls are absent rather than ranking against nothing |
| **Share** | No implementation — so the button is absent rather than dead |
| **Add to calendar, invite friends** | No implementation — so the buttons are absent rather than dead |
| **Payment or deposit** | C-4.1, blocked on company registration, not on code |
| **Load more results** | `next_cursor` is carried but unused: page two has **not** been availability-filtered, so "more" needs a product decision first |
| **Neighbourhood in Arabic** | `neighborhood` is one `VARCHAR(80)` column, so it reads `Zamalek` even in Arabic. A schema fix, logged in `docs/decisions/2026-08-02-customer-booking-path-scope.md` |

---

# If something goes wrong

| Symptom | Cause |
|---|---|
| Every screen says "You're offline" | The API is not running, or you started Flutter without `--dart-define-from-file=env/web.json` |
| Search 503s, everything else works | Meilisearch is down. `docker compose up -d meilisearch`, then `cd apps\api; pnpm seed` |
| Search returns nothing but the API has venues | Indexed but not seeded, or seeded before Meilisearch was up. Re-run `pnpm seed` |
| "No tables that night" everywhere | You picked a day the venue is closed — Zooba is dark on Mondays, Kazoku on Sunday and Monday |
| A booking 400s with `missing_idempotency_key` | A CORS preflight is stripping the header. Check `CORS_ORIGINS` is unset in dev so the loopback policy applies |

## Running the tests yourself

```powershell
cd apps\customer_app
flutter test --exclude-tags live      # no server needed
flutter test --tags live              # needs the API from step 3, seeded
flutter test --tags golden            # the pictures — a SUBSET of the line above,
                                      #   not a separate suite to add on
```

No count here on purpose. This line used to read `# 180`, which was true once
and then quietly stopped being true — the same failure as a fixture pinned to a
date. A number in a document has nobody checking it.

The `live` suite is the one that walks search → detail → slots → hold → confirm
over a real socket. It is excluded from CI on purpose; it is your end-to-end
check, not CI's.
