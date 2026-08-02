-- C-1.6: booking requires an account.
--
-- THE BUG THIS CLOSES WAS INVISIBLE BECAUSE NOTHING OBJECTED TO THE EMPTY
-- COLUMN. `ReservationsService.createHold` had always accepted and stored a
-- `userId`; the HTTP controller never passed one, so every reservation created
-- through the API had `user_id = NULL`. A diner's own booking never appeared
-- in their own `GET /reservations`, and no test, type or constraint said a
-- word about it — the column was nullable, and nullable means "this is fine".
--
-- Application-layer enforcement is now in place, but application layers are
-- exactly what forgot last time. This is the backstop that cannot forget.
--
-- WHY `source` IS PART OF THE PREDICATE, and why the column stays nullable:
-- a walk-in or a phone booking is taken by staff for somebody who has no
-- account and may never have one (R-3.2). Those are legitimately anonymous.
-- What must never be anonymous again is a booking that came through the APP.

-- Fail LOUDLY and readably rather than with a bare constraint violation.
-- Anyone meeting this needs to know what the rows are before deciding, and a
-- migration must never silently delete a reservation somebody is expecting to
-- honour.
DO $$
DECLARE
  offending int;
BEGIN
  SELECT count(*) INTO offending
    FROM reservations WHERE source = 'app' AND user_id IS NULL;

  IF offending > 0 THEN
    RAISE EXCEPTION
      'Cannot add app_booking_has_diner: % app reservation(s) have no user_id.',
      offending
    USING HINT =
      'These predate C-1.6 enforcement. Decide what they are before re-running. '
      'Test or seed data: delete them. REAL BOOKINGS: DO NOT DELETE — they '
      'cannot be attributed retroactively, so contact the diners from the '
      'restaurant''s own records first. To see them: SELECT id, code, '
      'restaurant_id, starts_at, status FROM reservations WHERE source = ''app'' '
      'AND user_id IS NULL ORDER BY starts_at;';
  END IF;
END $$;

ALTER TABLE reservations
  ADD CONSTRAINT app_booking_has_diner
  CHECK (source <> 'app' OR user_id IS NOT NULL);

COMMENT ON CONSTRAINT app_booking_has_diner ON reservations IS
  'C-1.6 — a booking made through the app belongs to a diner. Without an '
  'identity they cannot see it again, cannot cancel it, cannot be told when '
  'the venue cancels, and neither we nor the restaurant can tell a regular '
  'from a serial no-show. Walk-in and phone bookings (R-3.2) are legitimately '
  'anonymous, which is why source is in the predicate rather than the column '
  'being made NOT NULL.';
