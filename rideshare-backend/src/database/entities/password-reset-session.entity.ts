import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity({ name: 'password_reset_sessions' })
@Index('idx_password_reset_phone', ['phoneNumber'])
@Index('idx_password_reset_expires', ['expiresAt'])
export class PasswordResetSessionEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar' })
  phoneNumber: string;

  @Column({ type: 'varchar', select: false })
  otpCode: string;

  @Column({ type: 'boolean', default: false })
  isVerified: boolean;

  @Column({ type: 'int', default: 0 })
  attemptCount: number;

  @Column({ type: 'boolean', default: false })
  isLocked: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @Column({ type: 'timestamp' })
  expiresAt: Date;
}
