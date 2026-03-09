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
import { ChatRoomEntity } from './chat-room.entity';

@Entity({ name: 'messages' })
@Index('idx_messages_chat_room', ['chatRoomId'])
@Index('idx_messages_created_at_desc', ['chatRoomId', 'createdAt'])
export class MessageEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  chatRoomId: string;

  @ManyToOne(() => ChatRoomEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'chatRoomId' })
  chatRoom: ChatRoomEntity;

  @Column({ type: 'uuid' })
  senderId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'senderId' })
  sender: UserEntity;

  @Column({ type: 'varchar', nullable: true })
  senderName: string | null;

  @Column({ type: 'text' })
  text: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
