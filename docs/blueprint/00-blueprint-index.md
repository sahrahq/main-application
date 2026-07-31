# SAHRA Technical Blueprint — Index (v1, July 2026)

Complete production blueprint for SAHRA: a Resy-class restaurant reservation platform for Egypt/MENA, built with Flutter. Tailored to the SAHRA Strategy Book 2026 and the SAHRA design system v1.

| Doc | Contents | Blueprint sections |
|---|---|---|
| `01-product-and-business.md` | How Resy/OpenTable work, roles, monetization, MVP scope, GTM, competitive strategy | 1, 15 |
| `02-functional-requirements.md` | Customer / owner / admin requirements with priorities (P0/P1/P2) + NFRs | 2 |
| `03-system-architecture.md` | High-level, component, deployment, network, data-flow diagrams + 8 sequence diagrams (Mermaid) | 3 |
| `04-database-design.md` | Full ER diagram, 20+ table schemas, constraints, indexes, optimization rationale | 4 |
| `05-reservation-engine.md` | Allocation algorithm, anti-double-booking (3 layers), holds, waitlist, iftar peak handling, idempotency, pseudocode | 5 |
| `06-api-design.md` | REST API spec: auth, customer, owner, admin; errors, validation, versioning | 6 |
| `07-flutter-architecture.md` | Clean Architecture choice, project structure, Riverpod, offline, RTL, testing, best practices | 7, 12 |
| `08-tech-stack.md` | 6 backend options compared; framework/DB/BaaS comparisons; final hybrid recommendation | 8 |
| `09-security-and-scalability.md` | Auth/RBAC/PCI/PDPL security; scaling stages 10k → 100k → 1M+ with diagrams | 9, 10 |
| `10-devops-roadmap-cto.md` | Docker/ECS/Terraform, CI/CD pipeline, 8-phase roadmap with costs & team, maintenance plan, CTO recommendation & migration strategy | 11, 13, 14, 16 |

**Headline decisions:** Flutter (3 surfaces) → NestJS modular monolith → Supabase PostgreSQL + Redis + BullMQ + Meilisearch; Firebase only for FCM/Analytics/Crashlytics/Remote Config; Paymob + Fawry payments; WhatsApp-first messaging; subscription-only monetization (no per-cover fees); MVP launch Month 5; Ramadan iftar is the design peak.
