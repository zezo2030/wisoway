import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { RequestMethod } from '@nestjs/common';
import { JwtAuthGuard } from '../../../src/common/guards/jwt-auth.guard';
import { InstantRidesController } from '../../../src/modules/instant-rides/instant-rides.controller';
import { InstantRidesService } from '../../../src/modules/instant-rides/instant-rides.service';
import { InstantRequestStatus } from '../../../src/database/entities/instant-ride-request.entity';

/**
 * Contract for the additive retry endpoint and the additive fields on the
 * request view. Older clients must keep working: `no_drivers` stays a valid
 * status and every new field is optional to read.
 */
describe('POST /instant-rides/requests/:id/retry (Contract)', () => {
  const proto = InstantRidesController.prototype;

  it('is a POST on requests/:id/retry under the instant-rides controller', () => {
    expect(Reflect.getMetadata(PATH_METADATA, InstantRidesController)).toBe(
      'instant-rides',
    );
    expect(Reflect.getMetadata(PATH_METADATA, proto.retryRequest)).toBe(
      'requests/:id/retry',
    );
    expect(Reflect.getMetadata(METHOD_METADATA, proto.retryRequest)).toBe(
      RequestMethod.POST,
    );
  });

  it('is behind the JWT guard like the rest of the controller', () => {
    const guards: unknown[] =
      Reflect.getMetadata('__guards__', InstantRidesController) ?? [];

    expect(guards).toContain(JwtAuthGuard);
  });

  it('passes the request id and the caller as the owner, with no body', async () => {
    const instantRides = {
      retryRequest: jest.fn().mockResolvedValue({ id: 'r2' }),
    };
    const controller = new InstantRidesController(
      {} as any,
      instantRides as any,
    );

    await expect(controller.retryRequest('r1', 'p1')).resolves.toEqual({
      id: 'r2',
    });
    expect(instantRides.retryRequest).toHaveBeenCalledWith('r1', 'p1');
    // (id, passengerId) only — the new attempt is derived from the stored row.
    expect(proto.retryRequest.length).toBe(2);
  });

  it('documents every conflict code the app branches on', () => {
    const responses = Reflect.getMetadata(
      'swagger/apiResponse',
      proto.retryRequest,
    ) as Record<string, { description?: string }>;

    expect(Object.keys(responses)).toEqual(
      expect.arrayContaining(['403', '404', '409']),
    );
    for (const code of [
      'INSTANT_REQUEST_NOT_RETRYABLE',
      'INSTANT_ACTIVE_REQUEST_EXISTS',
      'INSTANT_RETRY_FARE_RECONFIRMATION_REQUIRED',
    ]) {
      expect(responses['409'].description).toContain(code);
    }
  });

  describe('GET /instant-rides/requests/:id', () => {
    /** Renders a stored row through the real view mapper. */
    async function view(request: Record<string, unknown>) {
      const requestRepo = { findOne: jest.fn().mockResolvedValue(request) };
      const service = new InstantRidesService(
        requestRepo as any,
        { findOne: jest.fn() } as any,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
        { getJob: jest.fn() } as any,
        { getJob: jest.fn() } as any,
      );
      return service.getRequest(request.id as string, 'p1');
    }

    const terminalRow = {
      id: 'r1',
      passengerId: 'p1',
      status: InstantRequestStatus.EXPIRED,
      terminalReason: 'no_eligible_drivers',
      retryOfRequestId: null,
      endedAt: new Date('2026-07-25T10:00:00Z'),
      fromName: 'A',
      fromAddress: null,
      toName: 'B',
      toAddress: null,
      seatCount: 1,
      fareEstimate: '4.50',
      currency: 'JOD',
      tripId: null,
      expiresAt: new Date('2026-07-25T09:58:00Z'),
      fareRevision: 0,
    };

    it('keeps every field an older client already reads', async () => {
      const body = await view(terminalRow);

      for (const field of [
        'id',
        'status',
        'from',
        'to',
        'seatCount',
        'fareEstimate',
        'currency',
        'tripId',
        'expiresAt',
      ]) {
        expect(body).toHaveProperty(field);
      }
    });

    it('adds the terminal-reason and retry fields', async () => {
      const body = await view(terminalRow);

      expect(body).toMatchObject({
        status: 'expired',
        terminalReason: 'no_eligible_drivers',
        canRetry: true,
        retryOfRequestId: null,
      });
    });

    it('still reports the legacy no_drivers status as retryable', async () => {
      const body = await view({
        ...terminalRow,
        status: InstantRequestStatus.NO_DRIVERS,
        terminalReason: null,
      });

      expect(body).toMatchObject({
        status: 'no_drivers',
        canRetry: true,
        terminalReason: null,
      });
    });

    it('does not offer a retry for a cancelled request', async () => {
      const body = await view({
        ...terminalRow,
        status: InstantRequestStatus.CANCELLED,
        terminalReason: 'passenger_cancelled',
      });

      expect(body).toMatchObject({
        status: 'cancelled',
        canRetry: false,
      });
    });
  });
});
