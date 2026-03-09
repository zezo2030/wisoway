import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitializePostgres1700000000000 implements MigrationInterface {
  name = 'InitializePostgres1700000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "postgis"`);
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'users_role_enum') THEN
          CREATE TYPE users_role_enum AS ENUM ('passenger', 'driver', 'admin');
        END IF;
      END$$;
    `);

    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trip_status_enum') THEN
          CREATE TYPE trip_status_enum AS ENUM ('active', 'hidden', 'completed', 'cancelled');
        END IF;
      END$$;
    `);

    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wallet_account_type_enum') THEN
          CREATE TYPE wallet_account_type_enum AS ENUM ('driver', 'rider', 'system');
        END IF;
      END$$;
    `);

    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wallet_transaction_type_enum') THEN
          CREATE TYPE wallet_transaction_type_enum AS ENUM
            ('topup', 'trip_debit', 'trip_payment', 'refund', 'payout', 'adjustment', 'hold', 'release_hold');
        END IF;
      END$$;
    `);

    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wallet_entry_direction_enum') THEN
          CREATE TYPE wallet_entry_direction_enum AS ENUM ('debit', 'credit');
        END IF;
      END$$;
    `);

    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wallet_transaction_status_enum') THEN
          CREATE TYPE wallet_transaction_status_enum AS ENUM ('pending', 'posted', 'failed', 'reversed');
        END IF;
      END$$;
    `);

    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payout_status_enum') THEN
          CREATE TYPE payout_status_enum AS ENUM ('pending', 'approved', 'rejected', 'paid');
        END IF;
      END$$;
    `);

    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_channel_enum') THEN
          CREATE TYPE notification_channel_enum AS ENUM ('in_app', 'push');
        END IF;
      END$$;
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        email VARCHAR UNIQUE,
        "phoneNumber" VARCHAR UNIQUE,
        name VARCHAR(120) NOT NULL,
        "passwordHash" VARCHAR,
        role users_role_enum NOT NULL DEFAULT 'passenger',
        "isActive" BOOLEAN NOT NULL DEFAULT TRUE,
        "fcmToken" VARCHAR,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS users_email_idx ON users (email)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS users_phone_idx ON users ("phoneNumber")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS users_role_idx ON users (role)`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS trips (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "driverId" UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        "fromName" VARCHAR(160) NOT NULL,
        "toName" VARCHAR(160) NOT NULL,
        "fromPoint" geography(Point,4326) NOT NULL,
        "toPoint" geography(Point,4326) NOT NULL,
        "departureTime" TIMESTAMPTZ NOT NULL,
        price NUMERIC(10,2) NOT NULL,
        currency VARCHAR(5) NOT NULL DEFAULT 'EGP',
        "totalSeats" INT NOT NULL DEFAULT 4,
        "availableSeats" INT NOT NULL DEFAULT 4,
        status trip_status_enum NOT NULL DEFAULT 'active',
        "isVisible" BOOLEAN NOT NULL DEFAULT TRUE,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS trips_driver_idx ON trips ("driverId")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS trips_status_departure_idx ON trips (status, "departureTime")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS trips_from_point_idx ON trips USING GIST ("fromPoint")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS trips_to_point_idx ON trips USING GIST ("toPoint")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS driver_locations (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "driverId" UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        "tripId" UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        point geography(Point,4326) NOT NULL,
        "speedKph" NUMERIC(6,2),
        heading NUMERIC(6,2),
        "accuracyMeters" NUMERIC(6,2),
        "recordedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS driver_locations_driver_time_idx ON driver_locations ("driverId", "recordedAt")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS driver_locations_trip_time_idx ON driver_locations ("tripId", "recordedAt")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS driver_locations_point_idx ON driver_locations USING GIST (point)`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS wallet_accounts (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "userId" UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        "accountType" wallet_account_type_enum NOT NULL,
        currency VARCHAR(5) NOT NULL DEFAULT 'EGP',
        balance NUMERIC(14,2) NOT NULL DEFAULT 0,
        "isActive" BOOLEAN NOT NULL DEFAULT TRUE,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT wallet_accounts_user_type_unique UNIQUE ("userId", "accountType", currency)
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS wallet_accounts_user_idx ON wallet_accounts ("userId")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "accountId" UUID NOT NULL REFERENCES wallet_accounts(id) ON DELETE CASCADE,
        type wallet_transaction_type_enum NOT NULL,
        direction wallet_entry_direction_enum NOT NULL,
        status wallet_transaction_status_enum NOT NULL DEFAULT 'posted',
        amount NUMERIC(14,2) NOT NULL,
        currency VARCHAR(5) NOT NULL DEFAULT 'EGP',
        "referenceType" VARCHAR,
        "referenceId" VARCHAR,
        "idempotencyKey" VARCHAR UNIQUE,
        metadata JSONB,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS wallet_tx_account_created_idx ON wallet_transactions ("accountId", "createdAt")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS wallet_tx_reference_idx ON wallet_transactions ("referenceId")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS wallet_holds (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "accountId" UUID NOT NULL REFERENCES wallet_accounts(id) ON DELETE CASCADE,
        amount NUMERIC(14,2) NOT NULL,
        currency VARCHAR(5) NOT NULL DEFAULT 'EGP',
        status VARCHAR NOT NULL DEFAULT 'pending',
        "referenceType" VARCHAR,
        "referenceId" VARCHAR,
        "expiresAt" TIMESTAMPTZ,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS wallet_holds_account_idx ON wallet_holds ("accountId")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS wallet_holds_status_idx ON wallet_holds (status)`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS payout_requests (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "driverId" UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        amount NUMERIC(14,2) NOT NULL,
        currency VARCHAR(5) NOT NULL DEFAULT 'EGP',
        status payout_status_enum NOT NULL DEFAULT 'pending',
        "bankAccountRef" VARCHAR(120),
        note VARCHAR(255),
        "processedByAdminId" UUID,
        "processedAt" TIMESTAMPTZ,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS payout_requests_driver_idx ON payout_requests ("driverId", "createdAt")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS payout_requests_status_idx ON payout_requests (status)`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "userId" UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type VARCHAR(50) NOT NULL,
        title VARCHAR(160) NOT NULL,
        body TEXT,
        channel notification_channel_enum NOT NULL DEFAULT 'in_app',
        "isRead" BOOLEAN NOT NULL DEFAULT FALSE,
        data JSONB,
        "expiresAt" TIMESTAMPTZ,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS notifications_user_created_idx ON notifications ("userId", "createdAt")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS notifications_user_read_idx ON notifications ("userId", "isRead")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS device_tokens (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "userId" UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token VARCHAR(512) NOT NULL UNIQUE,
        platform VARCHAR(20) NOT NULL DEFAULT 'android',
        "isActive" BOOLEAN NOT NULL DEFAULT TRUE,
        "lastSeenAt" TIMESTAMPTZ,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS device_tokens_user_idx ON device_tokens ("userId")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS device_tokens`);
    await queryRunner.query(`DROP TABLE IF EXISTS notifications`);
    await queryRunner.query(`DROP TABLE IF EXISTS payout_requests`);
    await queryRunner.query(`DROP TABLE IF EXISTS wallet_holds`);
    await queryRunner.query(`DROP TABLE IF EXISTS wallet_transactions`);
    await queryRunner.query(`DROP TABLE IF EXISTS wallet_accounts`);
    await queryRunner.query(`DROP TABLE IF EXISTS driver_locations`);
    await queryRunner.query(`DROP TABLE IF EXISTS trips`);
    await queryRunner.query(`DROP TABLE IF EXISTS users`);
  }
}
