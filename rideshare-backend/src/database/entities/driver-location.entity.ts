import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';
import { TripEntity } from './trip.entity';

type GeoPoint = {
  type: 'Point';
  coordinates: [number, number];
};

@Entity({ name: 'driver_locations' })
@Index('driver_locations_driver_time_idx', ['driverId', 'recordedAt'])
@Index('driver_locations_trip_time_idx', ['tripId', 'recordedAt'])
export class DriverLocationEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  driverId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'driverId' })
  driver: UserEntity;

  @Column({ type: 'uuid' })
  tripId: string;

  @ManyToOne(() => TripEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tripId' })
  trip: TripEntity;

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  @Index('driver_locations_point_idx', { spatial: true })
  point: GeoPoint;

  @Column({ type: 'numeric', precision: 6, scale: 2, nullable: true })
  speedKph: string | null;

  @Column({ type: 'numeric', precision: 6, scale: 2, nullable: true })
  heading: string | null;

  @Column({ type: 'numeric', precision: 6, scale: 2, nullable: true })
  accuracyMeters: string | null;

  @Column({ type: 'timestamptz', default: () => 'CURRENT_TIMESTAMP' })
  recordedAt: Date;

  @CreateDateColumn()
  createdAt: Date;
}
