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

@Entity({ name: 'ratings' })
@Index('idx_ratings_from_user_trip', ['fromUserId', 'tripId'], { unique: true })
export class RatingEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  fromUserId: string;

  @ManyToOne(() => UserEntity)
  @JoinColumn({ name: 'fromUserId' })
  fromUser: UserEntity;

  @Column({ type: 'uuid' })
  toUserId: string;

  @ManyToOne(() => UserEntity)
  @JoinColumn({ name: 'toUserId' })
  toUser: UserEntity;

  @Column({ type: 'uuid' })
  tripId: string;

  @ManyToOne(() => TripEntity)
  @JoinColumn({ name: 'tripId' })
  trip: TripEntity;

  @Column({ type: 'int' })
  rating: number;

  @Column({ type: 'text', nullable: true })
  comment: string | null;

  @Column({ type: 'varchar', nullable: true })
  userRole: string | null;

  @Column({ type: 'varchar', nullable: true })
  ratedRole: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
