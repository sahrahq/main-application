-- Separate Idempotency-Key for the confirm step.
--
-- doc 06 §1 requires an Idempotency-Key on holds AND confirms. They are two
-- distinct mutations issued at different times with different keys, so the
-- existing reservations.idempotency_key (which dedupes the hold) cannot also
-- dedupe the confirm without one legitimately overwriting the other.
--
-- Nullable: walk-in and phone reservations created by staff never pass
-- through a confirm step.

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS confirm_idempotency_key uuid;

CREATE UNIQUE INDEX IF NOT EXISTS reservations_confirm_idempotency_key_key
  ON public.reservations (confirm_idempotency_key);