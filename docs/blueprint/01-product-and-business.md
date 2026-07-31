# SAHRA Blueprint — 01: Product Understanding & Business Strategy

*Covers blueprint sections 1 (Product Understanding) and 15 (Business Strategy). Tailored to SAHRA — a Resy-class reservation and dining-discovery platform for Egypt and the MENA region.*

---

## 1. How Resy and OpenTable Work

Both platforms are **two-sided marketplaces** connecting diners (demand) with restaurant tables (supply). Their core asset is a real-time **inventory system for tables**: each restaurant configures its floor plan, seating capacity, service periods, and turn times; the platform exposes bookable "slots" to consumers and gives the restaurant an operations console (Resy OS, OpenTable GuestCenter) for the front-of-house team.

**The mechanics:**

1. A restaurant defines tables (capacity, combinability), shifts (lunch, dinner), slot intervals (usually 15 min), and turn times (e.g., a 4-top turns in 105 min).
2. The platform computes availability in real time: a slot is offered only if a suitable table (or combination) is free for the entire projected duration of the meal.
3. Diners search, filter, and book. The system holds inventory momentarily during checkout, confirms atomically, and notifies both sides.
4. The restaurant console manages the night: seating guests, marking no-shows, walk-ins, waitlists, and table status — which continuously re-feeds availability.
5. Post-visit, the platform closes the loop with reviews, guest profiles (allergies, VIP tags, spend history), and CRM/marketing tools.

**The strategic difference between them** (from the SAHRA Strategy Book): OpenTable monetizes booking *volume* — subscription plus **per-cover fees** ($1.50/network cover), which punishes successful independent restaurants. Resy (owned by American Express, which also acquired Tock in 2024 for ~$400M) is subscription-only ($249–$899/mo) and is effectively subsidized by AmEx cardmember-engagement economics — Resy users spend 3.5× more on dining than non-Resy AmEx members. OpenTable's US share eroded from ~51% (2022) to ~46% (2024) largely because of this pricing tension. **Neither has any presence in Egypt or MENA.**

## 2. The Three Roles

**Customers (diners)** discover restaurants, view real-time availability, book/modify/cancel reservations, join waitlists, pay deposits where required, write reviews, earn loyalty points, and share plans socially. For SAHRA the customer is the Cairo urban professional and expat (Zamalek/New Cairo/Maadi first), median-age-24 market, mobile-first, Arabic/English bilingual.

**Restaurant owners** are the paying side. They register a venue, pass verification, configure floor plan/hours/menus/photos, manage the reservation book and waitlist in real time, manage staff access, run promotions, and read analytics (covers, no-show rate, revenue attribution). Their alternative today in Cairo is a phone + paper notebook + a hostess — SAHRA's pitch must beat that at a price below the cost of one lost booking.

**Administrators (the SAHRA platform team)** approve restaurants, moderate content and reviews, manage users and roles, oversee payments/settlements/commissions, monitor system health and fraud, run support, and analyze marketplace-wide metrics.

## 3. Monetization Strategies

