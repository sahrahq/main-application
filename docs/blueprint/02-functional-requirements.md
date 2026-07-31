# SAHRA Blueprint — 02: Functional Requirements

*Requirement IDs: C = Customer, R = Restaurant owner, A = Admin. Priority: **P0** = MVP (Month 5 launch), **P1** = v1.1 (Months 6–12), **P2** = Year 2+.*

---

## 1. Customer Features

### C-1 Authentication & Profile
| ID | Requirement | Priority | Notes (Egypt) |
|---|---|---|---|
| C-1.1 | Sign up / login with email + password (verified email) | P0 | |
| C-1.2 | **Phone OTP login (SMS/WhatsApp)** | P0 | Phone is the primary identity in Egypt; WhatsApp OTP is cheaper and more reliable than SMS |
| C-1.3 | Social login: Google, Apple (App Store requirement), Facebook | P0 | Facebook still significant in Egypt |
| C-1.4 | Password reset via email/OTP; rate-limited | P0 | |
| C-1.5 | Profile: name (Arabic + Latin), phone, avatar, language pref, dietary prefs, default party size | P0 | |
| C-1.6 | Guest browse without account; account required to book | P0 | Reduces funnel friction |
| C-1.7 | Account deletion & data export (GDPR-style + Egypt PDPL Law 151/2020) | P1 | |

### C-2 Discovery & Search
| ID | Requirement | Priority | Notes |
|---|---|---|---|
| C-2.1 | Search by name, cuisine, area/neighborhood, with autocomplete (Arabic + English + "Franco" transliteration) | P0 | "كشري" and "koshary" must both hit |
| C-2.2 | Filters: cuisine, price band (EGP symbols), neighborhood, rating, distance, **available now / at time T for party N**, outdoor seating, family section, shisha, view (Nile), alcohol-free, valet | P0 | Availability-filtered search is the Resy-class differentiator |
| C-2.3 | Sort: relevance, rating, distance, price | P0 | |
| C-2.4 | Map view with clustering | P1 | |
| C-2.5 | Curated collections ("Iftar with a Nile view", "Trending in Zamalek") | P1 | Editorial + paid featured slots (labeled) |
| C-2.6 | Restaurant detail: photos, menus (with prices in EGP), hours, location/directions, amenities, cancellation/deposit policy, reviews, similar restaurants | P0 | |
| C-2.7 | Favorites/saved lists; shareable | P0 | |
| C-2.8 | Personalized recommendations (history + collaborative filtering) | P2 | The long-term data moat |

### C-3 Reservations
| ID | Requirement | Priority | Notes |
|---|---|---|---|
| C-3.1 | View real-time availability for date/time/party size (calendar + slot picker, ±2h alternatives when the requested slot is full) | P0 | |
| C-3.2 | Book with special requests, occasion tag, seating pref (indoor/outdoor/family) | P0 | |
| C-3.3 | 5-minute inventory hold during checkout | P0 | See doc 05 |
| C-3.4 | Modify time/party size (re-checks availability atomically) | P0 | |
| C-3.5 | Cancel with policy display; late-cancel/no-show tracked per user | P0 | No-show score gates future instant booking |
| C-3.6 | Waitlist: join for full slots; auto-notify with claim window (10 min) when a table frees | P1 | |
| C-3.7 | Reservation history + upcoming, add-to-calendar, directions | P0 | |
| C-3.8 | Group invites: share reservation with friends, RSVP | P2 | Social layer |
| C-3.9 | Reminders: 24h and 2h before, via push + WhatsApp | P0 | Single biggest no-show reducer |

### C-4 Payments, Reviews, Loyalty
| ID | Requirement | Priority | Notes |
|---|---|---|---|
| C-4.1 | Deposit / prepaid booking where restaurant requires it (Ramadan, events) | P1 | Paymob gateway: cards, mobile wallets (Vodafone Cash), Fawry reference codes; **cash-on-arrival** fallback with card-guarantee optional |
| C-4.2 | Saved payment methods (tokenized, never stored raw — PCI SAQ-A) | P1 | |
| C-4.3 | Refunds per cancellation policy; automatic on restaurant-initiated cancel | P1 | |
| C-4.4 | Reviews: only after a **seated** reservation (verified diner), 1–5 stars + text + photos; owner replies; report/moderation flow | P1 | Verified-only reviews are a trust wedge vs. Google Maps noise |
| C-4.5 | Loyalty points: earn per seated cover, redeem for partner perks; tier levels | P2 | |
| C-4.6 | Referral codes: both sides get credit after referee's first seated reservation | P1 | Fraud-checked (device, phone uniqueness) |
| C-4.7 | Notifications center + granular preferences (push/SMS/WhatsApp/email per event type) | P0 | |

## 2. Restaurant Owner Features

### R-1 Onboarding
| ID | Requirement | Priority | Notes |
|---|---|---|---|
| R-1.1 | Owner registration (separate role; business phone + email verification) | P0 | |
| R-1.2 | Create restaurant: name (ar/en), description, cuisines, address + map pin, contacts, license/tax-ID upload | P0 | Docs feed admin verification |
| R-1.3 | Submission → admin approval → live (status visible to owner) | P0 | |
| R-1.4 | Multi-restaurant support per owner account (groups/chains) | P1 | |

