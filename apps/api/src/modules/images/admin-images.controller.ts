import {
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOkResponse,
  ApiOperation,
  ApiQuery,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { RolesGuard } from '../../shared/auth/roles.guard';
import { Roles } from '../../shared/auth/roles.decorator';
import { ImagesService } from './images.service';
import { ImageResponse } from '../../shared/api/responses.dto';
import { ACCEPTED_MIME, MAX_UPLOAD_BYTES } from './image.ports';
import { readUpload } from './read-upload';

/**
 * VENUE PHOTOS GO IN THROUGH HERE, AND ONLY US CAN USE IT.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THIS IS AN OPERATIONS COST, NOT AN ARCHITECTURE
 * ─────────────────────────────────────────────────────────────────────────
 *
 * R-2.2 — "photo upload with ordering, cover photo" — is an OWNER-facing P0,
 * and `management_app` does not exist. So until it does, nobody at a
 * restaurant can add a photo: one of us collects them, checks them and uploads
 * them through this endpoint. At five pilot venues that is an afternoon; at
 * fifty it is somebody's job every week.
 *
 * Recorded in doc 10 §3b as a cost that scales linearly with venues, and named
 * there as the first thing that will make the management app urgent ahead of
 * schedule. This docstring exists so the next person to read the code finds
 * the same sentence.
 *
 * When R-2.2 ships, the owner-facing route is a second controller with an
 * ownership check — NOT this one with its role list widened. An admin route
 * that quietly starts accepting owners is how "admin only" stops being true.
 */
@ApiTags('admin:images')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('admin/restaurants/:restaurantId/images')
export class AdminImagesController {
  constructor(private readonly images: ImagesService) {}

  @Get()
  @Roles('admin', 'support', 'moderator')
  @ApiOkResponse({ type: [ImageResponse] })
  @ApiOperation({ summary: "A venue's photos, in order" })
  listImages(
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
  ): Promise<ImageResponse[]> {
    return this.images.forRestaurant(restaurantId) as Promise<ImageResponse[]>;
  }

  /**
   * Upload one photo.
   *
   * `multipart/form-data`, read WITHOUT a body-parser dependency — see
   * `read-upload.ts` for why `multer` is not here.
   *
   * NO `Idempotency-Key`. A replay uploads the photo twice, which produces two
   * gallery rows an admin can see and delete — visible, cheap, and reversible.
   * Weigh that against the alternative: a key column on `images` and a lookup
   * on every upload, to protect a manual operation performed by a person
   * watching the response. Pinned in the census with this reasoning.
   */
  @Post()
  @Roles('admin', 'support')
  @HttpCode(201)
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
      required: ['file'],
    },
  })
  @ApiQuery({
    name: 'cover',
    required: false,
    description: 'Make this the hero. The first photo of a venue becomes one anyway.',
  })
  @ApiOkResponse({ type: ImageResponse })
  @ApiResponse({
    status: 400,
    description: `invalid_image | image_too_large (>${MAX_UPLOAD_BYTES} bytes) | ` +
      `unsupported_image_type (accepted: ${ACCEPTED_MIME.join(', ')})`,
  })
  @ApiResponse({ status: 404, description: 'restaurant_not_found' })
  @ApiResponse({ status: 503, description: 'storage_unavailable' })
  async upload(
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Req() req: Request,
    @Query('cover') cover?: string,
  ): Promise<ImageResponse> {
    const file = await readUpload(req);

    return this.images.addRestaurantImage({
      restaurantId,
      body: file.body,
      mimeType: file.mimeType,
      cover: cover === 'true',
    }) as Promise<ImageResponse>;
  }

  @Delete(':imageId')
  @Roles('admin', 'support')
  @HttpCode(204)
  @ApiOperation({ summary: 'Remove a photo and every rendition of it' })
  // DECLARED, because `@HttpCode(204)` alone does not reach the spec — and the
  // client generator refuses an operation with no 2xx rather than guessing one.
  @ApiResponse({ status: 204, description: 'Deleted, with every rendition' })
  @ApiResponse({ status: 404, description: 'image_not_found' })
  remove(
    @Param('restaurantId', ParseUUIDPipe) _restaurantId: string,
    @Param('imageId', ParseUUIDPipe) imageId: string,
  ): Promise<void> {
    return this.images.remove(imageId);
  }
}
