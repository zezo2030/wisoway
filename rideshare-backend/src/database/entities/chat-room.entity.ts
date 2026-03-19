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
import { TripEntity } from './trip.entity';
import { UserEntity } from './user.entity';

@Entity({ name: 'chat_rooms' })
@Index('idx_chat_rooms_trip_id', ['tripId'])
@Index('idx_chat_rooms_last_message_time', ['lastMessageTime'])
export class ChatRoomEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  tripId: string;

  /** For 1:1 rooms: the passenger in this driver-passenger chat. Null = legacy group room. */
  @Column({ type: 'uuid', nullable: true })
  passengerId: string | null;

  @ManyToOne(() => TripEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tripId' })
  trip: TripEntity;

  // Store JSON of participants: [{ userId: string, joinedAt: Date }]
  @Column({ type: 'jsonb', default: [] })
  participants: any[];

  @Column({ type: 'text', nullable: true })
  lastMessage: string | null;

  @Column({ type: 'timestamp', nullable: true })
  lastMessageTime: Date | null;

  @Column({ type: 'uuid', nullable: true })
  lastMessageSenderId: string | null;

  @ManyToOne(() => UserEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'lastMessageSenderId' })
  lastMessageSender: UserEntity | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
