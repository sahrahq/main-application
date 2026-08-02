import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service';

export interface RegisterDeviceInput {
  userId: string;
  token: string;
  platform: string;
  locale: string;
}

@Injectable()
export class DevicesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Register or re-register a push token for a user.
   *
   * UPSERT ON THE TOKEN, NOT ON (user, token). The token is the address, and
   * an address belongs to a handset rather than to a person: reinstall an app
   * and FCM may hand the same token to a different account; sell the phone and
   * the new owner's account gets it. If registration inserted a second row,
   * BOTH accounts would be pushed — so the previous owner would receive the
   * new owner's reservations.
   *
   * Moving the row is therefore the correct behaviour and not merely the
   * convenient one.
   */
  async register(input: RegisterDeviceInput): Promise<{ id: string }> {
    const row = await this.prisma.device.upsert({
      where: { token: input.token },
      create: {
        userId: input.userId,
        token: input.token,
        platform: input.platform,
        locale: input.locale,
      },
      update: {
        userId: input.userId,
        platform: input.platform,
        locale: input.locale,
        lastSeenAt: new Date(),
        // Re-registering revives a token revoked by an earlier sign-out.
        revokedAt: null,
      },
      select: { id: true },
    });
    return row;
  }

  /**
   * Revoke on sign-out.
   *
   * A push token left attached to a signed-out user sends that person's
   * reservations to whoever holds the handset next — on a shared phone, or one
   * that has been sold, that is a privacy incident rather than an annoyance.
   *
   * Revoked rather than deleted, so "this handset was signed out at 19:04" is
   * still answerable when somebody asks why a notification stopped arriving.
   */
  async revoke(userId: string, token: string): Promise<void> {
    await this.prisma.device.updateMany({
      // BOTH predicates. Without `userId` anyone could revoke any token they
      // could guess, which is a cheap way to silence a diner's cancellations.
      where: { token, userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /** "Log out all devices" (doc 09 §1.1) — the push half of it. */
  async revokeAllForUser(userId: string): Promise<void> {
    await this.prisma.device.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
}
