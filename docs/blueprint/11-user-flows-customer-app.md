# SAHRA Blueprint — 11: User Flows — Customer App

*Screen-by-screen journeys, not backend sequence diagrams (those are in `03-system-architecture.md`). This is what the person actually sees and taps, in order, including empty states and failure paths. Restaurant management app flows come in a follow-up doc once we finish discussing that app's features.*

---

## 1. Onboarding & Registration

```mermaid
flowchart TD
    A[App opens] --> B{First time?}
    B -- yes --> C[Splash/intro screens<br/>optional, skippable]
    B -- no, logged in --> Z[Home / Discovery feed]
    B -- no, logged out --> D[Home in guest mode<br/>browse allowed]
    C --> D
    D --> E{User taps 'Book'<br/>or 'Sign up'}
    E --> F[Enter phone number]
    F --> G[Send OTP via WhatsApp<br/>SMS fallback]
    G --> H[Enter 6-digit code]
    H --> I{Code correct?}
    I -- no, attempts left --> H
    I -- no, 5 fails --> J[Locked 15 min<br/>+ 'resend' option]
    I -- yes --> K{New user?}
    K -- yes --> L[Name + email optional<br/>+ language pref ar/en]
    K -- no --> Z
    L --> M[Notification permission prompt<br/>with plain-language reason]
    M --> Z
    Z --> N[Or: continue with Google/Apple<br/>skips OTP, same downstream]
```

**Notes:**
- Guest browsing is allowed all the way to the booking button — we don't gate discovery behind login, only the actual reservation (reduces drop-off).
- Social login (Google/Apple) and phone/OTP both terminate at the same "new user profile" step — no duplicate accounts if email matches an existing phone account (merge prompt if detected).
- Notification permission is asked with context ("so we can remind you before your reservation"), not immediately on app open — asking cold gets rejected more.

## 2. Search & Discovery

```mermaid
flowchart TD
    A[Home feed] --> B[Search bar tap]
    B --> C[Recent searches + suggested cuisines]
    C --> D[User types query]
    D --> E[Live results list<br/>as-you-type, ar+en+franco match]
    A --> F[Or: browse collections<br/>'Trending in Zamalek', etc.]
    A --> G[Or: filter chips directly<br/>cuisine / area / price / open now]
    E --> H[Results list]
    F --> H
    G --> H
    H --> I{Apply more filters?}
    I -- yes --> J[Filter sheet: date, time, party size,<br/>rating, amenities]
    J --> H
    I -- no --> K[Tap a restaurant card]
    H --> L{No results?}
    L -- yes --> M[Empty state:<br/>'nothing matches — try nearby areas'<br/>+ suggested alternatives]
    K --> N[Restaurant Detail Screen]
```

**Restaurant Detail Screen contents (top to bottom):** cover photo carousel, name (ar/en), rating + review count, cuisine tags, price band, neighborhood + map pin + distance, availability widget (see flow 3), amenities icons, menu tab, photos tab, reviews tab, policies (cancellation window, deposit if any), "Save" heart icon.

## 3. Core Booking Flow — the flow that matters most

```mermaid
flowchart TD
    A[Restaurant Detail Screen] --> B[Availability widget:<br/>date picker + party size stepper]
    B --> C[Tap 'Find a table']
    C --> D{Slots available<br/>at requested time?}
    D -- yes --> E[Slot chips shown<br/>e.g. 7:00, 7:15, 7:30, 8:00]
    D -- no --> F[No exact match:<br/>show nearest alternatives ±2h<br/>+ 'Join waitlist' option]
    E --> G[Tap a time slot]
    F --> G
    G --> H{Logged in?}
    H -- no --> I[Prompt login/OTP<br/>flow 1, then return here]
    H -- yes --> J[Booking review sheet:<br/>date/time/party, seating pref,<br/>occasion tag, special requests,<br/>cancellation policy shown]
    I --> J
    J --> K[Tap 'Confirm Reservation']
    K --> L{Hold succeeds?}
    L -- no, slot just taken --> M[Toast: 'just booked by someone else'<br/>+ auto-refreshed nearby slots]
    L -- yes --> N{Deposit required<br/>by this restaurant?}
    N -- no --> O[Confirmation screen:<br/>reservation code, add to calendar,<br/>directions, share]
    N -- yes --> P[Payment sheet:<br/>card / wallet / Fawry code]
    P --> Q{Payment succeeds?}
    Q -- no --> R[Error + retry<br/>hold still active for 5 min]
    Q -- yes --> O
    O --> S[Push + WhatsApp confirmation sent]
    M --> B
```

