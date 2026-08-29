import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserEntity } from '../../../database/entities/user.entity';
import { seedAdminUser } from './admin.seed';

/**
 * Runs the admin seed on boot.
 *
 * It lives in its own provider rather than on AdminService because that service
 * is not registered in AdminModule's providers, so Nest never instantiates it
 * and its `onModuleInit` never fired — which is why an emptied users table left
 * the dashboard permanently locked out.
 */
@Injectable()
export class AdminSeedService implements OnModuleInit {
  private readonly logger = new Logger(AdminSeedService.name);

  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
  ) {}

  async onModuleInit(): Promise<void> {
    try {
      const result = await seedAdminUser(this.userRepo);
      this.logger.log(result.message);
    } catch (error) {
      // Boot must not fail over the seed: the rest of the API is still useful,
      // and the operator needs the log to know the dashboard has no way in.
      this.logger.error(
        `Failed to seed admin user: ${(error as Error).message}`,
        (error as Error).stack,
      );
    }
  }
}
