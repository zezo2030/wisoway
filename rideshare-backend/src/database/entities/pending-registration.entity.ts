import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { PgUserRole } from './shared.enums';

export enum PendingRegistrationGender {
  MALE = 'male',
  FEMALE = 'female',
}

@Entity({ name: 'pending_registrations' })
export class PendingRegistrationEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', unique: true })
  @Index('idx_pending_registration_phone')
  phoneNumber: string;

  @Column({ type: 'varchar', unique: true, nullable: true })
  @Index('idx_pending_registration_email')
  email: string | null;

  @Column({ type: 'varchar', select: false })
  passwordHash: string;

  @Column({ type: 'varchar', length: 100 })
  name: string;

  @Column({
    type: 'enum',
    enum: PendingRegistrationGender,
    nullable: true,
  })
  gender: PendingRegistrationGender | null;

  @Column({
    type: 'enum',
    enum: PgUserRole,
    default: PgUserRole.PASSENGER,
  })
  role: PgUserRole;

  @Column({ type: 'timestamp' })
  expiresAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
