import { Controller, Get, Param, Query, ParseUUIDPipe, BadRequestException } from "@nestjs/common";
import {
  ApiOkResponse, ApiOperation, ApiQuery, ApiTags,
} from '@nestjs/swagger';
import { AvailabilityService } from "./availability.service";
import { AvailabilityResponse } from '../../shared/api/responses.dto';

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

@ApiTags("availability")
@Controller("restaurants")
export class AvailabilityController {
  constructor(private readonly availability: AvailabilityService) {}

  /** doc 06 §3 — public; browsing availability must not require an account. */
  @Get(":id/availability")
  @ApiOkResponse({ type: AvailabilityResponse })
  @ApiOperation({ summary: "Bookable slots for a date and party size" })
  @ApiQuery({ name: "date", example: "2026-08-02" })
  @ApiQuery({ name: "party_size", example: 2 })
  getSlots(
    @Param("id", ParseUUIDPipe) id: string,
    @Query("date") date: string,
    @Query("party_size") partySize: string,
  ): Promise<AvailabilityResponse> {
    if (!ISO_DATE.test(date ?? "")) {
      throw new BadRequestException({
        code: "invalid_date",
        message: "date must be YYYY-MM-DD.",
        message_ar: "التاريخ لازم يكون بصيغة YYYY-MM-DD.",
      });
    }
    const n = Number(partySize);
    if (!Number.isInteger(n) || n < 1 || n > 50) {
      throw new BadRequestException({
        code: "invalid_party_size",
        message: "party_size must be an integer between 1 and 50.",
        message_ar: "عدد الأفراد لازم يكون رقم بين 1 و 50.",
      });
    }
    return this.availability.getSlots({ restaurantId: id, date, partySize: n });
  }
}