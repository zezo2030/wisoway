import { Processor, Process, OnQueueFailed } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { NotificationsService } from '../notifications.service';

@Processor('new-trip-fanout')
export class NewTripFanoutProcessor {
  private readonly logger = new Logger(NewTripFanoutProcessor.name);

  constructor(private readonly notificationsService: NotificationsService) {}

  @Process('fanout')
  async handleFanout(job: Job<{ tripId: string }>): Promise<void> {
    this.logger.log(`Processing city fan-out for trip ${job.data.tripId}`);
    await this.notificationsService.processCityFanout(job.data.tripId);
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `City fan-out job ${job.id} failed: ${error.message}`,
      error.stack,
    );
  }
}
