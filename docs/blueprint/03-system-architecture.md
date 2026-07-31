# SAHRA Blueprint — 03: System Architecture

*All diagrams in Mermaid. The architecture shown is the recommended hybrid (doc 08): Flutter → NestJS modular monolith → Supabase PostgreSQL + Redis, with Firebase for FCM/Analytics/Crashlytics.*

---

## 1. High-Level System Architecture

```mermaid
flowchart TB
    subgraph Clients
        MA[Flutter Mobile App<br/>Customers - iOS/Android]
        RA[Flutter Mobile/Tablet App<br/>Restaurant Console]
        WA[Flutter Web<br/>Admin Dashboard]
    end

    CDN[CDN - CloudFront/Cloudflare<br/>images, static assets]
    LB[Load Balancer + WAF<br/>rate limiting, DDoS protection]

    subgraph Backend["NestJS Backend (modular monolith)"]
        GW[API Gateway Layer<br/>REST v1, validation, authz]
        AUTH[Auth Module<br/>JWT, OTP, social]
        RES[Reservation Engine<br/>availability + booking]
        REST[Restaurant Module]
        SRCH[Search Module]
        PAY[Payments Module]
        NOTIF[Notification Module]
        ANLYT[Analytics Module]
        ADMIN[Admin Module]
    end

    subgraph Data
        PG[(PostgreSQL<br/>Supabase - primary store)]
        RD[(Redis<br/>cache, locks, rate limits)]
        MQ[[BullMQ Queues<br/>jobs: notifications, emails,<br/>expiry, waitlist]]
        MS[(Meilisearch<br/>restaurant search index)]
        S3[(Object Storage<br/>photos, menus, docs)]
    end

    subgraph Third-Party
        FCM[Firebase FCM<br/>push notifications]
        WAPI[WhatsApp Business API<br/>+ SMS fallback]
        PMB[Paymob / Fawry<br/>payment gateways]
        MAPS[Google Maps APIs]
        FA[Firebase Analytics<br/>+ Crashlytics + Remote Config]
    end

    MON[Monitoring: Grafana,<br/>Prometheus, Sentry, Loki]

    MA & RA & WA --> CDN
    MA & RA & WA --> LB --> GW
    GW --> AUTH & RES & REST & SRCH & PAY & NOTIF & ANLYT & ADMIN
    AUTH & RES & REST & PAY & ADMIN --> PG
    RES --> RD
    SRCH --> MS
    REST --> S3
    RES & PAY & REST --> MQ
    MQ --> NOTIF
    NOTIF --> FCM & WAPI
    PAY <--> PMB
    MA --> FA
    SRCH -. index sync .- PG
    Backend --> MON
```

## 2. Component Diagram

```mermaid
flowchart LR
    subgraph FlutterApp["Flutter App (Clean Architecture)"]
        UI[Presentation<br/>Widgets + Riverpod] --> DOM[Domain<br/>Entities + UseCases] --> DATA[Data<br/>Repositories + DTOs]
        DATA --> API[Dio REST Client]
        DATA --> LC[(Local Cache<br/>Drift/Hive)]
    end

    subgraph NestJS["NestJS Modules"]
        direction TB
        C1[AuthModule] ; C2[UsersModule] ; C3[RestaurantsModule]
        C4[AvailabilityModule] ; C5[ReservationsModule] ; C6[WaitlistModule]
        C7[PaymentsModule] ; C8[ReviewsModule] ; C9[NotificationsModule]
        C10[SearchModule] ; C11[AnalyticsModule] ; C12[AdminModule]
        C13[SharedKernel<br/>guards, interceptors, config]
    end

    API --> NestJS
    C5 --> C4
    C5 --> C6
    C5 --> C7
    C5 -- events --> C9
    C3 -- index events --> C10
    NestJS --> ORM[Prisma ORM] --> PG[(PostgreSQL)]
    C4 & C5 --> REDIS[(Redis)]
    C9 --> QUEUE[[BullMQ]]
```

## 3. Deployment Diagram (Growth stage)

```mermaid
flowchart TB
    U[Users] --> CF[Cloudflare<br/>DNS + WAF + CDN]
    CF --> ALB[AWS ALB<br/>eu-central / me-south region]

    subgraph EKSorECS["AWS ECS Fargate (or EKS later)"]
        A1[API container ×N<br/>auto-scaled 2..20]
        W1[Worker container ×M<br/>BullMQ consumers]
        CRON[Scheduler container<br/>expiry sweeps, digests]
    end

    ALB --> A1
    A1 --> RDSP[(Supabase PostgreSQL<br/>primary + read replica)]
    A1 --> EC[(ElastiCache Redis)]
    A1 --> MSC[(Meilisearch on EC2/ECS)]
    W1 --> RDSP & EC
    CRON --> RDSP
    A1 & W1 --> S3B[(S3 Bucket)]
    subgraph Observability
        PR[Prometheus] --> GF[Grafana]
        LK[Loki logs] --> GF
        SN[Sentry]
    end
    A1 & W1 --> PR & LK & SN
```

