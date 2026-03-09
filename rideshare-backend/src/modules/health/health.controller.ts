import { Controller, Get } from '@nestjs/common';
import {
  HealthCheck,
  HealthCheckService,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';
import { Public } from '../../common/decorators/public.decorator';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  @Public()
  check() {
    return this.health.check([
      () => ({
        app: {
          status: 'up',
        },
      }),
    ]);
  }

  @Get('db')
  @HealthCheck()
  @Public()
  checkDb() {
    return this.health.check([() => this.db.pingCheck('postgres')]);
  }
}
