-- A diner must SEE that the restaurant cancelled on them.
--
-- THE FAILURE THIS PREVENTS is the worst one this product can produce: a venue
-- cancels, the reservation quietly leaves the diner's "upcoming" list, and
-- they turn up to a restaurant that is not expecting them — in front of their
-- guests. They blame SAHRA, and they are right to.
--
-- The schema already answers WHO cancelled: `reservation_status` has both
-- `cancelled_by_user` and `cancelled_by_restaurant`, alongside `cancelled_at`
-- and `cancel_reason`. Nothing has to be inferred from timestamps or guessed
-- from an actor. What was missing is whether the diner has been TOLD.
--
-- Without this column the only available exit condition for the upcoming list
-- is a date comparison, which is exactly the silent disappearance above: the
-- booking vanishes on the day it would have happened, whether or not anybody
-- ever read it.
--
-- NULL means "not yet acknowledged", which is the correct default for every
-- existing row: none of them have been shown this notice, because it did not
-- exist.
ALTER TABLE reservations
  ADD COLUMN cancellation_seen_at timestamptz(6);

COMMENT ON COLUMN reservations.cancellation_seen_at IS
  'When the diner acknowledged a restaurant-initiated cancellation. NULL while '
  'unacknowledged, which keeps the reservation VISIBLE in their upcoming list '
  'regardless of date. It leaves that list because they saw it, not because '
  'the date passed.';

-- Partial index: the only query that reads this column asks for the
-- unacknowledged ones, which are a small and self-clearing subset. Indexing
-- the acknowledged rows would be dead weight that grows forever.
CREATE INDEX idx_resv_unacknowledged_cancellation
  ON reservations (user_id, starts_at)
  WHERE status = 'cancelled_by_restaurant' AND cancellation_seen_at IS NULL;
