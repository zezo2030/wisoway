import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  SavedPlaceEntity,
  SavedPlaceKind,
} from '../../database/entities/saved-place.entity';
import { UpsertSavedPlaceDto } from './dto/upsert-saved-place.dto';

/** Named places a user may keep besides Home and Work. */
export const MAX_CUSTOM_PLACES = 20;

@Injectable()
export class SavedPlacesService {
  constructor(
    @InjectRepository(SavedPlaceEntity)
    private readonly repo: Repository<SavedPlaceEntity>,
  ) {}

  /** Home, then Work, then named places newest first. */
  async list(userId: string): Promise<SavedPlaceEntity[]> {
    const places = await this.repo.find({
      where: { userId },
      order: { updatedAt: 'DESC' },
    });
    const rank = (p: SavedPlaceEntity) =>
      p.kind === SavedPlaceKind.HOME
        ? 0
        : p.kind === SavedPlaceKind.WORK
          ? 1
          : 2;
    return places.sort((a, b) => rank(a) - rank(b));
  }

  /**
   * Create or move a place. Home and Work are singletons (stored with an
   * empty label); a custom place is matched by its label.
   */
  async upsert(
    userId: string,
    dto: UpsertSavedPlaceDto,
  ): Promise<SavedPlaceEntity> {
    const label =
      dto.kind === SavedPlaceKind.CUSTOM ? (dto.label ?? '').trim() : '';
    if (dto.kind === SavedPlaceKind.CUSTOM && !label) {
      throw new BadRequestException('A custom place needs a label');
    }

    const existing = await this.repo.findOne({
      where: { userId, kind: dto.kind, label },
    });
    if (!existing && dto.kind === SavedPlaceKind.CUSTOM) {
      const count = await this.repo.count({
        where: { userId, kind: SavedPlaceKind.CUSTOM },
      });
      if (count >= MAX_CUSTOM_PLACES) {
        throw new BadRequestException(
          `You can save up to ${MAX_CUSTOM_PLACES} places`,
        );
      }
    }

    // ON CONFLICT on the unique index, so two devices saving Home at once
    // end with one row rather than a constraint error.
    await this.repo.upsert(
      {
        userId,
        kind: dto.kind,
        label,
        name: dto.name.trim(),
        secondaryText: dto.secondaryText?.trim() ?? '',
        latitude: dto.latitude,
        longitude: dto.longitude,
      },
      { conflictPaths: ['userId', 'kind', 'label'] },
    );
    return this.repo.findOneOrFail({
      where: { userId, kind: dto.kind, label },
    });
  }

  async remove(userId: string, id: string): Promise<void> {
    const result = await this.repo.delete({ id, userId });
    if (!result.affected) throw new NotFoundException('Saved place not found');
  }
}
