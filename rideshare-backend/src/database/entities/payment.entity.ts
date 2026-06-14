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
import { BookingEntity } from './booking.entity';

@Entity({ name: 'payments' })
@Index('idx_payments_user', ['userId'])
@Index('idx_payments_trip', ['tripId'])
@Index('idx_payments_booking', ['bookingId'])
@Index('idx_payments_status', ['status'])
export class PaymentEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', nullable: true })
  tripId: string | null;

  @ManyToOne(() => TripEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'tripId' })
  trip: TripEntity | null;

  @Column({ type: 'uuid', nullable: true })
  bookingId: string | null;

  @ManyToOne(() => BookingEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'bookingId' })
  booking: BookingEntity | null;

  @Column({ type: 'uuid' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'varchar', length: 5, default: 'JOD' })
  currency: string;

  @Column({ type: 'varchar' })
  method: string;

  @Column({ type: 'varchar', default: 'pending' })
  status: string;

  @Column({ type: 'varchar', default: 'trip' })
  paymentType: string;

  @Column({ type: 'varchar', nullable: true })
  direction: string | null;

  @Column({ type: 'text', nullable: true })
  proofImageUrl: string | null;

  @Column({ type: 'varchar', nullable: true })
  walletNumber: string | null;

  @Column({ type: 'varchar', nullable: true })
  transactionId: string | null;

  @Column({ type: 'varchar', nullable: true })
  paymentGatewayRef: string | null;

  @Column({ type: 'varchar', nullable: true })
  recipientAliasType: string | null;

  @Column({ type: 'varchar', nullable: true })
  recipientAliasValue: string | null;

  @Column({ type: 'text', nullable: true })
  adminNote: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
