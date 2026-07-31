# SAHRA Blueprint — 07: Flutter App Architecture & Best Practices

*Covers blueprint sections 7 and 12. Three Flutter surfaces share one codebase philosophy: Customer app (iOS/Android), Restaurant console (Android tablet-first), Admin dashboard (Flutter Web).*

---

## 1. Architecture Pattern Choice

| Pattern | Verdict for SAHRA |
|---|---|
| **MVC** | ❌ Controllers become god-objects; no seam for testing business rules; collapses beyond ~20 screens. |
| **MVP** | ❌ Presenter boilerplate without solving state propagation; designed for imperative UIs, fights Flutter's declarative model. |
| **MVVM** | ⚠️ Good fit for Flutter (ViewModel ≈ state notifier) but under-specifies the data/domain layers — fine for small apps, insufficient for a marketplace with offline cache, payments, and 3 user roles. |
| **Clean Architecture** | ✅ **Chosen.** Presentation / Domain / Data layers with dependency rule pointing inward. Domain (entities + use cases) is pure Dart — trivially unit-testable; swapping REST for GraphQL or adding offline cache touches only the data layer; feature teams work in parallel without merge collisions. |

**Decision: Clean Architecture organized feature-first, with MVVM-style presentation inside each feature** (Riverpod notifiers act as ViewModels). Pragmatic rule: trivial CRUD screens may skip formal use-case classes and call repositories directly — dogma costs velocity; the rule is "domain logic never lives in widgets."

## 2. Project Structure

```text
lib/
├── core/                       # framework-agnostic building blocks
│   ├── error/                  # Failure types, exception→failure mappers
│   ├── network/                # Dio client, interceptors (auth, retry, locale, idempotency)
│   ├── storage/                # secure storage, Drift database, cache policies
│   ├── utils/                  # formatters (EGP, Hijri/Gregorian dates), validators
│   └── constants/
├── config/
│   ├── env/                    # dev / staging / prod (--dart-define-from-file)
│   ├── theme/                  # design tokens from sahra-design-system-v1 (light/dark)
│   └── flavors.dart
├── shared/
│   ├── widgets/                # SahraButton, SlotChip, RatingStars, EmptyState…
│   ├── extensions/
│   └── providers/              # connectivity, app lifecycle, locale
├── features/
│   ├── authentication/
│   │   ├── data/               # dto/, datasources/ (remote, local), repositories_impl/
│   │   ├── domain/             # entities/, repositories/ (abstract), usecases/
│   │   └── presentation/       # screens/, widgets/, providers/ (Riverpod notifiers)
│   ├── restaurants/            # search, detail, menus, favorites
│   ├── reservations/           # availability, hold/confirm, history, waitlist
│   ├── reviews/
│   ├── notifications/
│   ├── payments/
│   ├── profile/
│   └── owner_console/          # restaurant-side features (separate entry point)
├── services/                   # app-level singletons: push, analytics, deep links, remote config
├── routes/                     # GoRouter config, guards, route names
├── localization/               # ARB files: app_ar.arb, app_en.arb
└── main.dart                   # + main_dev.dart / main_prod.dart bootstraps
```

Monorepo note: `packages/sahra_api_client` (generated from OpenAPI), `packages/sahra_design_system` (tokens + shared widgets) extracted as local packages shared by all three apps.

## 3. Cross-Cutting Recommendations

