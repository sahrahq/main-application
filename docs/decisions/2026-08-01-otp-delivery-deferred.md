# 2026-08-01 — OTP delivery is STUBBED. Real sending is a launch blocker.

> ## 🚨 LAUNCH BLOCKER — DO NOT GO LIVE WITHOUT READING THIS
>
> **OTP codes are not sent to anyone.** They are written to the application
> log. Anyone who can read the logs can log in as any user whose phone number
> they know.
>
> **الإرسال الحقيقي للـ OTP متأجّل لحد ما الشركة تتأسّس ويتفتح حساب
> WhatsApp Business. لازم يتعمل قبل الإطلاق — من غيره أي حد يقدر يقرأ اللوج
> يدخل بحساب أي مستخدم.**

**Status:** accepted, temporary — must be reversed before launch
**Blocks:** production launch
**Affects:** `apps/api/src/modules/auth/otp/delivery/`

## Context

`02-functional-requirements.md` C-1.2 makes phone OTP a **P0** requirement and
names the channel: *"WhatsApp OTP is cheaper and more reliable than SMS"*, with
SMS as fallback.

Both channels need something SAHRA does not yet have:

| Channel | Needs |
|---|---|
| WhatsApp Business API | A registered company, a verified WhatsApp Business account, a Meta Business Manager, and an approved message template for authentication |
| SMS (fallback) | A contract with an Egyptian aggregator, and a registered sender ID |

Company registration is not in place, so neither can be provisioned. Waiting
for it would block the entire authentication flow — registration, phone login,
and password reset all route through OTP.

## Decision

Ship the OTP **logic** complete, with delivery behind a port.

- `OtpDelivery` (`otp.ports.ts`) is the interface: `send({ phone, code, purpose })`.
- `LoggingOtpDelivery` is the shipped adapter. It writes the code to the log
  with a `[STUB DELIVERY]` warning and sends nothing.
- **It throws on construction when `NODE_ENV=production`.** Forgetting to swap
  the adapter is the obvious way this becomes a breach, so the process refuses
  to boot rather than quietly logging live credentials into log aggregation.

Everything else is real and tested: 6-digit CSPRNG codes, SHA-256 at rest,
5-minute TTL, 5-attempt lock, constant-time comparison, and the per-phone and
per-IP send limits from doc 09 §1.1.

## What has to happen before launch

1. Register the company; open a Meta Business Manager and a **WhatsApp Business
   API** account.
2. Get an authentication message template approved (Arabic **and** English —
   CLAUDE.md requires both).
3. Contract an Egyptian SMS aggregator for fallback and register a sender ID.
4. Write `WhatsAppOtpDelivery` and `SmsOtpDelivery` against the existing
   `OtpDelivery` interface, plus a fallback wrapper (WhatsApp first, SMS on
   failure).
5. Bind `OTP_DELIVERY` to the real adapter in `AuthModule`.
6. Delete `LoggingOtpDelivery` from the production path.
7. Re-check the send limits against real carrier pricing. The current values
   (3 per phone / 10 min, 10 per IP / 10 min) were chosen from doc 06 §1, not
   from a bill.

**Nothing in `OtpService` changes.** That is the point of the port: the
integration surface is one class and one binding.

## Alternatives rejected

- **Wait for company registration.** Blocks auth entirely, and blocks every
  screen that needs a signed-in user — which is most of them.
- **Return the code in the API response for now.** Turns a temporary
  inconvenience into a permanent hole the moment someone forgets to remove it,
  and it would be invisible in the logs rather than shouting `[STUB DELIVERY]`.
- **A third-party sender under a personal account.** Sender IDs and WhatsApp
  templates are tied to the registered business; migrating later would break
  message continuity and risk the number's reputation.

## Consequences

- **The API cannot serve production traffic** until step 5. The guard in
  `LoggingOtpDelivery` enforces this rather than trusting anyone to remember.
- Local and staging development is unblocked: the code is in the log.
- The OTP logic is fully tested now (11 unit tests), so the eventual provider
  swap is an integration task, not a re-implementation.