**Failure/edge states worth designing explicitly, not as an afterthought:**
- Hold expires while user is filling the review sheet (5-min window per `05-reservation-engine.md`) → sheet shows a countdown in the last minute, and on expiry re-runs availability instead of a dead-end error.
- No slots at all for the date → don't just show "no availability", offer the waitlist join and/or nearby similar restaurants with availability at that time.
- Party size exceeds what any table combination supports → explain why ("max party size for this restaurant is 10") rather than a generic error.

## 4. Modify / Cancel Reservation

```mermaid
flowchart TD
    A[Reservation history] --> B[Tap an upcoming reservation]
    B --> C[Reservation detail screen]
    C --> D{Action?}
    D -- Modify --> E[Same slot picker as booking,<br/>pre-filled with current values]
    E --> F{New slot available?}
    F -- yes --> G[Confirm change<br/>old hold released, new one confirmed atomically]
    F -- no --> H[Show alternatives;<br/>original reservation untouched until user picks]
    D -- Cancel --> I[Cancellation sheet:<br/>shows policy — free / penalty / no refund<br/>based on time-to-reservation]
    I --> J{Confirm cancel?}
    J -- yes, within free window --> K[Cancelled, full refund if deposit existed]
    J -- yes, outside window --> L[Cancelled, penalty shown before confirming<br/>never a surprise charge]
    J -- no --> C
    K --> M[Cancellation confirmed screen<br/>+ 'rebook' suggestion]
    L --> M
```

## 5. Waitlist (customer side)

```mermaid
flowchart TD
    A[No slots at desired time] --> B[Tap 'Join waitlist']
    B --> C[Confirm date/time window + party size]
    C --> D[Waitlist confirmation:<br/>shows position, no guaranteed time]
    D --> E{Table frees up<br/>matching this entry}
    E -- yes --> F[Push notification:<br/>'Table available — claim in 10 min']
    F --> G{User claims in time?}
    G -- yes --> H[Goes straight into booking-review sheet<br/>flow 3, step J, pre-filled]
    G -- no, expires --> I[Offer moves to next person;<br/>this user notified 'offer expired'<br/>+ option to rejoin]
    D --> J[User can cancel waitlist entry anytime<br/>from reservation history]
```

## 6. Post-Visit / Review

```mermaid
flowchart TD
    A[Reservation marked 'completed'<br/>by restaurant after visit] --> B[Push next morning:<br/>'How was your visit to X?']
    B --> C{User taps notification<br/>or opens from history}
    C --> D[Review screen:<br/>overall stars + food/service/ambience<br/>+ optional text + photos]
    D --> E[Submit]
    E --> F{Passes auto-moderation?}
    F -- yes --> G[Published immediately<br/>+ thank-you screen]
    F -- flagged --> H[Shown to user as 'submitted,<br/>pending review' — not silently dropped]
    G --> I[Owner can reply — visible to reviewer<br/>as a push when they do]
```

**Constraint carried from the schema:** one review per completed reservation, and the review prompt only fires for reservations with `status = completed` — never for cancelled or no-show reservations.

---

**Next up (once we finish discussing this app's features):** the restaurant management app flows — owner onboarding, daily reservation-book operation, walk-in entry, and the admin approval flow living inside the same app.
