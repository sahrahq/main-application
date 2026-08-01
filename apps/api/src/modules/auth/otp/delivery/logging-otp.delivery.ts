import { Injectable, Logger } from "@nestjs/common";
import type { OtpDelivery, OtpPurpose } from "../otp.ports";

/**
 * STUB DELIVERY — writes the code to the application log instead of sending it.
 *
 * Real delivery (WhatsApp Business API, SMS fallback) is blocked on company
 * registration; see docs/decisions/2026-08-01-otp-delivery-deferred.md.
 * Replacing this class is the entire integration surface — OtpService does not
 * change.
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

  async send(message: { phone: string; code: string; purpose: OtpPurpose }): Promise<void> {
    this.logger.warn(
      `[STUB DELIVERY] ${message.purpose} code for ${message.phone} is ${message.code} ` +
        `— not actually sent. Real delivery pending company registration.`,
    );
  }
}