## 4. Network Diagram

```mermaid
flowchart TB
    INET((Internet)) --> CF[Cloudflare edge<br/>TLS 1.3, WAF, bot mgmt]
    CF --> IGW[Public subnet<br/>ALB only]
    subgraph VPC["VPC 10.0.0.0/16"]
        subgraph Public["Public subnets (2 AZs)"]
            ALB2[ALB] ; NAT[NAT Gateway]
        end
        subgraph PrivApp["Private app subnets"]
            ECS1[API tasks] ; ECS2[Workers]
        end
        subgraph PrivData["Private data subnets"]
            DB[(PostgreSQL)] ; RDS2[(Redis)] ; MS2[(Meilisearch)]
        end
    end
    IGW --> ALB2 --> ECS1
    ECS1 --> DB & RDS2 & MS2
    ECS2 --> DB & RDS2
    ECS1 & ECS2 --> NAT --> EXT[Paymob, FCM, WhatsApp APIs]
    note1[Security groups:<br/>DB accepts 5432 only from app SG<br/>Redis 6379 only from app SG<br/>No public IPs on private subnets]
```

## 5. Data Flow Diagram (booking a table)

```mermaid
flowchart LR
    D[Diner app] -- "1 search(area, time, party)" --> S[Search Module]
    S -- "2 candidate restaurants" --> AV[Availability Engine]
    AV -- "3 read slots" --> R[(Redis availability cache)]
    AV -- "cache miss" --> P[(PostgreSQL)]
    D -- "4 book(slot)" --> RE[Reservation Engine]
    RE -- "5 lock + tx" --> P
    RE -- "6 invalidate" --> R
    RE -- "7 event: reservation.created" --> Q[[Queue]]
    Q --> N[Notifier] --> F[FCM push to diner]
    N --> W[WhatsApp confirm to diner]
    N --> RT[Realtime update to restaurant console]
    RE -- "8 analytics event" --> AN[(Analytics store)]
```

## 6. Sequence Diagrams

### 6.1 User Registration (phone OTP + email)

```mermaid
sequenceDiagram
    autonumber
    participant App as Flutter App
    participant API as NestJS Auth
    participant DB as PostgreSQL
    participant WA as WhatsApp/SMS
    App->>API: POST /v1/auth/register {phone, email, password, name}
    API->>API: validate, check uniqueness, hash password (argon2)
    API->>DB: INSERT user (status=pending_verification)
    API->>WA: send OTP (6-digit, 5 min TTL, hashed in Redis)
    API-->>App: 201 {user_id, otp_required}
    App->>API: POST /v1/auth/verify-otp {user_id, code}
    API->>API: verify code (max 5 attempts, rate-limited)
    API->>DB: UPDATE user status=active
    API-->>App: 200 {access_token (15m), refresh_token (30d, rotating)}
```

### 6.2 Restaurant Registration & Approval

```mermaid
sequenceDiagram
    autonumber
    participant O as Owner App
    participant API as NestJS
    participant S3 as Storage
    participant DB as PostgreSQL
    participant Adm as Admin Dashboard
    O->>API: POST /v1/owner/restaurants {profile, location}
    API->>DB: INSERT restaurant (status=draft)
    O->>API: request signed upload URLs
    API->>S3: presign PUT (license, photos)
    O->>S3: upload files
    O->>API: POST /v1/owner/restaurants/:id/submit
    API->>DB: status=pending_review, enqueue admin task
    API-->>Adm: appears in approval queue (realtime)
    Adm->>API: POST /v1/admin/restaurants/:id/approve
    API->>DB: status=active + audit log
    API->>API: emit restaurant.approved → search index + owner notification
    API-->>O: push "Your restaurant is live"
```

### 6.3 Reservation Creation (happy path with hold)

