import { OnQueueFailed, Process, Processor } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  DriverAvailabilityEntity,
  InstantOfferStatus,
  InstantRequestStatus,
  InstantRideOfferEntity,
  InstantRideRequestEntity,
} from '../../../database/entities';
import { InstantDispatchService } from '../instant-dispatch.service';
import {
  EXPIRE_OFFER_JOB,
  INSTANT_OFFER_TIMEOUT_QUEUE,
} from '../instant-rides.constants';

/**
 * Fires when a driver doesn't respond to an instant-ride offer in time:
 * marks the offer timed-out, frees the driver, and moves the request on to the
 * next-nearest driver.
 */
@Processor(INSTANT_OFFER_TIMEOUT_QUEUE)
export class InstantOfferTimeoutProcessor {
  private readonly logger = new Logger(InstantOfferTimeoutProcessor.name);

  constructor(
    @InjectRepository(InstantRideOfferEntity)
    private readonly offerRepo: Repository<InstantRideOfferEntity>,
    @InjectRepository(InstantRideRequestEntity)
    private readonly requestRepo: Repository<InstantRideRequestEntity>,
    @InjectRepository(DriverAvailabilityEntity)
    private readonly availabilityRepo: Repository<DriverAvailabilityEntity>,
    private readonly dispatch: InstantDispatchService,
  ) {}

  @Process(EXPIRE_OFFER_JOB)
  async handle(job: Job<{ offerId: string }>): Promise<void> {
    const { offerId } = job.data;
    const offer = await this.offerRepo.findOne({ where: { id: offerId } });
    if (!offer || offer.status !== InstantOfferStatus.OFFERED) {
      return;
    }

    await this.offerRepo.update(
      { id: offerId, status: InstantOfferStatus.OFFERED },
      { status: InstantOfferStatus.TIMED_OUT, respondedAt: new Date() },
    );
    await this.availabilityRepo.update(
      { driverId: offer.driverId, currentRequestId: offer.requestId },
      { currentRequestId: null },
    );
    await this.requestRepo.update(
      { id: offer.requestId, status: InstantRequestStatus.OFFERED },
      { status: InstantRequestStatus.SEARCHING },
    );

    await this.dispatch.dispatchNext(offer.requestId);
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `Offer-timeout job ${job.id} failed: ${error.message}`,
      error.stack,
    );
  }
}
