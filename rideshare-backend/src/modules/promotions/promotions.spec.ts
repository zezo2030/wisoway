import { EntityManager } from 'typeorm';
import { pricePromotion } from './promotions.module';
describe('Passenger promotion pricing', () => {
  const campaign = {
    code: 'SAVE20',
    percent: '20',
    tripType: 'all',
    active: true,
    startsAt: new Date(Date.now() - 60000),
    endsAt: new Date(Date.now() + 60000),
  };
  const query = jest.fn();
  const manager = { query } as unknown as EntityManager;
  beforeEach(() => {
    query.mockReset();
    query.mockResolvedValue([campaign]);
  });
  it('normalizes code and computes rounded net fare on the server', async () => {
    expect(await pricePromotion(manager, ' save20 ', 10, 'shared')).toEqual({
      promoCode: 'SAVE20',
      originalAmount: '10.00',
      discountAmount: '2.00',
      totalAmount: '8.00',
    });
    expect(query).toHaveBeenCalledWith(expect.any(String), ['SAVE20']);
  });
  it.each([
    { active: false },
    { endsAt: new Date(0) },
    { startsAt: new Date(Date.now() + 600000) },
    { tripType: 'instant' },
  ])('rejects ineligible campaigns %j', async (overrides) => {
    query.mockResolvedValue([{ ...campaign, ...overrides }]);
    await expect(
      pricePromotion(manager, 'SAVE20', 10, 'shared'),
    ).rejects.toThrow();
  });
  it('rejects unknown codes', async () => {
    query.mockResolvedValue([]);
    await expect(
      pricePromotion(manager, 'UNKNOWN', 10, 'instant'),
    ).rejects.toThrow();
  });
  it('allows a fully subsidized trip without a negative payable amount', async () => {
    query.mockResolvedValue([{ ...campaign, percent: '100' }]);
    expect(
      (await pricePromotion(manager, 'SAVE20', 10, 'instant')).totalAmount,
    ).toBe('0.00');
  });
  it('keeps normal bookings independent of campaigns', async () => {
    expect(
      (await pricePromotion(manager, undefined, 10, 'shared')).discountAmount,
    ).toBe('0.00');
    expect(query).not.toHaveBeenCalled();
  });
});
