import { InstantRequestExpiryProcessor } from './instant-request-expiry.processor';

describe('InstantRequestExpiryProcessor', () => {
  let requestRepo: any;
  let offerRepo: any;
  let availabilityRepo: any;
  let dispatch: any;
  let processor: InstantRequestExpiryProcessor;

  const job = (requestId: string) => ({ data: { requestId } }) as any;

  beforeEach(() => {
    requestRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: 'r1',
        passengerId: 'p1',
        status: 'searching',
      }),
    };
    offerRepo = {
      findOne: jest.fn().mockResolvedValue(null),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    availabilityRepo = { update: jest.fn().mockResolvedValue({ affected: 1 }) };
    dispatch = {
      dispatchNext: jest.fn().mockResolvedValue(undefined),
      finalizeSearch: jest.fn().mockResolvedValue(true),
    };
    processor = new InstantRequestExpiryProcessor(
      requestRepo,
      offerRepo,
      availabilityRepo,
      dispatch,
    );
  });

  it('ignores a request that is no longer searching', async () => {
    requestRepo.findOne.mockResolvedValue({ id: 'r1', status: 'accepted' });

    await processor.handle(job('r1'));

    expect(dispatch.finalizeSearch).not.toHaveBeenCalled();
  });

  it('lets the shared helper derive the reason when no offer is outstanding', async () => {
    await processor.handle(job('r1'));

    expect(offerRepo.update).not.toHaveBeenCalled();
    expect(dispatch.finalizeSearch).toHaveBeenCalledWith('r1', undefined);
  });

  it('cancels the outstanding offer, frees the driver, and forces ttl_expired', async () => {
    offerRepo.findOne.mockResolvedValue({
      id: 'o1',
      driverId: 'd1',
      status: 'offered',
    });

    await processor.handle(job('r1'));

    expect(offerRepo.update).toHaveBeenCalledWith(
      { id: 'o1' },
      expect.objectContaining({ status: 'cancelled' }),
    );
    expect(availabilityRepo.update).toHaveBeenCalledWith(
      { driverId: 'd1', currentRequestId: 'r1' },
      { currentRequestId: null },
    );
    expect(dispatch.finalizeSearch).toHaveBeenCalledWith('r1', 'ttl_expired');
  });

  it('runs a delayed dispatch wave without finalizing the request', async () => {
    await processor.handleWave(job('r1'));

    expect(dispatch.dispatchNext).toHaveBeenCalledWith('r1');
    expect(dispatch.finalizeSearch).not.toHaveBeenCalled();
  });
});