| Strategy | How it works | SAHRA fit (Egypt) |
|---|---|---|
| **Commission per reservation** | $0.25–$1.50 per seated cover (OpenTable model) | ❌ Avoid at launch. It's OpenTable's most-hated feature and a structural weakness SAHRA should exploit. Revisit only for promoted placement covers. |
| **Subscription plans (SaaS)** | Tiered monthly fee for the restaurant console | ✅ **Primary revenue.** SAHRA Basic (free/low-cost booking management) → SAHRA Pro at **$80–100/mo** (advanced analytics, AI guest profiling, marketing tools) per the Strategy Book. Priced in EGP with USD-indexed review to manage devaluation risk. |
| **Featured restaurants** | Paid placement in search/collections ("Trending in Zamalek") | ✅ Phase 2. High margin; must be clearly labeled to protect trust. |
| **Advertising** | Banner/native ads from F&B brands, banks, delivery apps | ⚠️ Phase 3 only. Bank card-linked dining offers (CIB, Banque Misr) are the culturally right version of "advertising" in Egypt. |
| **Premium analytics** | Deeper BI: demand forecasting, guest cohorts, Ramadan demand curves | ✅ Bundled into SAHRA Pro; standalone add-on for groups/chains. |
| **Reservation/deposit fees** | Fee on prepaid deposits or ticketed events (iftar seatings, chef's tables) | ✅ Phase 2 — Ramadan iftar/sohour seatings are a uniquely Egyptian ticketed-event opportunity (Tock model). Take 3–5% on prepaid events. |
| **White-label** | SAHRA engine powering hotel groups / hospitality chains under their brand | ✅ Phase 3+. Gulf hotel groups (Dubai, Riyadh expansion in Year 3) are natural buyers. |
| **Consumer premium tier** | Diner subscription: priority waitlist, exclusive tables, member events | ⚠️ Test in Year 2. Strategy Book flags premium conversion as the thesis to validate early via LTV:CAC tracking from Month 1. |

**Revenue model summary:** subscription-first (no per-cover fees — the explicit anti-OpenTable wedge), with event ticketing and featured placement as the second and third engines. The Strategy Book is explicit that the Year-3 prize is not the ~$588K subscription ARR from 700 restaurants but the behavioral data and social graph of ~200K MAU that powers recommendations and organic acquisition, with a path to ~$2.1M ARR in Cairo and $15M+ ARR by Year 5 with MENA expansion.

---

## 4. Business Strategy (Section 15)

### 4.1 MVP Features (build first — target launch Month 5, hard date)

**Customer:** email + Google/Apple sign-in, phone OTP (essential in Egypt), search with filters (area, cuisine, price, availability), restaurant profile (photos, menu, hours, map), real-time booking, modify/cancel, favorites, push + WhatsApp/SMS confirmations, reservation history, Arabic/English with full RTL.

**Restaurant:** owner registration + verification, restaurant profile setup, table & floor configuration, hours/shifts/slot rules, reservation book (list view), manual walk-in/phone-booking entry (critical — the hostess must run the *whole* book in SAHRA or she'll abandon it), no-show marking, basic daily analytics.

**Admin:** restaurant approval queue, user management, content moderation, basic dashboards.

### 4.2 Postpone (v1.1 → Year 2)

Payments/deposits (launch bookings free — Egypt's card penetration makes deposits a filter, not a feature, at MVP), reviews (seed with imported ratings; open UGC after moderation tooling exists), loyalty & referrals, waitlist, promotions engine, floor-plan visual editor (list-based tables first), staff roles granularity, consumer premium tier, advanced analytics, event ticketing, white-label, social graph features (the long-term differentiator, but not MVP).

### 4.3 Customer Acquisition

Expats first (Zamalek/Maadi) — digitally fluent, underserved, already trained on Resy/OpenTable abroad, socially influential; they seed Egyptian professionals through the same networks. Channels: Instagram/TikTok food content (highest-engagement category in Egypt), micro-influencer dinners, restaurant cross-promotion (table tents, QR codes — every partner restaurant is an acquisition channel), referral credits at v1.1.

### 4.4 Restaurant Acquisition

Door-to-door founder-led sales for the first 50 (target: 50 by Month 6, 100 by Month 12). Hire the **restaurant success manager before public launch** (Strategy Book recommendation #2). Land with the free tier + white-glove onboarding (SAHRA staff digitizes their floor plan and photos), expand to Pro. Get 5 letters of intent before pre-seed. Target venues serving economically resilient audiences (expats, upper-middle class, tourists).

### 4.5 Marketing & Growth

Neighborhood-by-neighborhood density (Brooklyn strategy — Resy won Brooklyn with 53% share before expanding): win Zamalek completely, then New Cairo, then Maadi/Heliopolis. Ramadan is the growth holiday: iftar/sohour bookings are high-intent, capacity-constrained, and culturally synced with "sahra" (the evening gathering the brand is named for). Year 3: Dubai and Riyadh.

### 4.6 Competitive Advantages vs. Resy/OpenTable (if they enter Egypt)

1. **Pricing**: subscription-only, EGP-denominated, no per-cover fees.
2. **Local payment rails**: Paymob, Fawry, InstaPay, mobile wallets, cash-on-arrival flows — global platforms assume card infrastructure Egypt doesn't have.
3. **Cultural product depth**: Ramadan modes (iftar precise-sunset seatings, sohour late-night slots), family seating preferences, prayer-time-aware slotting, full Arabic RTL — expensive for an international player to retrofit.
4. **Relationship moat**: deep Cairo restaurant relationships and local knowledge baked into the product (Strategy Book: "the Egyptian market is SAHRA's moat").
5. **Social layer**: peer recommendation and shared dining memory — the domain Resy's AI has explicitly *not* entered.
6. **Elmenus**: treat as partnership/data opportunity (menus, discovery traffic), not a threat.

### 4.7 KPIs from Day 1

LTV:CAC (from Month 1, per Strategy Book), restaurant count & logo retention, covers seated/week, no-show rate (the number that sells Pro), booking completion rate, D30 diner retention, WAU/MAU.
