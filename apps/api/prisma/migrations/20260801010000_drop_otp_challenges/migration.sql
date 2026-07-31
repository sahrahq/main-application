-- Drop otp_challenges: it contradicted a decision the blueprint had already made.
--
-- docs/blueprint/09-security-and-scalability.md §1.1:
--   "phone OTP hashed in Redis, 5-min TTL, 5 attempts, per-phone and per-IP
--    rate limits (blocks SMS-pumping fraud — a real cost attack in Egypt)"
--
-- A 5-minute secret belongs in a store that expires keys on its own. Holding
-- it in Postgres would accumulate millions of dead rows and require a cleanup
-- job to delete data that Redis discards for free. The per-phone/per-IP rate
-- limiting that blocks SMS-pumping is also a sliding-window problem — Redis's
-- native shape, awkward in SQL.
--
-- The table was created empty and never written to, so no data is lost.
-- refresh_tokens stays: 30-day lifetime with revocation and device binding
-- needs durable storage (same doc, same section).

DROP TABLE IF EXISTS public.otp_challenges;
DROP TYPE  IF EXISTS public.otp_purpose;
