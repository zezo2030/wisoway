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
import { BookingEntity } from './booking.entity';
import { UserEntity } from './user.entity';

export const CallSessionStatus = {
  INITIATED: 'initiated',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  FAILED: 'failed',
} as const;
export type CallSessionStatus =
  (typeof CallSessionStatus)[keyof typeof CallSessionStatus];

@Entity({ name: 'call_sessions' })
@Index('idx_call_sessions_booking', ['bookingId'])
@Index('idx_call_sessions_twilio_sid', ['twilioCallSid'])
export class CallSessionEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  bookingId: string;

  @ManyToOne(() => BookingEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'bookingId' })
  booking: BookingEntity;

  @Column({ type: 'uuid' })
  callerUserId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'callerUserId' })
  caller: UserEntity;

  @Column({ type: 'uuid' })
  calleeUserId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'calleeUserId' })
  callee: UserEntity;

  /** Twilio proxy DID that mediates the call (E.164 format). */
  @Column({ type: 'varchar' })
  proxyNumber: string;

  /** Real phone number of the caller — stored for admin audit only. */
  @Column({ type: 'varchar', nullable: true })
  callerRealNumber: string | null;

  /** Real phone number of the callee — stored for admin audit only. */
  @Column({ type: 'varchar', nullable: true })
  calleeRealNumber: string | null;

  /** Populated by Twilio webhook on call initiation. */
  @Column({ type: 'varchar', nullable: true, unique: true })
  twilioCallSid: string | null;

  @Column({ type: 'varchar', default: CallSessionStatus.INITIATED })
  status: CallSessionStatus;

  @Column({ type: 'timestamp', nullable: true })
  startedAt: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  endedAt: Date | null;

  @Column({ type: 'int', nullable: true })
  durationSeconds: number | null;

  /** Terminal reason as reported by Twilio (e.g. 'completed', 'no-answer', 'busy', 'failed'). */
  @Column({ type: 'varchar', nullable: true })
  terminationReason: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
