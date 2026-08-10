import { Body, Controller, Get, Param, Post, Req, UseGuards, ParseUUIDPipe } from "@nestjs/common";
import type { Request } from "express";
import {
  ApiBearerAuth, ApiOkResponse, ApiOperation, ApiResponse, ApiTags,
} from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from "class-validator";
import { ApiPropertyOptional } from "@nestjs/swagger";
import { AdminRestaurantsService } from "./admin-restaurants.service";
import { JwtAuthGuard } from "../../shared/auth/jwt-auth.guard";
import { RolesGuard } from "../../shared/auth/roles.guard";
import { Roles } from "../../shared/auth/roles.decorator";
import { CurrentUser } from "../../shared/auth/current-user.decorator";
import type { AuthedUser } from "../../shared/auth/jwt.strategy";
import { AdminRestaurantResponse } from '../../shared/api/responses.dto';

export class RejectRestaurantDto {
  @ApiPropertyOptional({ maxLength: 500, description: "Shown to the owner so they can fix it" })
  @IsOptional() @IsString() @MaxLength(500)
  reason?: string;
}

@ApiTags("admin:restaurants")
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller("admin/restaurants")
export class AdminRestaurantsController {
  constructor(private readonly admin: AdminRestaurantsService) {}

  @Get()
  @ApiOkResponse({ type: [AdminRestaurantResponse] })
  @Roles("admin", "support", "moderator")
  @ApiOperation({ summary: "The pending_review queue, oldest first" })
  list(@CurrentUser() user: AuthedUser): Promise<AdminRestaurantResponse[]> {
    return this.admin.listPendingReview({ actorId: user.id, actorRoles: user.roles });
  }

  @Post(":id/approve")
  @ApiOkResponse({ type: AdminRestaurantResponse })
  @Roles("admin")
  @ApiOperation({ summary: "pending_review to active" })
  @ApiResponse({ status: 409, description: "invalid_status_transition" })
  approve(@CurrentUser() user: AuthedUser, @Param("id", ParseUUIDPipe) id: string, @Req() req: Request): Promise<AdminRestaurantResponse> {
    return this.admin.approve({
      actorId: user.id, actorRoles: user.roles, restaurantId: id,
      ip: req.ip ?? null, userAgent: req.get("user-agent") ?? null,
    });
  }

  @Post(":id/reject")
  @ApiOkResponse({ type: AdminRestaurantResponse })
  @Roles("admin")
  @ApiOperation({ summary: "pending_review back to draft, with a reason" })
  reject(
    @CurrentUser() user: AuthedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: RejectRestaurantDto,
    @Req() req: Request,
  ): Promise<AdminRestaurantResponse> {
    return this.admin.reject({
      actorId: user.id,
      actorRoles: user.roles,
      restaurantId: id,
      reason: dto.reason,
      ip: req.ip ?? null,
      userAgent: req.get("user-agent") ?? null,
    });
  }
}