import { Injectable, ForbiddenException, NotFoundException, ConflictException, Logger } from '@nestjs/common';
import { RestaurantStatus } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { AuditService } from '../../shared/audit/audit.service';

/**
 * doc 06 §5 — `/admin/...`, roles admin/support/moderator.
 *
 * Read and write are deliberately NOT the same privilege. A moderator handling
 * the review queue should be able to see what is waiting without being able to
 * put a venue live on the platform; approval is the action with commercial and
 * legal consequence, so it is narrowed to `admin`.
 */
const CAN_READ_QUEUE = ['admin', 'support', 'moderator'];
const CAN_DECIDE = ['admin'];

export interface AdminActor {
  actorId?: string;
  actorRoles: string[];
  /** Recorded on the audit row — where the decision came from. */
  ip?: string | null;
  userAgent?: string | null;
}

export interface AdminRestaurantRow {
  id: string;
  slug: string;
  status: RestaurantStatus;
  nameEn: string;
  nameAr: string;
  city: string;
  neighborhood: string | null;
}

const SELECT = {
  id: true, slug: true, status: true, nameEn: true, nameAr: true,
  city: true, neighborhood: true,
};

@Injectable()
export class AdminRestaurantsService {
  private readonly logger = new Logger(AdminRestaurantsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async listPendingReview(actor: AdminActor): Promise<AdminRestaurantRow[]> {
    this.assertRole(actor.actorRoles, CAN_READ_QUEUE);
    return this.prisma.restaurant.findMany({
      where: { status: RestaurantStatus.pending_review, deletedAt: null },
      select: SELECT,
      orderBy: { updatedAt: 'asc' }, // oldest waiting first
    });
  }

  /** pending_review → active. The moment a venue can take real bookings. */
  async approve(input: AdminActor & { restaurantId: string }): Promise<AdminRestaurantRow> {
    this.assertRole(input.actorRoles, CAN_DECIDE);
    return this.decide(input, RestaurantStatus.active, 'restaurant.approve');
  }

  /**
   * pending_review → draft, with a reason.
   *
   * Back to draft rather than a terminal `rejected`: the status enum in doc 04
   * has no such value, and commercially the goal is for the owner to fix the
   * listing and resubmit, not to be locked out.
   */
  async reject(
    input: AdminActor & { restaurantId: string; reason?: string },
  ): Promise<AdminRestaurantRow> {
    this.assertRole(input.actorRoles, CAN_DECIDE);
    return this.decide(input, RestaurantStatus.draft, 'restaurant.reject', input.reason);
  }

  /**
   * The state change and its audit row, in ONE transaction.
   *
   * doc 06 §5 requires every admin call to be audit-logged. Writing the audit
   * row outside the transaction would allow an approval to commit while its
   * record was lost — the exact scenario that makes a decision impossible to
   * reconstruct later. Here neither can happen without the other.
   */
  private async decide(
    input: AdminActor & { restaurantId: string },
    next: RestaurantStatus,
    action: string,
    reason?: string,
  ): Promise<AdminRestaurantRow> {
    return this.prisma.$transaction(async (tx) => {
      const current = await tx.restaurant.findFirst({
        where: { id: input.restaurantId, deletedAt: null },
        select: { status: true },
      });
      if (!current) {
        throw new NotFoundException({
          code: 'restaurant_not_found',
          message: 'Restaurant not found.',
          message_ar: 'المطعم غير موجود.',
        });
      }
      if (current.status !== RestaurantStatus.pending_review) {
        throw new ConflictException({
          code: 'invalid_status_transition',
          message: `Only a restaurant awaiting review can be decided (this one is ${current.status}).`,
          message_ar: 'لا يمكن اتخاذ قرار إلا لمطعم في انتظار المراجعة.',
        });
      }

      const out = await tx.restaurant.update({
        where: { id: input.restaurantId },
        data: { status: next },
        select: SELECT,
      });

      await this.audit.record(
        {
          actorId: input.actorId ?? null,
          // The role the decision was made UNDER, not every role held.
          actorRole: this.decidingRole(input.actorRoles),
          action,
          entityType: 'restaurant',
          entityId: input.restaurantId,
          before: { status: current.status },
          after: reason === undefined ? { status: next } : { status: next, reason },
          ip: input.ip ?? null,
          userAgent: input.userAgent ?? null,
        },
        tx,
      );

      return out;
    });
  }

  /** Which of the caller's roles actually authorised this. */
  private decidingRole(actorRoles: string[]): string | null {
    return actorRoles?.find((r) => CAN_DECIDE.includes(r)) ?? null;
  }

  private assertRole(actorRoles: string[], allowed: string[]): void {
    if (!actorRoles?.some((r) => allowed.includes(r))) {
      throw new ForbiddenException({
        code: 'forbidden_role',
        message: 'You do not have permission to do that.',
        message_ar: 'ليس لديك صلاحية للقيام بذلك.',
      });
    }
  }
}
