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

export enum SavedPlaceKind {
  HOME = 'home',
  WORK = 'work',
  CUSTOM = 'custom',
}

/**
 * A user's shortcut place (Home, Work or a named one), offered by the app's
 * route search before the user types. Home and Work are stored with an empty
 * label, so the unique index makes each a singleton per user; a custom place
 * is unique by its label.
 */
@Entity({ name: 'saved_places' })
@Index('uq_saved_places_user_kind_label', ['userId', 'kind', 'label'], {
  unique: true,
})
export class SavedPlaceEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  @Column({ type: 'enum', enum: SavedPlaceKind })
  kind: SavedPlaceKind;

  @Column({ type: 'varchar', length: 30, default: '' })
  label: string;

  @Column({ type: 'varchar', length: 200 })
  name: string;

  @Column({ type: 'varchar', length: 300, default: '' })
  secondaryText: string;

  @Column({ type: 'double precision' })
  latitude: number;

  @Column({ type: 'double precision' })
  longitude: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
