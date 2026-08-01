import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface AuditEntry {
  /** NULL for system-originated actions (expiry sweeps, jobs). */
  actorId?: string | null;
  /** The role the action was authorised under, not every role the actor holds. */
  actorRole?: string | null;
  /** Dotted, past-tense-able: `restaurant.approve`, `reservation.cancel`. */
  action: string;
  entityType: string;
  entityId: string;
  before?: unknown;
  after?: unknown;
  ip?: string | null;
  userAgent?: string | null;
}

/**
 * Append-only audit trail (doc 04 §2, doc 06 §5).
 *
 * `tx` is not optional in spirit: an audit row written in a different
 * transaction from the change it describes can outlive a rollback, or be lost
 * while the change commits. Callers that mutate state should pass their
 * transaction client so the decision and its record land together or not at
 * all.
 */
@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async record(entry: AuditEntry, tx?: Prisma.TransactionClient): Promise<void> {
    const db = tx ?? this.prisma;

    await db.auditLog.create({
      data: {
        actorId: entry.actorId ?? null,
        actorRole: entry.actorRole ?? null,
        action: entry.action,
        entityType: entry.entityType,
        entityId: entry.entityId,
        before: toJson(entry.before),
        after: toJson(entry.after),
        ip: entry.ip ?? null,
        userAgent: entry.userAgent ?? null,
      },
    });
  }

  /** Read an entity's history, newest first. Backed by idx_audit_entity. */
  async historyFor(entityType: string, entityId: string, limit = 50) {
    return this.prisma.auditLog.findMany({
      where: { entityType, entityId },
      orderBy: { id: 'desc' },
      take: Math.min(limit, 200),
    });
  }
}

/** Undefined must become SQL NULL, not the JSON string "undefined". */
function toJson(value: unknown): Prisma.InputJsonValue | typeof Prisma.JsonNull {
  if (value === undefined || value === null) return Prisma.JsonNull;
  return value as Prisma.InputJsonValue;
}
