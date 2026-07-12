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
} from '../../../database/entities';
import { NotificationsService } from '../../notifications/notifications.service';
import {
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
    private readonly notifications: NotificationsService,
  ) {}

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
      where: { requestId, status: InstantOfferStatus.OFFERED },
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

    await this.requestRepo.update(
      {
        id: requestId,
        status: In([
          InstantRequestStatus.SEARCHING,
          InstantRequestStatus.OFFERED,
        ]),
      },
      { status: InstantRequestStatus.NO_DRIVERS },
    );

    await this.notifications
      .sendPush(request.passengerId, {
        title: 'انتهت مهلة الطلب',
        body: 'لم نعثر على سائق متاح. يمكنك المحاولة مرة أخرى.',
        type: 'instant_no_drivers',
        data: { requestId },
      })
      .catch(() => undefined);
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `Request-expiry job ${job.id} failed: ${error.message}`,
      error.stack,
    );
  }
}
