# SAHRA

A Resy-class restaurant reservation platform for Egypt / MENA. Two Flutter apps on one shared NestJS backend, fully bilingual Arabic (RTL) + English.

- **`apps/customer_app`** — diners: discover, book, waitlist, reviews, loyalty. iOS + Android.
- **`apps/management_app`** — restaurant owners and staff, plus a role-gated admin section. Android-first.

## Start here

| If you want to… | Read |
|---|---|
| Set up your machine and start coding | [DEVELOPMENT.md](DEVELOPMENT.md) |
| Drive this repo with Claude Code | [GETTING-STARTED-WITH-CLAUDE-CODE.md](GETTING-STARTED-WITH-CLAUDE-CODE.md) |
| Understand *what* the product does and *how the data works* | [docs/blueprint/00-blueprint-index.md](docs/blueprint/00-blueprint-index.md) |
| Build any screen or component | [docs/design/DESIGN-RULES.md](docs/design/DESIGN-RULES.md) |
| Ship to the App Store / Play Store | [STORE-DEPLOYMENT.md](STORE-DEPLOYMENT.md) |

[CLAUDE.md](CLAUDE.md) is the single entry point Claude Code loads automatically every session. There is exactly one CLAUDE.md in this repo — don't add another.

## Layout

```
sahra/
├── CLAUDE.md                            # Claude Code contract (technical + design rules)
├── DEVELOPMENT.md                       # full technical guide: stack, setup, build order
├── GETTING-STARTED-WITH-CLAUDE-CODE.md  # prompt-by-prompt walkthrough
├── STORE-DEPLOYMENT.md                  # App Store / Play Store release steps
└── docs/
    ├── blueprint/    # 12 technical docs — product, architecture, DB, API, security, roadmap
    ├── design/       # design contract, tokens, HTML UI kit, assets
    └── decisions/    # decision log: YYYY-MM-DD-topic.md for choices not in the blueprint
```

`apps/` and `packages/` are created during Phase 1 — see [DEVELOPMENT.md](DEVELOPMENT.md) §3 for the target layout and §11 for the order to build in.

## The rules that don't bend

1. **A table can never be double-booked** — three-layer prevention, with its concurrency stress test written *first*. [docs/blueprint/05-reservation-engine.md](docs/blueprint/05-reservation-engine.md)
2. **Every API mutation is idempotent** via `Idempotency-Key`. [docs/blueprint/06-api-design.md](docs/blueprint/06-api-design.md)
3. **Contract-first API** — Flutter models are generated from the OpenAPI spec into `packages/sahra_api_client`, never hand-written.
4. **No hardcoded colors or spacing** — every value comes from `docs/design/tokens.json` through the Flutter theme.
5. **Every screen ships RTL-tested and dark-mode-tested**, with 44px minimum touch targets.

Full detail and the rest of the list: [CLAUDE.md](CLAUDE.md).
