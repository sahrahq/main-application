import { Injectable, ForbiddenException, NotFoundException, ConflictException, Logger } from '@nestjs/common';
import { RestaurantStatus } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';

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

  constructor(private readonly prisma: PrismaService) {}

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
    await this.assertPending(input.restaurantId);

    const out = await this.prisma.restaurant.update({
      where: { id: input.restaurantId },
      data: { status: RestaurantStatus.active },
      select: SELECT,
    });

    // TODO(audit): doc 06 §5 requires every admin call to be audit-logged.
    // The audit_logs table (doc 04 §2) is not in the P0 schema yet, so this
    // is an application log only — NOT the append-only record the doc means.
    this.logger.log(
      `admin.restaurant.approve restaurant=${input.restaurantId} actor=${input.actorId ?? 'unknown'}`,
    );
    return out;
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
    await this.assertPending(input.restaurantId);

    const out = await this.prisma.restaurant.update({
      where: { id: input.restaurantId },
      data: { status: RestaurantStatus.draft },
      select: SELECT,
    });

    // TODO(audit): as above — the reason belongs in audit_logs, not a log line.
    this.logger.log(
      `admin.restaurant.reject restaurant=${input.restaurantId} ` +
        `actor=${input.actorId ?? 'unknown'} reason=${JSON.stringify(input.reason ?? '')}`,
    );
    return out;
  }

  private async assertPending(restaurantId: string): Promise<void> {
    const r = await this.prisma.restaurant.findFirst({
      where: { id: restaurantId, deletedAt: null },
      select: { status: true },
    });
    if (!r) {
      throw new NotFoundException({
        code: 'restaurant_not_found',
        message: 'Restaurant not found.',
        message_ar: 'المطعم غير موجود.',
      });
    }
    if (r.status !== RestaurantStatus.pending_review) {
      throw new ConflictException({
        code: 'invalid_status_transition',
        message: `Only a restaurant awaiting review can be decided (this one is ${r.status}).`,
        message_ar: 'لا يمكن اتخاذ قرار إلا لمطعم في انتظار المراجعة.',
      });
    }
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
