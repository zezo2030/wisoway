import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';
import { TripStatus } from './shared.enums';

type GeoPoint = {
  type: 'Point';
  coordinates: [number, number];
};

@Entity({ name: 'trips' })
@Index('trips_driver_idx', ['driverId'])
@Index('trips_status_departure_idx', ['status', 'departureTime'])
export class TripEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  driverId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'driverId' })
  driver: UserEntity;

  @Column({ type: 'varchar', nullable: true })
  driverName: string | null;

  @Column({ type: 'varchar', length: 160 })
  fromName: string;

  @Column({ type: 'text', nullable: true })
  fromAddress: string | null;

  @Column({ type: 'varchar', length: 160 })
  toName: string;

  @Column({ type: 'text', nullable: true })
  toAddress: string | null;

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  @Index('trips_from_point_idx', { spatial: true })
  fromPoint: GeoPoint;

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  @Index('trips_to_point_idx', { spatial: true })
  toPoint: GeoPoint;

  @Column({ type: 'timestamptz' })
  departureTime: Date;

  @Column({ type: 'numeric', precision: 10, scale: 2 })
  price: string;

  @Column({ type: 'varchar', length: 5, default: 'EGP' })
  currency: string;

  @Column({ type: 'int', default: 4 })
  totalSeats: number;

  @Column({ type: 'int', default: 4 })
  availableSeats: number;

  @Column({ type: 'jsonb', nullable: true })
  seatLayout: any;

  @Column({ type: 'jsonb', default: [] })
  seats: any[];

  @Column({ type: 'enum', enum: TripStatus, default: TripStatus.ACTIVE })
  status: TripStatus;

  @Column({ type: 'varchar', default: 'not_paid' })
  communicationFeeStatus: string;

  @Column({ type: 'text', nullable: true })
  carImageUrl: string | null;

  @Column({ type: 'boolean', default: true })
  isVisible: boolean;

  @Column({ type: 'boolean', default: false })
  driverWalletChargeApplied: boolean;

  @Column({ type: 'timestamp', nullable: true })
  driverWalletChargeAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
