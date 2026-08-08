/**
 * Auth e2e — register, login, and the refresh-rotation security properties
 * from doc 06 §2 and doc 09 §1.1.
 *
 * The reuse-detection test is the one that matters: it is the difference
 * between a stolen refresh token being useful for 30 days and being useful
 * until the victim's next refresh.
 */
import { PrismaClient } from '@prisma/client';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { AuthService, normalizePhone } from '../src/modules/auth/auth.service';
import { TokenService, type TokenPair } from '../src/modules/auth/token.service';
import { OtpService } from '../src/modules/auth/otp/otp.service';
import { InMemoryOtpStore } from '../src/modules/auth/otp/stores/in-memory-otp.store';
import { InMemoryRateLimiter } from '../src/modules/auth/otp/stores/in-memory-rate-limiter';
import { RecordingOtpDelivery } from '../src/modules/auth/otp/delivery/recording-otp.delivery';
import { DevicesService } from '../src/modules/notifications/devices.service';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { resetOtpState } from './support/otp-budget';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });
const config = new ConfigService({
  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET ?? 'test-secret-not-for-production',
});
const tokens = new TokenService(prisma as unknown as PrismaService, new JwtService({}), config);

// Real OTP logic, test doubles for the ports — so the register → verify flow
// is exercised end to end without Redis or a carrier.
const otpDelivery = new RecordingOtpDelivery();
const otp = new OtpService(new InMemoryOtpStore(), new InMemoryRateLimiter(), otpDelivery);
// Real DevicesService — signing out has to revoke push tokens too, and a
// stub here would let that regress unnoticed.
const devices = new DevicesService(prisma as unknown as PrismaService);
const auth = new AuthService(prisma as unknown as PrismaService, tokens, otp, devices);

const PHONE = `010${Date.now().toString().slice(-8)}`;
const PASSWORD = 'correct-horse-battery-staple';
let userId: string;
let registerChallengeId: string;

beforeAll(async () => {
  // Shared per-IP OTP budget — see support/otp-budget.ts.
  await resetOtpState();

  await prisma.$connect();
}, 60_000);

afterAll(async () => {
  if (userId) {
    await prisma.refreshToken.deleteMany({ where: { userId } });
    await prisma.userRole.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } }).catch(() => undefined);
  }
  await prisma.$disconnect();
}, 60_000);