### R-2 Profile & Inventory Management
| ID | Requirement | Priority | Notes |
|---|---|---|---|
| R-2.1 | Edit profile, amenities, policies (cancellation window, deposit rules, kids policy) | P0 | |
| R-2.2 | Photo upload with ordering, cover photo; server-side resize/WebP | P0 | |
| R-2.3 | Menus: categories → items (name ar/en, description, price, photo, dietary tags); PDF upload fallback | P0 | Fallback matters — many Cairo venues have only PDF/paper menus |
| R-2.4 | Opening hours per weekday; multiple shifts; special dates (holidays); **Ramadan mode** — one-tap seasonal schedule (iftar seating pegged to Maghrib time, sohour slots until 3:00) | P0 | Iftar slot auto-adjusts daily with sunset |
| R-2.5 | Tables: name/number, min–max capacity, zone (indoor/outdoor/family), combinable flags | P0 | |
| R-2.6 | Slot rules: interval (15/30 min), default turn time by party size, pacing cap (max new covers per 15 min), blackout dates, hold-back quota for walk-ins | P0 | Pacing prevents kitchen collapse |
| R-2.7 | Visual floor-plan editor (drag-drop) | P2 | List-based config is enough for MVP |

### R-3 Operations
| ID | Requirement | Priority | Notes |
|---|---|---|---|
| R-3.1 | Reservation book: today view + calendar; statuses (pending/confirmed/seated/completed/no-show/cancelled); real-time updates | P0 | Must work on a cheap Android tablet |
| R-3.2 | Manually add walk-ins & phone bookings (consumes the same inventory) | P0 | Non-negotiable for adoption |
| R-3.3 | Confirm/decline requests (for request-mode restaurants); auto-confirm mode | P0 | |
| R-3.4 | Seat, transfer table, mark no-show, add notes to guest profile (VIP, allergy) | P0 | |
| R-3.5 | Waitlist console: view, notify next, seat from waitlist | P1 | |
| R-3.6 | Staff accounts with roles (manager/host) and per-permission grants; audit trail | P1 | Owner-only at MVP |
| R-3.7 | Offline tolerance: tonight's book cached locally; queued mutations sync on reconnect | P1 | Egyptian connectivity reality |

### R-4 Growth & Admin
| ID | Requirement | Priority | Notes |
|---|---|---|---|
| R-4.1 | Analytics: covers/day, occupancy by shift, no-show rate, lead time, top guests, revenue attribution | P0 basic / P1 full | The Pro upsell engine |
| R-4.2 | Promotions: off-peak discounts, special events, ticketed iftar seatings | P1/P2 | |
| R-4.3 | Notifications: new booking, cancellation, review posted, waitlist activity | P0 | |
| R-4.4 | Subscription management: plan (Basic/Pro), payment method, invoices (EGP), upgrade/downgrade | P1 | Manual invoicing acceptable for first 50 venues |

## 3. Admin Features

| ID | Requirement | Priority | Notes |
|---|---|---|---|
| A-1 | User management: search, view, suspend/ban, role assignment, impersonate-for-support (audited) | P0 | |
| A-2 | Restaurant approval queue: review docs, approve/reject with reason, request changes | P0 | |
| A-3 | Content moderation: photos, menus, reviews; report queue; automated profanity/spam flagging (ar/en) | P1 | |
| A-4 | Payment management: transactions, refunds, settlement to restaurants, reconciliation with Paymob/Fawry | P1 | |
| A-5 | Commission/fee configuration per plan & per restaurant override | P1 | |
| A-6 | Platform analytics: GMV-equivalent (covers × est. value), bookings funnel, cohort retention, restaurant health scores | P1 | |
| A-7 | Reports: scheduled exports (CSV), investor KPI pack | P1 | |
| A-8 | System monitoring dashboard: API health, queue depth, error rates (links to Grafana/Sentry) | P0 | |
| A-9 | Fraud detection: serial no-show users, fake-review rings, referral abuse, stolen-card patterns; rule-based flags → manual review queue | P2 (rules P1) | |
| A-10 | Support dashboard: ticket queue, user context panel, canned responses, escalation | P1 | WhatsApp Business inbox integration is the Egypt-native support channel |
| A-11 | Audit log of every admin action (immutable) | P0 | |
| A-12 | Feature flags & remote config (kill switches, staged rollout) | P1 | |

## 4. Non-Functional Requirements (summary)

- **Availability:** 99.9% for booking APIs (≤ 43 min downtime/month); graceful read-only degradation.
- **Latency:** search P95 < 500 ms; availability check P95 < 300 ms; booking commit P95 < 1 s.
- **Consistency:** zero double-bookings — serializable-equivalent guarantees on inventory (doc 05).
- **Localization:** Arabic (RTL) + English at parity from day 1; all content fields bilingual; Hijri-aware Ramadan scheduling.
- **Performance envelope:** app usable on mid-range Android over 3G; cold start < 3 s; APK ≤ 40 MB.
- **Peaks:** Ramadan iftar is the design peak — ~10× normal booking write throughput in the 2 hours before Maghrib; Thursday/Friday dinners are weekly peaks.
- **Security & privacy:** Egypt PDPL (Law 151/2020) + GDPR-grade practices; PCI SAQ-A via tokenization (doc 09).
