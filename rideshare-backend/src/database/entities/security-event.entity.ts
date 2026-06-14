import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';

/**
 * An immutable audit log of security-relevant events that occur on a user
 * account or device.  Rows are append-only — never updated or deleted by
 * application code.
 *
 * Phase 3 (008-platform-completion / US1 — auth hardening):
 *  - Written by LocationGuardInterceptor on mock-location rejection (T031).
 *  - Written by AccountRiskService on multi-account flag creation (T027).
 *  - Written by DeviceService on device revoke (T034).
 *  - Read by admin API for audit trail (T034–T037).
 *
 * Example eventType values:
 *  - 'mock_location_rejected'
 *  - 'multi_account_flag_created'
 *  - 'device_revoked_by_admin'
 *  - 'account_restricted_auto'
 *  - 'account_unrestricted_admin'
 */
@Entity({ name: 'security_events' })
@Index('security_events_user_idx', ['userId'])
@Index('security_events_type_idx', ['eventType'])
@Index('security_events_created_idx', ['createdAt'])
export class SecurityEventEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** The user the event concerns (nullable for system-level events with no actor). */
  @Column({ type: 'uuid', nullable: true, default: null })
  userId: string | null;

  @ManyToOne(() => UserEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'userId' })
  user: UserEntity | null;

  /** Machine-readable event type (see examples in class JSDoc). */
  @Column({ type: 'varchar', length: 64 })
  eventType: string;

  /**
   * Optional reference to the UserDevice involved (e.g. for revoke events).
   * Stored as plain UUID string to avoid hard FK constraint on an audit log.
   */
  @Column({ type: 'uuid', nullable: true, default: null })
  deviceId: string | null;

  /** Optional structured metadata serialised as JSON (IP, coordinates, etc.). */
  @Column({ type: 'jsonb', nullable: true, default: null })
  metadata: Record<string, unknown> | null;

  /** UUID of the admin actor when the event was triggered by an admin action. */
  @Column({ type: 'uuid', nullable: true, default: null })
  adminActorId: string | null;

  /**
   * Optional HTTP request / trace correlation ID (Phase 9 / T187).
   * Set from the `X-Request-ID` header (or gateway-assigned trace ID) so a
   * single inbound request can be traced across logs, audit rows, and queues.
   * Nullable: background jobs that create security events have no request ID.
   */
  @Column({ type: 'varchar', nullable: true, default: null })
  correlationId: string | null;

  /** Immutable creation timestamp — the only timestamp this entity needs. */
  @CreateDateColumn({ type: 'timestamptz' })
  createdAt: Date;
}
