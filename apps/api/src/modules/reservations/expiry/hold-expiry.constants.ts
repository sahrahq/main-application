/** doc 05 section 4 — one queue, one job name, one sweep cadence. */
export const HOLD_EXPIRY_QUEUE = "hold-expiry";
export const EXPIRE_HOLD_JOB = "expire-hold";

/** Backstop cadence. doc 05 section 4: "a sweeper runs every 60 s". */
export const SWEEP_INTERVAL_MS = 60_000;