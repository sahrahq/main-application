import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../../shared/prisma/prisma.service';

/**
 * How long an unverified registration survives. **24 HOURS.**
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THIS NUMBER IS NOT ARBITRARY, AND IT IS NOT A USABILITY SETTING.
 * Read this before changing it.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * The obvious justification — "long enough that someone slow reading their
 * SMS is not cut off, short enough that a squatted number frees up for its
 * owner" — is NO LONGER LOAD-BEARING, and reasoning from it will produce the
 * wrong answer. `AuthService.register` now REPLACES an unverified
 * registration rather than refusing it, so:
 *
 *   - a real owner is never blocked, however long the row has sat there
 *   - a squatted number is free the moment its owner tries to use it
 *
 * Neither outcome depends on this constant at all. Tune it for usability and
 * you are tuning something that has no usability effect.
 *
 * THE ACTUAL BASIS IS A LEGAL ONE: **data minimisation**.
 *
 * A phone number attached to an account nobody ever confirmed is personal
 * data we hold with no lawful basis and no purpose — the person it identifies
 * may never have heard of SAHRA, because anybody can type a stranger's number
 * into a signup form. Egypt's **Personal Data Protection Law 151/2020**, which
 * doc 02 §4 commits this platform to alongside GDPR-grade practice, requires
 * that such data be kept no longer than the purpose needs. The purpose —
 * completing a signup — is over within minutes.
 *
 * 24 hours is therefore an upper bound chosen for one remaining operational
 * reason: it preserves a support window wide enough for "I tried to sign up
 * yesterday and something went wrong". Shorter is defensible. LONGER NEEDS A
 * REASON THAT SURVIVES A REGULATOR ASKING WHY WE STILL HAVE THE NUMBER.
 */
export const PENDING_TTL_HOURS = 24;

/** Hourly. The work is a bounded DELETE; there is nothing to gain from tighter. */
const SWEEP_INTERVAL_MS = 60 * 60 * 1000;

@Injectable()
export class PendingRegistrationSweeper {
  private readonly logger = new Logger(PendingRegistrationSweeper.name);

  constructor(private readonly prisma: PrismaService) {}

  @Interval(SWEEP_INTERVAL_MS)
  async sweep(): Promise<void> {
    try {
      const removed = await this.removeExpired();
      if (removed > 0) {
        this.logger.log(`Removed ${removed} unverified registration(s) older than ${PENDING_TTL_HOURS}h.`);
      }
    } catch (err) {
      // A sweeper that throws takes the interval down with it and stops
      // running silently — the failure mode is "it quietly never ran again".
      this.logger.error(`Pending-registration sweep failed: ${String(err)}`);
    }
  }

  /** Exposed so a test can run one pass without waiting an hour. */
  async removeExpired(now: Date = new Date()): Promise<number> {
    const cutoff = new Date(now.getTime() - PENDING_TTL_HOURS * 3_600_000);

    // Three predicates, all required:
    //
    //   phone_verified_at IS NULL   never proved they hold the number
    //   status = 'pending'          never activated by any route
    //   created_at < cutoff         old enough
    //
    // `phone_verified_at` alone would be the safer single check, but asking
    // both questions means a future bug in either one cannot delete a real
    // account by itself.
    //
    // AND NOT EXISTS a reservation: a pending user should never have booked,
    // because booking needs tokens and tokens need verification. "Should
    // never" is exactly the assumption worth not betting a DELETE on.
    const rows = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT id FROM users u
       WHERE u.phone_verified_at IS NULL
         AND u.status = 'pending'
         AND u.created_at < ${cutoff}
         AND u.deleted_at IS NULL
         AND NOT EXISTS (SELECT 1 FROM reservations r WHERE r.user_id = u.id)`;

    if (rows.length === 0) return 0;
    const ids = rows.map((r) => r.id);

    await this.prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ANY(${ids}::uuid[])`;
    await this.prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ANY(${ids}::uuid[])`;
    await this.prisma.$executeRaw`DELETE FROM users          WHERE id      = ANY(${ids}::uuid[])`;

    return ids.length;
  }
}
