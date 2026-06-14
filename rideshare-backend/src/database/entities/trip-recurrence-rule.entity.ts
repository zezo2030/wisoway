/**
 * Phase 6 / T116 — 008-platform-completion, US4 / 012-trip-authoring
 *
 * TripRecurrenceRule entity — captures a recurring-trip template that the
 * RecurrenceSpawnProcessor uses to auto-generate future Trip rows.
 *
 * See data-model.md "TripRecurrenceRule (`trip_recurrence_rules`)".
 */

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

export enum RecurrenceFrequency {
  DAILY = 'daily',
  WEEKLY = 'weekly',
}

@Entity({ name: 'trip_recurrence_rules' })
@Index('recurrence_rules_driver_active_idx', ['driverId', 'isActive'])
@Index('recurrence_rules_spawn_sweep_idx', ['isActive', 'lastSpawnedFor'])
export class TripRecurrenceRuleEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  driverId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'driverId' })
  driver: UserEntity;

  @Column({ type: 'jsonb' })
  templateJson: any;

  @Column({ type: 'enum', enum: RecurrenceFrequency })
  frequency: RecurrenceFrequency;

  @Column({ type: 'smallint', default: 0 })
  weekdayMask: number;

  @Column({ type: 'time' })
  localTime: string;

  @Column({ type: 'varchar', length: 40, default: 'Asia/Amman' })
  timezone: string;

  @Column({ type: 'date', nullable: true })
  until: string | null;

  @Column({ type: 'date', nullable: true })
  lastSpawnedFor: string | null;

  @Column({ type: 'boolean', default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
