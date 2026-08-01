import type { OtpDelivery, OtpPurpose } from "../otp.ports";

/** Test double: keeps what was "sent" so specs can read the code back. */
export class RecordingOtpDelivery implements OtpDelivery {
  readonly channel = "recording";
  readonly sent: { phone: string; code: string; purpose: OtpPurpose }[] = [];

  async send(message: { phone: string; code: string; purpose: OtpPurpose }): Promise<void> {
    this.sent.push(message);
  }
}