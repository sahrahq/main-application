import { Controller, Get, HttpStatus, Inject, Res } from '@nestjs/common';
import type { Response } from 'express';
import { ApiOkResponse, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { PUSH_READINESS, type PushReadiness } from '../notifications/push-readiness';
import { HealthResponse } from '../../shared/api/responses.dto';

/**
 * `/health` — and it is not a liveness probe.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * IT ANSWERS 503 WHEN A PLATFORM CANNOT BE REACHED. THAT IS THE POINT.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `main.ts` has excluded `health` from the `/v1` prefix since the first commit,
 * and no controller ever existed behind it — `GET /health` has been answering
 * 404 for weeks. It gets built now because Stage 2 needs somewhere for a
 * partial configuration to be VISIBLE.
 *
 * The state this exists for: Firebase project `sahra-4881d` has an Android app
 * and no APNs key. Android push works. FCM accepts an iOS send and answers with
 * a message id; the iPhone never rings. Nothing about that is visible from a
 * log, a metric, a manual test on an Android handset, or a green test suite.
 *
 * So it is 503, not a field in a 200 body. A degraded state reported inside a
 * successful response is a degraded state nobody notices — every uptime check
 * ever written looks at the status code.
 *
 * ── WHY THIS DOES NOT BREAK A DEPLOYMENT ────────────────────────────────
 *
 * Because it must not be wired to a container liveness probe, and doc 10's
 * pipeline does not do that — it runs a **synthetic booking probe**. A load
 * balancer that killed this process for having no APNs key would be trading a
 * missing iPhone notification for a total outage.
 *
 * `status` is the machine-readable field: `ok` or `degraded`. The 503 is for
 * the human and the dashboard; `reasons` is for whoever has to fix it.
 */
@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(@Inject(PUSH_READINESS) private readonly push: PushReadiness) {}

  @Get()
  @ApiOperation({ summary: 'Service health, including which push platforms are reachable' })
  @ApiOkResponse({ type: HealthResponse })
  @ApiResponse({
    status: 503,
    description:
      'Degraded — at least one push platform a diner can register for cannot ' +
      'be reached. The process is healthy; the capability is not.',
    type: HealthResponse,
  })
  check(
    // `passthrough`, so the SAME body shape is returned either way and only the
    // status differs. Throwing a `ServiceUnavailableException` instead would
    // route through the doc 06 §1 error filter and reshape the body into an
    // error envelope — a health check whose payload changes shape when it is
    // unhealthy is a health check nothing can parse.
    @Res({ passthrough: true }) res: Response,
  ): HealthResponse {
    const reasons = this.push.platforms
      // `web` is out of scope rather than broken (doc 02), so it never degrades
      // anything. Excluded here rather than removed from the list, because the
      // list is also what `/health` reports and "web: not in scope" is a useful
      // thing to be able to read.
      .filter((p) => !p.deliverable && p.platform !== 'web')
      .map((p) => `${p.platform}: ${p.reason}`);

    res.status(reasons.length === 0 ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE);

    return {
      status: reasons.length === 0 ? 'ok' : 'degraded',
      push: {
        configured: this.push.configured,
        project_id: this.push.projectId,
        deliverable: this.push.platforms.filter((p) => p.deliverable).map((p) => p.platform),
        unreachable: this.push.unreachable,
      },
      reasons,
    };
  }
}
