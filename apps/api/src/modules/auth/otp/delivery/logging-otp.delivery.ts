import { Injectable, Logger } from "@nestjs/common";
import type { OtpDelivery, OtpPurpose } from "../otp.ports";

/**
 * STUB DELIVERY — writes the code to the application log instead of sending it.
 *
 * Real delivery (WhatsApp Business API, SMS fallback) is not built; see
 * docs/decisions/2026-08-01-otp-delivery-deferred.md. Replacing this class is
 * the entire integration surface — OtpService does not change.
 *
 * NOT BLOCKED ON COMPANY REGISTRATION. This file used to say it was, and that
 * was wrong — corrected by the product owner alongside the same error about
 * FCM. It is unbuilt work, not a licensing wall.
 *
 * This adapter REFUSES TO RUN IN PRODUCTION. Logging a live OTP would put a
 * working credential into log aggregation, and "we forgot to swap the adapter"
 * is exactly the mistake this class exists to make impossible.
 */
@Injectable()
export class LoggingOtpDelivery implements OtpDelivery {
  readonly channel = "log";
  private readonly logger = new Logger("OtpDelivery");

  constructor(nodeEnv: string = process.env.NODE_ENV ?? "development") {
    if (nodeEnv === "production") {
      throw new Error(
        "LoggingOtpDelivery must never run in production: it writes OTP codes " +
          "to the log. Configure a real OtpDelivery adapter (WhatsApp/SMS) first.",
      );
    }
  }

  /**
   * FOUR LINES, ON PURPOSE.
   *
   * The code used to be one clause in the middle of a sentence, in a wall of
   * identically-shaped Nest log lines, in a terminal already scrolling with
   * Prisma queries. It was findable if you knew to grep for it and invisible
   * if you did not — the product owner tapped "Send me a code", watched
   * nothing arrive, and had no way to know the code was six inches above.
   *
   * A banner is not decoration here. It is the only delivery channel that
   * exists, so it gets to look like one.
   */
  async send(message: { phone: string; code: string; purpose: OtpPurpose }): Promise<void> {
    this.logger.warn("");
    this.logger.warn("┌─────────────────────────────────────────────┐");
    this.logger.warn(`│  OTP CODE:  ${message.code.padEnd(32)}│`);
    this.logger.warn(`│  for ${message.phone.padEnd(39)}│`);
    this.logger.warn(`│  purpose: ${message.purpose.padEnd(34)}│`);
    this.logger.warn("│  STUB DELIVERY — no SMS was sent (OPS-1)    │");
    this.logger.warn("└─────────────────────────────────────────────┘");
    this.logger.warn("");
  }
}