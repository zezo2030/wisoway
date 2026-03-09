import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { RatingsService } from './ratings.service';
import { CreateRatingDto } from './dto/create-rating.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PaginationDto } from '../../common/dto/pagination.dto';

@ApiTags('ratings')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('ratings')
export class RatingsController {
  constructor(private readonly ratingsService: RatingsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a rating for a user after trip completion' })
  @ApiResponse({ status: 201, description: 'Rating created successfully' })
  @ApiResponse({
    status: 400,
    description:
      'Bad request - trip not completed, already rated, or self-rating',
  })
  @ApiResponse({
    status: 403,
    description: 'Forbidden - not a participant of this trip',
  })
  @ApiResponse({ status: 404, description: 'Trip or user not found' })
  async create(@Body() createRatingDto: CreateRatingDto, @Req() req: any) {
    const userRole = req.user.role || 'passenger';
    return this.ratingsService.create(createRatingDto, req.user.sub, userRole);
  }

  @Get('user/:userId')
  @ApiOperation({ summary: 'Get all ratings received by a user' })
  @ApiParam({ name: 'userId', description: 'User ID' })
  @ApiQuery({ name: 'page', required: false, type: Number, default: 1 })
  @ApiQuery({ name: 'limit', required: false, type: Number, default: 20 })
  @ApiResponse({ status: 200, description: 'Returns paginated ratings' })
  async findByUser(
    @Param('userId') userId: string,
    @Query() pagination: PaginationDto,
  ) {
    return this.ratingsService.findByUser(userId, {
      page: pagination.page || 1,
      limit: pagination.limit || 20,
    });
  }

  @Get('trip/:tripId')
  @ApiOperation({ summary: 'Get all ratings for a trip' })
  @ApiParam({ name: 'tripId', description: 'Trip ID' })
  @ApiQuery({ name: 'page', required: false, type: Number, default: 1 })
  @ApiQuery({ name: 'limit', required: false, type: Number, default: 20 })
  @ApiResponse({ status: 200, description: 'Returns paginated ratings' })
  async findByTrip(
    @Param('tripId') tripId: string,
    @Query() pagination: PaginationDto,
  ) {
    return this.ratingsService.findByTrip(tripId, {
      page: pagination.page || 1,
      limit: pagination.limit || 20,
    });
  }

  @Get('my')
  @ApiOperation({ summary: 'Get all ratings given by the current user' })
  @ApiQuery({ name: 'page', required: false, type: Number, default: 1 })
  @ApiQuery({ name: 'limit', required: false, type: Number, default: 20 })
  @ApiResponse({ status: 200, description: 'Returns paginated ratings' })
  async findByRater(@Req() req: any, @Query() pagination: PaginationDto) {
    return this.ratingsService.findByRater(req.user.sub, {
      page: pagination.page || 1,
      limit: pagination.limit || 20,
    });
  }
}
