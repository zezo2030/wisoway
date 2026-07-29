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

@Entity({ name: 'vehicles' })
@Index('idx_vehicles_driver_id', ['driverId'], { unique: true })
export class VehicleEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  driverId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'driverId' })
  driver: UserEntity;

  @Column({ type: 'varchar' })
  vehicleType: string;

  @Column({ type: 'varchar', length: 20 })
  plateNumber: string;

  @Column({ type: 'varchar', length: 100 })
  model: string;

  @Column({ type: 'int' })
  seats: number;

  @Column({ type: 'jsonb', nullable: true })
  seatLayout: {
    rows: number;
    seatsPerRow: number;
    seatsPerRowList?: number[];
    preventGenderMixing?: boolean;
  } | null;

  @Column({ type: 'text', nullable: true })
  licenseImageUrl: string | null;

  @Column({ type: 'text', nullable: true })
  vehicleLicenseImageUrl: string | null;

  /** A photo of the car itself. Captured once at vehicle registration and
   * shown on every trip detail screen. */
  @Column({ type: 'text', nullable: true })
  carImageUrl: string | null;

  /** Vehicle insurance document. Required for registrations from this release
   * on; nullable for vehicles created before the column existed. */
  @Column({ type: 'text', nullable: true })
  insuranceImageUrl: string | null;

  @Column({ type: 'boolean', default: false })
  isVerified: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
