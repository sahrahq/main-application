import { Controller, Get, Param } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { MenusService } from './menus.service';
import { MenuResponse } from '../../shared/api/responses.dto';

/**
 * doc 06 §3 — `GET /restaurants/:id/menus`, "Menus → categories → items".
 *
 * PUBLIC. Guest browsing runs all the way to the booking button (C-1.6), and a
 * menu behind a sign-in wall is the single most effective way to lose somebody
 * deciding where to eat.
 *
 * Registered BEFORE `PublicRestaurantsModule`, whose `GET /restaurants/:idOrSlug`
 * is a one-segment wildcard on the same base path. Two segments do not collide
 * with one in Express, so this is belt and braces rather than a fix — but the
 * ordering rule in `app.module.ts` exists because that reasoning is easy to get
 * wrong, and `menus-reviews.e2e-spec.ts` asserts the route actually resolves rather
 * than trusting this comment.
 */
@ApiTags('menus')
@Controller('restaurants')
export class MenusController {
  constructor(private readonly menus: MenusService) {}

  @Get(':idOrSlug/menus')
  @ApiOkResponse({ type: [MenuResponse] })
  @ApiOperation({ summary: "A venue's menus, with categories and available items" })
  @ApiResponse({
    status: 404,
    description: 'restaurant_not_found — also for a venue that is not active',
  })
  listMenus(@Param('idOrSlug') idOrSlug: string): Promise<MenuResponse[]> {
    return this.menus.forRestaurant(idOrSlug) as Promise<MenuResponse[]>;
  }
}
