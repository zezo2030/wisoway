import { OnQueueFailed, Process, Processor } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import {
  DriverAvailabilityEntity,
  InstantOfferStatus,
  InstantRequestStatus,
  InstantRideOfferEntity,
  InstantRideRequestEntity,
  InstantTerminalReason,
} from '../../../database/entities';
import { InstantDispatchService } from '../instant-dispatch.service';
import {
  DISPATCH_WAVE_JOB,
  EXPIRE_REQUEST_JOB,
  INSTANT_REQUEST_EXPIRY_QUEUE,
} from '../instant-rides.constants';

/**
 * Fires when an instant request's overall window elapses without a match:
 * cancels any outstanding offer, frees the driver, and tells the passenger no
 * driver was found.
 */
@Processor(INSTANT_REQUEST_EXPIRY_QUEUE)
export class InstantRequestExpiryProcessor {
  private readonly logger = new Logger(InstantRequestExpiryProcessor.name);

  constructor(
    @InjectRepository(InstantRideRequestEntity)
    private readonly requestRepo: Repository<InstantRideRequestEntity>,
    @InjectRepository(InstantRideOfferEntity)
    private readonly offerRepo: Repository<InstantRideOfferEntity>,
    @InjectRepository(DriverAvailabilityEntity)
    private readonly availabilityRepo: Repository<DriverAvailabilityEntity>,
    private readonly dispatch: InstantDispatchService,
  ) {}

  /** Delayed re-dispatch wave while the request is still searching. */
  @Process(DISPATCH_WAVE_JOB)
  async handleWave(job: Job<{ requestId: string }>): Promise<void> {
    await this.dispatch.dispatchNext(job.data.requestId);
  }

  @Process(EXPIRE_REQUEST_JOB)
  async handle(job: Job<{ requestId: string }>): Promise<void> {
    const { requestId } = job.data;
    const request = await this.requestRepo.findOne({
      where: { id: requestId },
    });
    if (
      !request ||
      (request.status !== InstantRequestStatus.SEARCHING &&
        request.status !== InstantRequestStatus.OFFERED)
    ) {
      return;
    }

    const offer = await this.offerRepo.findOne({
      where: {
        requestId,
        status: In([InstantOfferStatus.OFFERED, InstantOfferStatus.COUNTERED]),
      },
    });
    if (offer) {
      await this.offerRepo.update(
        { id: offer.id },
        { status: InstantOfferStatus.CANCELLED, respondedAt: new Date() },
      );
      await this.availabilityRepo.update(
        { driverId: offer.driverId, currentRequestId: requestId },
        { currentRequestId: null },
      );
    }

    // The outstanding offer above is already cancelled, so the shared helper
    // reads "all declined" unless nobody was ever offered the ride.
    await this.dispatch.finalizeSearch(
      requestId,
      offer ? InstantTerminalReason.TTL_EXPIRED : undefined,
    );
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `Request-expiry job ${job.id} failed: ${error.message}`,
      error.stack,
    );
  }
}