```mermaid
sequenceDiagram
    autonumber
    participant D as Diner App
    participant API as Reservation Engine
    participant R as Redis
    participant DB as PostgreSQL
    participant Q as Queue/Notifier
    D->>API: GET /v1/restaurants/:id/availability?date&party=4
    API->>R: read cached slot map
    API-->>D: available slots
    D->>API: POST /v1/reservations/holds {slot, party, Idempotency-Key}
    API->>DB: SELECT tables FOR UPDATE SKIP LOCKED + conflict check
    API->>DB: INSERT reservation (status=held, expires_at=now()+5m)
    API->>R: invalidate slot cache
    API-->>D: 201 {hold_id, expires_at}
    D->>API: POST /v1/reservations/holds/:id/confirm {requests, occasion}
    API->>DB: UPDATE status=confirmed (tx re-validates expiry)
    API->>Q: reservation.created
    Q-->>D: push + WhatsApp confirmation
    Q-->>API: realtime event to restaurant console
    Note over API,DB: Expiry worker cancels un-confirmed holds after 5 min
```

### 6.4 Reservation Cancellation

```mermaid
sequenceDiagram
    autonumber
    participant D as Diner App
    participant API as NestJS
    participant DB as PostgreSQL
    participant PAY as Payments
    participant Q as Queue
    D->>API: DELETE /v1/reservations/:id
    API->>DB: load reservation + restaurant policy (tx)
    alt outside free-cancel window & deposit paid
        API->>PAY: compute penalty / partial refund
        PAY->>PAY: refund via Paymob API
    end
    API->>DB: UPDATE status=cancelled_by_user, release table inventory
    API->>Q: reservation.cancelled
    Q-->>D: cancellation confirmation
    Q->>API: check waitlist for freed slot
    API->>Q: waitlist.slot_available → notify first eligible waiter
```

### 6.5 Payment Processing (deposit via Paymob)

```mermaid
sequenceDiagram
    autonumber
    participant D as Diner App
    participant API as Payments Module
    participant PM as Paymob
    participant DB as PostgreSQL
    D->>API: POST /v1/payments/intents {reservation_id, Idempotency-Key}
    API->>DB: INSERT payment (status=pending, amount, currency=EGP)
    API->>PM: create order + payment key
    API-->>D: {payment_token, iframe_url / SDK params}
    D->>PM: card / wallet / Fawry ref payment
    PM-->>API: webhook: transaction processed (HMAC-signed)
    API->>API: verify HMAC, verify amount, dedupe by txn_id
    API->>DB: UPDATE payment status=captured, reservation deposit_paid
    API-->>D: push "Deposit confirmed"
    Note over API: Reconciliation job re-queries Paymob nightly.<br/>Webhook is at-least-once → handler idempotent
```

### 6.6 Push Notification Pipeline

```mermaid
sequenceDiagram
    autonumber
    participant SVC as Any Module
    participant Q as BullMQ
    participant N as Notification Worker
    participant DB as PostgreSQL
    participant FCM as Firebase FCM
    participant WA as WhatsApp API
    SVC->>Q: emit event {type, user_id, payload}
    Q->>N: consume (retry ×3, exponential backoff, DLQ)
    N->>DB: load user prefs + device tokens + locale
    alt push enabled
        N->>FCM: send (ar/en template)
        FCM-->>N: per-token result, prune invalid tokens
    end
    alt whatsapp for critical events
        N->>WA: template message (confirmation/reminder)
    end
    N->>DB: INSERT notification row (in-app center)
```

### 6.7 Waitlist Flow

```mermaid
sequenceDiagram
    autonumber
    participant D as Diner
    participant API as Waitlist Module
    participant DB as PostgreSQL
    participant Q as Queue
    D->>API: POST /v1/waitlists {restaurant, date, window, party}
    API->>DB: INSERT waitlist entry (position by created_at + priority)
    API-->>D: 201 {position}
    Note over API: cancellation frees a slot
    Q->>API: waitlist.slot_available {slot}
    API->>DB: SELECT next matching entry FOR UPDATE SKIP LOCKED
    API->>DB: UPDATE entry status=offered, offer_expires=now()+10m
    API-->>D: push "Table available — claim in 10 min"
    alt claims in time
        D->>API: POST /v1/waitlists/:id/claim (goes through hold+confirm flow)
        API->>DB: reservation created, entry=converted
    else expires
        API->>DB: entry=expired, offer next in queue
    end
```

### 6.8 Review Submission

```mermaid
sequenceDiagram
    autonumber
    participant D as Diner App
    participant API as Reviews Module
    participant DB as PostgreSQL
    participant MOD as Moderation (rules + queue)
    D->>API: POST /v1/reviews {reservation_id, rating, text, photos}
    API->>DB: verify reservation status=completed & belongs to user & no existing review
    API->>MOD: auto-screen (profanity ar/en, spam, PII)
    alt clean
        API->>DB: INSERT review (status=published)
        API->>DB: recompute restaurant rating aggregate (async)
    else flagged
        API->>DB: INSERT review (status=pending_moderation) → admin queue
    end
    API-->>D: 201
    API->>API: notify owner (reply prompt)
```
