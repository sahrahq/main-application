import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import {
  IsString, IsOptional, IsInt, Min, Max, IsArray, IsLatitude, IsLongitude, IsIn, MaxLength,
} from "class-validator";

export class CreateRestaurantDto {
  @ApiProperty({ maxLength: 160 })
  @IsString() @MaxLength(160)
  nameEn!: string;

  @ApiProperty({ maxLength: 160, description: "Arabic name — required, not optional (CLAUDE.md: bilingual by column)" })
  @IsString() @MaxLength(160)
  nameAr!: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional() @IsArray() @IsString({ each: true })
  cuisines?: string[];

  @ApiPropertyOptional({ default: "Cairo" })
  @IsOptional() @IsString() @MaxLength(80)
  city?: string;

  @ApiPropertyOptional({ example: "Zamalek" })
  @IsOptional() @IsString() @MaxLength(80)
  neighborhood?: string;

  @ApiProperty({ example: 30.0622 })
  @IsLatitude()
  lat!: number;

  @ApiProperty({ example: 31.2185 })
  @IsLongitude()
  lng!: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 4 })
  @IsOptional() @IsInt() @Min(1) @Max(4)
  priceBand?: number;

  @ApiPropertyOptional({ default: 30 })
  @IsOptional() @IsInt() @Min(5) @Max(240)
  slotIntervalMin?: number;

  @ApiPropertyOptional({ enum: ["instant", "request"] })
  @IsOptional() @IsIn(["instant", "request"])
  bookingMode?: "instant" | "request";
}

export class UpdateRestaurantDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(160) nameEn?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(160) nameAr?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() descriptionEn?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() descriptionAr?: string;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @IsString({ each: true }) cuisines?: string[];
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(80) neighborhood?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(80) city?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(4) priceBand?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(5) @Max(240) slotIntervalMin?: number;
  @ApiPropertyOptional({ enum: ["instant", "request"] }) @IsOptional() @IsIn(["instant", "request"]) bookingMode?: "instant" | "request";
}

export class ConfirmHoldDto {
  @ApiPropertyOptional({ maxLength: 2000 })
  @IsOptional() @IsString() @MaxLength(2000)
  specialRequests?: string;

  @ApiPropertyOptional({ maxLength: 40 })
  @IsOptional() @IsString() @MaxLength(40)
  occasion?: string;
}