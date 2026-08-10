import { PrismaClient } from '@prisma/client';

/**
 * A diner to own the app bookings a fixture creates.
 *
 * WHY EVERY SUITE THAT BOOKS NOW NEEDS ONE. C-1.6 makes an account a
 * requirement for booking, and the DB constraint `app_booking_has_diner`
 * enforces it beneath the service — `source = 'app'` implies `user_id IS NOT
 * NULL`. Fixtures that created reservations with a null user were reproducing,
 * in miniature, exactly the bug that shipped: the column was nullable, so
 * nothing objected, so nobody noticed for weeks.
 *
 * Walk-in and phone bookings (R-3.2) stay legitimately anonymous and do not
 * need this.
 *
 * Reused across a suite rather than created per test: these are read-only
 * subjects, and one row is easier to clean up than twenty.
 */
export async function createTestDiner(
  prisma: PrismaClient,
  label = 'Test Diner',
): Promise<string> {
  const user = await prisma.user.create({
    data: {
      // Random tail, because suites run against a shared database and a fixed
      // number would collide with a parallel run.
      phone: `+2017${Math.floor(Math.random() * 1e8).toString().padStart(8, '0')}`,
      fullName: label,
      status: 'active',
    },
    select: { id: true },
  });
  return user.id;
}

/** Remove a diner created by [createTestDiner], with their dependants. */
export async function removeTestDiner(prisma: PrismaClient, userId: string | undefined): Promise<void> {
  if (!userId) return;
  await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${userId}::uuid`;
  await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${userId}::uuid`;
  await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${userId}::uuid`;
}
