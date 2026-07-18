import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { InstantRideRequestEntity } from './instant-ride-request.entity';

export const InstantOfferStatus = {
  /** Sent to the driver, awaiting response. */
  OFFERED: 'offered',
  ACCEPTED: 'accepted',
  DECLINED: 'declined',
  /** The driver countered with a higher fare, awaiting the passenger. */
  COUNTERED: 'countered',
  /** The passenger declined the driver's counter-offer. */
  REJECTED: 'rejected',
  /** The driver didn't respond within the offer window. */
  TIMED_OUT: 'timed_out',
  /** The request was cancelled/expired before the driver responded. */
  CANCELLED: 'cancelled',
} as const;
export type InstantOfferStatus =
  (typeof InstantOfferStatus)[keyof typeof InstantOfferStatus];

/** One offer of an instant request to one driver (sequential dispatch). */
@Entity({ name: 'instant_ride_offers' })
@Index('instant_offers_request_idx', ['requestId'])
@Index('instant_offers_driver_status_idx', ['driverId', 'status'])
export class InstantRideOfferEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  requestId: string;

  @ManyToOne(() => InstantRideRequestEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'requestId' })
  request: InstantRideRequestEntity;

  @Column({ type: 'uuid' })
  driverId: string;

  @Column({ type: 'uuid', nullable: true })
  vehicleId: string | null;

  @Column({ type: 'varchar', length: 16, default: InstantOfferStatus.OFFERED })
  status: InstantOfferStatus;

  /** Driver's counter-offer fare; null while the offer is at the passenger's fare. */
  @Column({ type: 'numeric', precision: 10, scale: 2, nullable: true })
  proposedFare: string | null;

  /** The request's fare revision this offer was made at. */
  @Column({ type: 'int', default: 1 })
  fareRevision: number;

  @Column({ type: 'timestamptz', default: () => 'CURRENT_TIMESTAMP' })
  offeredAt: Date;

  @Column({ type: 'timestamptz', nullable: true })
  respondedAt: Date | null;

  @Column({ type: 'timestamptz' })
  expiresAt: Date;

  @CreateDateColumn()
  createdAt: Date;
}
