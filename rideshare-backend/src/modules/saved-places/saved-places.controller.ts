import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SavedPlacesService } from './saved-places.service';
import { UpsertSavedPlaceDto } from './dto/upsert-saved-place.dto';

@ApiTags('saved-places')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('me/saved-places')
export class SavedPlacesController {
  constructor(private readonly service: SavedPlacesService) {}

  @Get()
  @ApiOperation({ summary: 'Your Home, Work and named places' })
  list(@CurrentUser('id') userId: string) {
    return this.service.list(userId);
  }

  @Put()
  @ApiOperation({
    summary: 'Save a place',
    description:
      'Home and Work are replaced in place; a custom place is matched by its label.',
  })
  upsert(@CurrentUser('id') userId: string, @Body() dto: UpsertSavedPlaceDto) {
    return this.service.upsert(userId, dto);
  }

  @Delete(':id')
  @HttpCode(204)
  @ApiOperation({ summary: 'Delete a saved place' })
  async remove(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.service.remove(userId, id);
  }
}