| Concern | Choice | Why |
|---|---|---|
| **State management** | **Riverpod 2 (with codegen)** | Compile-safe DI + state in one system; `AsyncNotifier` maps perfectly to loading/error/data; auto-dispose prevents leaks; test overrides are one line. Bloc is the respectable alternative (see §5) — Riverpod wins on boilerplate and DI unification. |
| **Dependency injection** | Riverpod providers (no get_it needed) | One graph for services *and* state; overridable per test/flavor. |
| **Navigation** | GoRouter | Declarative, deep-link-native, guards for auth/roles, web-URL support for the admin dashboard. |
| **Error handling** | Sealed `Failure` hierarchy + `Result<T>`; global `runZonedGuarded` → Crashlytics; user-facing errors always bilingual with retry affordances | |
| **Offline support** | Drift (SQLite) as source-of-truth cache; stale-while-revalidate reads; **outbound mutation queue for the restaurant console** (tonight's book must survive a dead router); connectivity banner | Egyptian connectivity reality |
| **Caching** | HTTP: Dio + interceptor honoring server Cache-Control; images: `cached_network_image` + blurhash placeholders; availability responses: 30 s in-memory TTL | |
| **Localization** | `flutter_localizations` + ARB; full RTL via `Directionality`; **never hardcode left/right — use `EdgeInsetsDirectional`, `Alignment.centerStart`**; Arabic-Indic numeral option; Hijri calendar labels during Ramadan | Arabic parity is a launch gate, not a follow-up |
| **Deep linking** | App Links/Universal Links: `sahra.app/r/{slug}`, `/res/{code}`, `/invite/{code}`; deferred deep links for referral installs | Every restaurant share is an acquisition loop |
| **Performance** | const constructors, `ListView.builder` + itemExtent, precached hero images, isolates for JSON >100 KB, deferred loading for owner console, DevTools budget: no frame > 16 ms on a mid-range Android | Cold start < 3 s target |
| **Security** | `flutter_secure_storage` for tokens; certificate pinning (with remote-config kill switch); no secrets in Dart code (all server-side); jailbreak/root signal → step-up auth for payments; obfuscation (`--obfuscate --split-debug-info`) | |

## 4. Testing Strategy (Section 12)

| Layer | Tool | Target |
|---|---|---|
| Unit (domain + notifiers) | `flutter_test`, `mocktail` | Use cases, validators, state machines — **80%+ on domain**; booking state machine at ~100% |
| Widget | `flutter_test` golden + interaction | Shared design-system widgets, critical screens (slot picker, booking sheet) in **both LTR and RTL** goldens |
| Integration | `integration_test` on Firebase Test Lab device matrix (cheap Androids included) | Golden path: search → book → cancel; owner path: accept → seat |
| Contract | Generated API client vs. committed OpenAPI spec | CI-blocking |

## 5. Riverpod vs. Bloc (explicit comparison)

- **Bloc**: enforced event→state discipline, superb traceability (`BlocObserver`), bigger ceremony per feature (~4 files), separate DI (get_it) still needed. Best when the team is large and junior-heavy and needs rails.
- **Riverpod**: less boilerplate, unified DI, compile-time safety, `ref.watch` composition of derived state (e.g., `availabilityProvider(restaurantId, date)` family). Discipline must come from convention.
- **For SAHRA** (small senior-leaning team, 3 surfaces, lots of derived async state): **Riverpod**. Adopt a lint-enforced convention: one `@riverpod` notifier per screen, side-effects only in notifiers, never in widgets.

## 6. World-Class App Checklist (Section 12 continued)

- **Accessibility:** Semantics labels on all interactive widgets (ar + en), 44 px touch targets, WCAG AA contrast (verify SAHRA brand palette in dark mode), dynamic type support tested at 200%, TalkBack/VoiceOver passes on the booking flow.
- **Responsive design:** breakpoint system (compact phone / tablet / web); restaurant console optimized for 10" Android tablets in landscape; admin dashboard is desktop-web-first.
- **Dark mode:** token-driven from the design system doc (`claude/sahra-design-system-v1.md`); OLED-friendly true-black variant optional; test both themes × both directions (4 golden variants).
- **Analytics:** Firebase Analytics with a **typed event catalog** (`search_performed`, `slot_selected`, `booking_confirmed`, `booking_cancelled`, funnel-complete events) reviewed like an API contract; screen-view auto-tracking; no PII in event params.
- **Crash reporting:** Crashlytics + Sentry breadcrumbs on the booking flow; crash-free-sessions ≥ 99.7% as a release gate.
- **Release hygiene:** feature flags via Remote Config; staged rollouts (10% → 50% → 100%); forced-upgrade mechanism; shorebird/code-push optional for emergency Dart-only fixes.
