# For Group G, when `read_at` is first read

Annotated **2026-08-09** by the silent-lapse sweep. `migration.sql` is
untouched — Prisma checksums applied migrations, so a note beside the file is
the only way to annotate one without it reporting as modified.

## doc 04 asks for an index this migration did not create

doc 04 §notifications:

```
idx_notif_user_unread(user_id, created_at DESC) WHERE read_at IS NULL
```

This migration created:

```sql
CREATE INDEX idx_notifications_user ON notifications (user_id, created_at DESC);
```

Different name, and **not partial**. CLAUDE.md rule 3 makes index names part of
the contract, so this is a real deviation — it just is not one worth fixing
yet.

## Why it was not built

**Nothing reads `read_at`.** Not one query in `apps/api/src`. The notifications
*read* half — unread counts, marking as read, the notification centre — is
Group G. Creating the index now would be an index Postgres maintains on every
insert to serve a query nobody makes.

## What to do in Group G

Create it under **doc 04's name**, `idx_notif_user_unread`, partial on
`WHERE read_at IS NULL`, at the same time as the first query that filters on
`read_at`. Then remove the entry from the `notYet` map in
`apps/api/test/schema-invariants.e2e-spec.ts` — that test fails if the index
appears while the exemption is still listed, so the two cannot drift.

Keep `idx_notifications_user` as well: it serves "all my notifications, newest
first", which is a different read and one the app makes.
