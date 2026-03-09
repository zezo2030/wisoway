import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity({ name: 'communication_fees' })
@Index('idx_communication_fees_country', ['countryCode'], { unique: true })
export class CommunicationFeeEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 5 })
  countryCode: string;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  feeAmount: number;

  @Column({ type: 'varchar', length: 5 })
  currency: string;

  @Column({ type: 'boolean', default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
