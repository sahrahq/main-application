-- audit_logs (doc 04 §2, doc 06 §5).
--
-- "No UPDATE/DELETE grants to app role" is the requirement. GRANTs alone do
-- not achieve it here: the API connects as `postgres`, which OWNS this table,
-- and an owner is not bound by its own GRANTs. So the prohibition is enforced
-- by a trigger, which binds the owner too.
--
-- An audit trail that the operator can quietly edit is not an audit trail. The
-- whole value of this table is that a decision cannot be rewritten after the
-- fact — including by us.

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id           BIGSERIAL PRIMARY KEY,
  actor_id     UUID REFERENCES public.users(id) ON DELETE SET NULL,
  actor_role   VARCHAR(30),
  action       VARCHAR(60)  NOT NULL,
  entity_type  VARCHAR(40)  NOT NULL,
  entity_id    UUID         NOT NULL,
  before       JSONB,
  after        JSONB,
  ip           INET,
  user_agent   TEXT,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- doc 04 §2, verbatim.
CREATE INDEX IF NOT EXISTS idx_audit_entity
  ON public.audit_logs (entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_audit_actor_created
  ON public.audit_logs (actor_id, created_at DESC);

-- ─────────────────────────── append-only enforcement ─────────────────────
-- ON DELETE SET NULL above deliberately does NOT conflict with this: erasing a
-- user nulls the actor reference (PDPL erasure anonymises PII) but leaves the
-- record that the action happened. The trigger blocks row deletion, not FK
-- nulling, because an UPDATE issued by the referential action runs as an
-- internal system operation rather than a statement against this table.

CREATE OR REPLACE FUNCTION public.sahra_audit_is_append_only()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION
    'audit_logs is append-only (doc 04 §2): % is not permitted', TG_OP
    USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_no_update ON public.audit_logs;
CREATE TRIGGER trg_audit_no_update
  BEFORE UPDATE ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.sahra_audit_is_append_only();

DROP TRIGGER IF EXISTS trg_audit_no_delete ON public.audit_logs;
CREATE TRIGGER trg_audit_no_delete
  BEFORE DELETE ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.sahra_audit_is_append_only();

-- TRUNCATE bypasses row-level triggers entirely — it needs its own statement
-- trigger, or "DELETE the evidence" is one keyword away.
DROP TRIGGER IF EXISTS trg_audit_no_truncate ON public.audit_logs;
CREATE TRIGGER trg_audit_no_truncate
  BEFORE TRUNCATE ON public.audit_logs
  FOR EACH STATEMENT EXECUTE FUNCTION public.sahra_audit_is_append_only();

-- Defence in depth: when a least-privileged application role is introduced
-- (doc 09), it should hold INSERT and SELECT only. Stated here so the intent
-- travels with the table.
REVOKE UPDATE, DELETE, TRUNCATE ON public.audit_logs FROM PUBLIC;

-- Consistent with the rest of the schema: keep it off the public Data API.
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.audit_logs FROM anon, authenticated;
