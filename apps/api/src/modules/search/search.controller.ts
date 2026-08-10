import { Controller, Get, Query, BadRequestException } from '@nestjs/common';
import {
  ApiOkResponse, ApiOperation, ApiQuery, ApiTags,
} from '@nestjs/swagger';
import { RestaurantSearchService, SEARCH_PAGE_SIZE } from './restaurant-search.service';
import { SearchResponse } from '../../shared/api/responses.dto';

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** doc 06 §3 — public. Browsing must not require an account. */
@ApiTags('search')
@Controller('restaurants')
export class SearchController {
  constructor(private readonly search: RestaurantSearchService) {}

  @Get('search')
  @ApiOkResponse({ type: SearchResponse })
  @ApiOperation({ summary: 'Discovery search — text + facets, availability post-filtered' })
  @ApiQuery({ name: 'q', required: false, example: 'sequoia' })
  @ApiQuery({ name: 'cuisine', required: false, example: 'egyptian' })
  @ApiQuery({ name: 'neighborhood', required: false, example: 'Zamalek' })
  @ApiQuery({ name: 'price_band', required: false, example: 3 })
  @ApiQuery({ name: 'rating_min', required: false, example: 4 })
  @ApiQuery({ name: 'lat', required: false, example: 30.0622 })
  @ApiQuery({ name: 'lng', required: false, example: 31.2185 })
  @ApiQuery({ name: 'radius_km', required: false, example: 5 })
  @ApiQuery({ name: 'available_at', required: false, description: 'YYYY-MM-DD; needs party_size' })
  @ApiQuery({ name: 'party_size', required: false, example: 2 })
  @ApiQuery({ name: 'amenities', required: false, description: 'comma-separated' })
  @ApiQuery({ name: 'sort', required: false, enum: ['relevance', 'rating', 'distance'] })
  @ApiQuery({ name: 'cursor', required: false })
  @ApiQuery({ name: 'limit', required: false, example: SEARCH_PAGE_SIZE })
  async find(
    @Query('q') q?: string,
    @Query('cuisine') cuisine?: string,
    @Query('neighborhood') neighborhood?: string,
    @Query('price_band') priceBand?: string,
    @Query('rating_min') ratingMin?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('radius_km') radiusKm?: string,
    @Query('available_at') availableAt?: string,
    @Query('party_size') partySize?: string,
    @Query('amenities') amenities?: string,
    @Query('sort') sort?: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ): Promise<SearchResponse> {
    const date = availableAt ? this.parseDate(availableAt) : undefined;
    const party = partySize === undefined ? undefined : this.int(partySize, 'party_size', 1, 50);

    // Half a filter is worse than none: `available_at` with no party size would
    // silently return unfiltered results that LOOK availability-checked.
    if ((date && party === undefined) || (party !== undefined && !date)) {
      throw new BadRequestException({
        code: 'invalid_availability_filter',
        message: 'available_at and party_size must be given together.',
        message_ar: 'لازم تبعت التاريخ وعدد الأفراد مع بعض.',
      });
    }

    return this.search.search({
      q,
      cuisine,
      neighborhood,
      priceBand: priceBand === undefined ? undefined : this.int(priceBand, 'price_band', 1, 4),
      ratingMin: ratingMin === undefined ? undefined : this.num(ratingMin, 'rating_min', 0, 5),
      amenities: amenities ? amenities.split(',').map((a) => a.trim()).filter(Boolean) : undefined,
      lat: lat === undefined ? undefined : this.num(lat, 'lat', -90, 90),
      lng: lng === undefined ? undefined : this.num(lng, 'lng', -180, 180),
      radiusKm: radiusKm === undefined ? undefined : this.num(radiusKm, 'radius_km', 0, 500),
      sort: this.parseSort(sort),
      date,
      partySize: party,
      cursor,
      limit: limit === undefined ? undefined : this.int(limit, 'limit', 1, SEARCH_PAGE_SIZE),
    });
  }

  /** Accepts a plain date or the date half of an ISO instant. */
  private parseDate(value: string): string {
    const date = value.length > 10 ? value.slice(0, 10) : value;
    if (!ISO_DATE.test(date) || Number.isNaN(Date.parse(`${date}T00:00:00Z`))) {
      throw new BadRequestException({
        code: 'invalid_date',
        message: 'available_at must be YYYY-MM-DD.',
        message_ar: 'التاريخ لازم يكون بصيغة YYYY-MM-DD.',
      });
    }
    return date;
  }

  private parseSort(value?: string): 'relevance' | 'rating' | 'distance' | undefined {
    if (value === undefined) return undefined;
    if (value === 'relevance' || value === 'rating' || value === 'distance') return value;
    throw new BadRequestException({
      code: 'invalid_sort',
      message: 'sort must be one of relevance, rating, distance.',
      message_ar: 'الترتيب لازم يكون relevance أو rating أو distance.',
    });
  }

  private int(raw: string, field: string, min: number, max: number): number {
    const n = Number(raw);
    if (!Number.isInteger(n) || n < min || n > max) throw this.bad(field, min, max);
    return n;
  }

  private num(raw: string, field: string, min: number, max: number): number {
    const n = Number(raw);
    if (!Number.isFinite(n) || n < min || n > max) throw this.bad(field, min, max);
    return n;
  }

  private bad(field: string, min: number, max: number): BadRequestException {
    return new BadRequestException({
      code: 'invalid_query_param',
      message: `${field} must be a number between ${min} and ${max}.`,
      message_ar: `القيمة ${field} لازم تكون رقم بين ${min} و ${max}.`,
      details: [{ field, issue: 'out_of_range' }],
    });
  }
}