describe('auth — registration and login', () => {
  it('registers and requires OTP before the account is usable', async () => {
    const r = await auth.register({ phone: PHONE, fullName: 'Nour Hassan', password: PASSWORD });
    userId = r.userId;
    registerChallengeId = r.challengeId;

    expect(r.otpRequired).toBe(true);

    const u = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
    expect(u.status).toBe('pending'); // not active until phone is verified
    expect(u.phone).toBe(normalizePhone(PHONE));
    // The password must never be recoverable from the row.
    expect(u.passwordHash).toBeTruthy();
    expect(u.passwordHash).not.toContain(PASSWORD);
    expect(u.passwordHash!.startsWith('$argon2id$')).toBe(true);
  }, 60_000);

  it('verifies the phone, which is what makes the account defended', async () => {
    // Moved ahead of the duplicate test deliberately. 409 `phone_exists` is
    // now the answer for a VERIFIED account only: an unverified registration
    // is reclaimable, because refusing it told real diners their own number
    // was taken (see account-squatting.e2e-spec.ts).
    const code = otpDelivery.sent.filter((m) => m.phone === normalizePhone(PHONE)).at(-1)!.code;
    const outcome = await auth.verifyOtp(registerChallengeId, code);

    // `signed_in`, not `profile_needed`: the row already exists, so answering
    // the code signs them in rather than asking for a name.
    expect(outcome.status).toBe('signed_in');
    expect(outcome.status === 'signed_in' && outcome.tokens.accessToken).toBeTruthy();
    const u = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
    expect(u.status).toBe('active');
    expect(u.phoneVerifiedAt).not.toBeNull();
  }, 60_000);

  it('rejects a duplicate phone even when written in a different format', async () => {
    // Same number, international form — must collide with the local form.
    //
    // This assertion is unchanged, but what it proves has moved: before, it
    // held for ANY existing row; now it holds because the row above is
    // VERIFIED. An unverified one would be reclaimed instead, which is the
    // whole point of the squatting fix.
    await expect(
      auth.register({ phone: normalizePhone(PHONE), fullName: 'Impostor' }),
    ).rejects.toMatchObject({ response: { code: 'phone_exists' } });
  }, 60_000);

  it('and the impostor did not overwrite the password on the way past', async () => {
    // The reclaim path rewrites `passwordHash`. If the verified-account guard
    // ever regressed, this row would silently lose its password and the login
    // test below would fail with a confusing "invalid credentials".
    const u = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
    expect(u.passwordHash).toBeTruthy();
    expect(u.fullName).toBe('Nour Hassan');
  }, 60_000);

  it('logs in and issues a working pair', async () => {
    const pair = await auth.login(PHONE, PASSWORD);
    expect(pair.accessToken.split('.')).toHaveLength(3); // JWT
    expect(pair.expiresIn).toBe(900); // 15 min, doc 09 §1.1
    expect(pair.refreshToken.length).toBeGreaterThan(40);
  }, 60_000);

  it('rejects a wrong password', async () => {
    await expect(auth.login(PHONE, 'wrong-password')).rejects.toMatchObject({
      response: { code: 'invalid_credentials' },
    });
  }, 60_000);

  /**
   * `users.email` IS A CONTACT FIELD, NOT A CREDENTIAL.
   *
   * `login` used to match `phone OR email`. An address on a record that also
   * carried a `passwordHash` was therefore a second way in. Diners were safe
   * only because the customer app happens to send no password at
   * registration — a property of one client, not a boundary — and collecting
   * an optional contact email is exactly what stops that accident holding.
   *
   * This test sets up the dangerous combination on purpose: a real password
   * AND a real email on the same row.
   */
  describe('email is a contact field, not a credential', () => {
    const CONTACT_EMAIL = `contact.${Date.now()}@example.com`;

    it('the account really does carry both a password and an email — setup', async () => {
      // Without this the two assertions below pass on a row with no email at
      // all, which is the shape of a guard that proves nothing.
      await prisma.user.update({
        where: { id: userId },
        data: { email: CONTACT_EMAIL },
      });
      const u = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
      expect(u.email).toBe(CONTACT_EMAIL);
      expect(u.passwordHash).toBeTruthy();
    }, 60_000);

    it('logging in BY EMAIL fails, with the correct password', async () => {
      await expect(auth.login(CONTACT_EMAIL, PASSWORD)).rejects.toMatchObject({
        response: { code: 'invalid_credentials' },
      });
    }, 60_000);

    it('and the same account still logs in by phone — the guard is not just a broken login', async () => {
      // THE GUARD ON THE GUARD. Deleting the whole lookup would satisfy the
      // assertion above and break authentication for everyone.
      const pair = await auth.login(PHONE, PASSWORD);
      expect(pair.accessToken.split('.')).toHaveLength(3);
      expect(pair.user.email).toBe(CONTACT_EMAIL);
    }, 60_000);
  });

  it('gives the same error for an unknown account — no user enumeration', async () => {
    await expect(auth.login('+201555555555', 'whatever')).rejects.toMatchObject({
      response: { code: 'invalid_credentials' },
    });
  }, 60_000);

  it('stores only a hash of the refresh token, never the token', async () => {
    const pair = await auth.login(PHONE, PASSWORD);
    const raw = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n FROM refresh_tokens WHERE token_hash = ${pair.refreshToken}`;
    expect(Number(raw[0].n)).toBe(0); // the raw token is NOT in the column

    const hashed = await prisma.refreshToken.findUnique({
      where: { tokenHash: TokenService.hash(pair.refreshToken) },
    });
    expect(hashed).not.toBeNull();
  }, 60_000);
});

describe('auth — refresh rotation (doc 09 §1.1)', () => {
  it('rotates: the old token dies, a new one works', async () => {
    const first = await auth.login(PHONE, PASSWORD);
    const second = await auth.refresh(first.refreshToken);

    expect(second.refreshToken).not.toBe(first.refreshToken);

    const old = await prisma.refreshToken.findUniqueOrThrow({
      where: { tokenHash: TokenService.hash(first.refreshToken) },
    });
    expect(old.revokedAt).not.toBeNull();
    expect(old.replacedBy).not.toBeNull(); // audit trail intact

    // The new one still rotates.
    const third = await auth.refresh(second.refreshToken);
    expect(third.refreshToken).not.toBe(second.refreshToken);
  }, 60_000);

  it('keeps the whole chain in one family', async () => {
    const a = await auth.login(PHONE, PASSWORD);
    const b = await auth.refresh(a.refreshToken);

    const [ra, rb] = await Promise.all([
      prisma.refreshToken.findUniqueOrThrow({ where: { tokenHash: TokenService.hash(a.refreshToken) } }),
      prisma.refreshToken.findUniqueOrThrow({ where: { tokenHash: TokenService.hash(b.refreshToken) } }),
    ]);
    expect(rb.familyId).toBe(ra.familyId);
  }, 60_000);

  it('REPLAY of a used token kills the entire family', async () => {
    const stolen = await auth.login(PHONE, PASSWORD);

    // Victim refreshes normally.
    const legit = await auth.refresh(stolen.refreshToken);
    const family = (
      await prisma.refreshToken.findUniqueOrThrow({
        where: { tokenHash: TokenService.hash(legit.refreshToken) },
      })
    ).familyId;

    // Thief replays the token they copied earlier.
    await expect(auth.refresh(stolen.refreshToken)).rejects.toMatchObject({
      response: { code: 'token_reuse_detected' },
    });

    // Every token in the family is now dead — including the victim's live one.
    const live = await prisma.refreshToken.count({ where: { familyId: family, revokedAt: null } });
    expect(live).toBe(0);

    // And the victim's previously-good token no longer rotates.
    await expect(auth.refresh(legit.refreshToken)).rejects.toMatchObject({
      response: { code: 'token_reuse_detected' },
    });
  }, 60_000);

  /**
   * IDEM-1. A dropped response is not a stolen token.
   *
   * The commonest refresh replay is a diner on a bad connection retrying with
   * the only token they still hold, because the rotation response never
   * arrived. Before this, that signed them out mid-booking and logged it as
   * theft.
   */
  describe('a retried rotation is not reuse', () => {
    const CLIENT = { ip: '197.44.0.11', userAgent: 'SAHRA/1.0 (Android 13)' };

    it('the SAME client replaying inside the window keeps its session', async () => {
      const first = await auth.login(PHONE, PASSWORD, CLIENT);
      const family = (
        await prisma.refreshToken.findUniqueOrThrow({
          where: { tokenHash: TokenService.hash(first.refreshToken) },
        })
      ).familyId;

      // Rotation succeeds server-side; the response is lost in transit, so the
      // client never sees `lost` and still holds `first`.
      const lost = await auth.refresh(first.refreshToken, CLIENT);

      // It retries with the only token it has.
      const retried = await auth.refresh(first.refreshToken, CLIENT);

      // A working pair, not a 401.
      expect(retried.refreshToken).toBeTruthy();
      expect(retried.accessToken.split('.')).toHaveLength(3);
      expect(retried.user.id).toBe(first.user.id);

      // The family SURVIVED — this is the whole point.
      const familyOf = await prisma.refreshToken.findUniqueOrThrow({
        where: { tokenHash: TokenService.hash(retried.refreshToken) },
      });
      expect(familyOf.familyId).toBe(family);

      // And the diner can carry on: the token they were handed rotates.
      const next = await auth.refresh(retried.refreshToken, CLIENT);
      expect(next.refreshToken).not.toBe(retried.refreshToken);

      // The unheld replacement was retired rather than left live. Two live
      // tokens from one rotation is the one outcome worse than a 401.
      const orphan = await prisma.refreshToken.findUniqueOrThrow({
        where: { tokenHash: TokenService.hash(lost.refreshToken) },
      });
      expect(orphan.revokedAt).not.toBeNull();
    }, 60_000);

    it('a DIFFERENT client replaying the same token still kills the family', async () => {
      // The security property the grace window must not cost us. Same timing,
      // same unused replacement — only the caller differs.
      const stolen = await auth.login(PHONE, PASSWORD, CLIENT);
      const legit = await auth.refresh(stolen.refreshToken, CLIENT);
      const family = (
        await prisma.refreshToken.findUniqueOrThrow({
          where: { tokenHash: TokenService.hash(legit.refreshToken) },
        })
      ).familyId;

      await expect(
        auth.refresh(stolen.refreshToken, { ip: '102.44.9.9', userAgent: 'curl/8.4' }),
      ).rejects.toMatchObject({ response: { code: 'token_reuse_detected' } });

      const live = await prisma.refreshToken.count({
        where: { familyId: family, revokedAt: null },
      });
      expect(live).toBe(0);
    }, 60_000);

    it('a replay AFTER the replacement has been used is theft, same client or not', async () => {
      // The other half of the discriminator. Once the legitimate client has
      // exercised its new token, a replay of the old one cannot be a lost
      // response — somebody received it.
      const stolen = await auth.login(PHONE, PASSWORD, CLIENT);
      const legit = await auth.refresh(stolen.refreshToken, CLIENT);
      await auth.refresh(legit.refreshToken, CLIENT); // the victim carries on

      await expect(auth.refresh(stolen.refreshToken, CLIENT)).rejects.toMatchObject({
        response: { code: 'token_reuse_detected' },
      });
    }, 60_000);

    it('grace needs positive evidence — an unknown IP does not qualify', async () => {
      // `null === null` must not read as "same client". This is the case the
      // pre-existing theft test exercises, and it is asserted here explicitly
      // so nobody later "simplifies" the check into an equality that treats
      // two unknowns as a match.
      const first = await auth.login(PHONE, PASSWORD); // no ctx recorded
      await auth.refresh(first.refreshToken);

      await expect(auth.refresh(first.refreshToken)).rejects.toMatchObject({
        response: { code: 'token_reuse_detected' },
      });
    }, 60_000);
  });

  it('two concurrent refreshes with the same token: exactly one wins', async () => {
    const pair = await auth.login(PHONE, PASSWORD);

    const results = await Promise.all([
      auth.refresh(pair.refreshToken).then(() => 'ok').catch((e) => e.response?.code ?? 'err'),
      auth.refresh(pair.refreshToken).then(() => 'ok').catch((e) => e.response?.code ?? 'err'),
    ]);

    // The atomic revoke must let exactly one through; the loser is treated as
    // replay, which is the safe direction to be wrong.
    expect(results.filter((r) => r === 'ok')).toHaveLength(1);
    expect(results.filter((r) => r === 'token_reuse_detected')).toHaveLength(1);
  }, 60_000);

  it('rejects an unknown refresh token', async () => {
    await expect(auth.refresh('not-a-real-token')).rejects.toMatchObject({
      response: { code: 'invalid_refresh_token' },
    });
  }, 60_000);

  it('logout revokes only that token; logout-all revokes every device', async () => {
    const deviceA = await auth.login(PHONE, PASSWORD);
    const deviceB = await auth.login(PHONE, PASSWORD);

    await auth.logout(deviceA.refreshToken, false);
    await expect(auth.refresh(deviceA.refreshToken)).rejects.toMatchObject({
      response: { code: 'token_reuse_detected' },
    });

    // Device B is untouched by A's logout.
    const rotatedB = await auth.refresh(deviceB.refreshToken);
    expect(rotatedB.refreshToken).toBeTruthy();

    await auth.logout(rotatedB.refreshToken, true);
    const live = await prisma.refreshToken.count({ where: { userId, revokedAt: null } });
    expect(live).toBe(0);
  }, 60_000);
});

describe('phone verification (doc 06 §2, doc 02 C-1.2)', () => {
  const vPhone = `010${(Date.now() + 7).toString().slice(-8)}`;
  let vUserId: string;
  let vChallengeId: string;

  afterAll(async () => {
    if (vUserId) {
      await prisma.refreshToken.deleteMany({ where: { userId: vUserId } });
      await prisma.userRole.deleteMany({ where: { userId: vUserId } });
      await prisma.user.delete({ where: { id: vUserId } }).catch(() => undefined);
    }
  });

  it('register sends a code and leaves the account pending', async () => {
    const before = otpDelivery.sent.length;
    const r = await auth.register({ phone: vPhone, fullName: 'Verify Me' });
    vUserId = r.userId;
    vChallengeId = r.challengeId;

    expect(otpDelivery.sent.length).toBe(before + 1);
    expect(otpDelivery.sent.at(-1)!.code).toMatch(/^\d{6}$/);

    const u = await prisma.user.findUniqueOrThrow({ where: { id: vUserId } });
    expect(u.status).toBe('pending');
    expect(u.phoneVerifiedAt).toBeNull();
  }, 60_000);

  it('a wrong code does not activate the account', async () => {
    await expect(auth.verifyOtp(vChallengeId, '000000')).rejects.toMatchObject({
      response: { code: 'invalid_otp' },
    });
    const u = await prisma.user.findUniqueOrThrow({ where: { id: vUserId } });
    expect(u.status).toBe('pending');
  }, 60_000);

  it('the right code activates the account and returns a token pair', async () => {
    const { code } = otpDelivery.sent.at(-1)!;
    const outcome = await auth.verifyOtp(vChallengeId, code);

    expect(outcome.status).toBe('signed_in');
    const pair = (outcome as { status: 'signed_in'; tokens: TokenPair }).tokens;
    expect(pair.accessToken.split('.')).toHaveLength(3);
    expect(pair.refreshToken.length).toBeGreaterThan(40);

    const u = await prisma.user.findUniqueOrThrow({ where: { id: vUserId } });
    expect(u.status).toBe('active');
    expect(u.phoneVerifiedAt).not.toBeNull();
  }, 60_000);

  it('the same code cannot be replayed', async () => {
    const { code } = otpDelivery.sent.at(-1)!;
    await expect(auth.verifyOtp(vChallengeId, code)).rejects.toMatchObject({
      response: { code: 'invalid_otp' },
    });
  }, 60_000);
});

describe('normalizePhone — one account per human (doc 02 C-1.2)', () => {
  it('collapses every Egyptian format to one E.164 value', () => {
    const want = '+201000000000';
    expect(normalizePhone('01000000000')).toBe(want);
    expect(normalizePhone('+201000000000')).toBe(want);
    expect(normalizePhone('00201000000000')).toBe(want);
    expect(normalizePhone('201000000000')).toBe(want);
    expect(normalizePhone('+20 100 000 0000')).toBe(want);
    expect(normalizePhone('010-0000-0000')).toBe(want);
  });
});
