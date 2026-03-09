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
import { TripEntity } from './trip.entity';

@Entity({ name: 'bookings' })
@Index('idx_bookings_user_trip', ['userId', 'tripId'], { unique: true })
@Index('idx_bookings_trip', ['tripId'])
@Index('idx_bookings_user', ['userId'])
export class BookingEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tripId', type: 'uuid' })
  tripId: string;

  @ManyToOne(() => TripEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tripId' })
  trip: TripEntity;

  @Column({ name: 'userId', type: 'uuid' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  @Column({ type: 'varchar' })
  seatNumber: string;

  @Column({ type: 'varchar', default: 'pending' })
  @Index('idx_bookings_status')
  status: string;

  @Column({ type: 'boolean', default: false })
  hasDriverPaidToContact: boolean;

  @Column({ type: 'boolean', default: false })
  sharePhoneWithDriver: boolean;

  @Column({ type: 'text', nullable: true })
  cancellationReason: string | null;

  @Column({ type: 'timestamp', nullable: true })
  cancelledAt: Date | null;

  @Column({ type: 'varchar', nullable: true })
  cancelledBy: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
