import { OnQueueFailed, Process, Processor } from '@nestjs/bull';
import { Logger } from '@nestjs/common';
import type { Job } from 'bull';
import {
  RIDE_FARE_CLIQ_QUEUE,
  RIDE_FARE_POLL_JOB,
  RidePaymentsService,
  type RideFarePollJob,
} from './ride-payments.service';

/** Watches an outstanding CliQ ride-fare request until the bank answers. */
@Processor(RIDE_FARE_CLIQ_QUEUE)
export class RideFarePollProcessor {
  private readonly logger = new Logger(RideFarePollProcessor.name);

  constructor(private readonly ridePayments: RidePaymentsService) {}

  @Process(RIDE_FARE_POLL_JOB)
  async handle(job: Job<RideFarePollJob>): Promise<void> {
    await this.ridePayments.pollCliq(job.data);
  }

  @OnQueueFailed()
  onFailed(job: Job<RideFarePollJob>, error: Error) {
    this.logger.error(
      `ride-fare poll ${job.id} failed for payment ${job.data?.paymentId}: ${error.message}`,
    );
  }
}
