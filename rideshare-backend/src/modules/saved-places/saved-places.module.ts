import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SavedPlaceEntity } from '../../database/entities/saved-place.entity';
import { SavedPlacesController } from './saved-places.controller';
import { SavedPlacesService } from './saved-places.service';

@Module({
  imports: [TypeOrmModule.forFeature([SavedPlaceEntity])],
  controllers: [SavedPlacesController],
  providers: [SavedPlacesService],
})
export class SavedPlacesModule {}
