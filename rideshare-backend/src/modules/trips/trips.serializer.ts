/**
 * TripSerializer — Phase 9 / T180 (008-platform-completion)
 *
 * The `published → active` compatibility shim (R-008) has been dropped.
 *
 * Background:
 *  - Migration 008.06 converted all `status='active'` rows to `status='published'`
 *    in PostgreSQL and kept the response serializer emitting 'active' for one
 *    release so that deployed mobile clients below the min-version floor would
 *    not break.
 *  - Phase 9 enforces the MIN_APP_VERSION gate: requests from app versions below
 *    the gate are rejected with 409 UPGRADE_REQUIRED before reaching any endpoint.
 *    Once the gate is live, 'published' can be returned verbatim.
 *
 * After this change:
 *  - `trip.status` is returned as-is to all clients.
 *  - Clients MUST recognise: 'draft' | 'published' | 'fully_booked' | 'in_progress'
 *    | 'hidden' | 'completed' | 'cancelled'
 *  - The legacy 'active' value no longer appears in any response.
 */

import { TripEntity } from '../../database/entities/trip.entity';

/**
 * Serialize a trip entity for inclusion in API responses.
 * No compatibility remapping is applied — the real status value is returned.
 */
export function serializeTrip(trip: TripEntity): Record<string, unknown> {
  return {
    ...trip,
    // status is returned verbatim; 'published' is the normal visible-trip value
    // (the historical 'active' alias was removed by migration 008.06 / Phase 9 T180)
  };
}
