/**
 * Runs at the scheduled departureTime (and again from the lifecycle sweep
 * while a trip is still waiting). Whether the trip actually starts now — or
 * waits for a passenger to confirm they're on board — is TripStartService's
 * call; see there.
 *
 * No fines are issued here. Driver no-show is surfaced to admins purely through
 * passenger reports (booking.passengerReportedDriverAbsentAt) collected during
 * the existing -60m to +30m confirmation window.
 */
import { Processor, Process, OnQueueFailed } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { TripStartService } from '../../trip-time/trip-start.service';

@Processor('trip-auto-start')
export class TripAutoStartProcessor {
  private readonly logger = new Logger(TripAutoStartProcessor.name);

  constructor(private readonly tripStart: TripStartService) {}

  @Process('enforce')
  async handle(job: Job<{ tripId: string }>): Promise<void> {
    await this.tripStart.onDeparture(job.data.tripId);
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `trip-auto-start job ${job?.id}: ${error.message}`,
      error.stack,
    );
  }
}
