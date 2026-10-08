import { PreTripReminderJob } from './pre-trip-reminder.job';

describe('PreTripReminderJob', () => {
  let tripRepo: any;
  let bookingRepo: any;
  let notifications: any;
  let execute: jest.Mock;
  let job: PreTripReminderJob;

  const trip = { id: 't1', driverId: 'd1', toName: 'العلا' };

  beforeEach(() => {
    execute = jest.fn().mockResolvedValue({ affected: 1 });
    const qb: any = {
      update: () => qb,
      set: () => qb,
      where: () => qb,
      andWhere: () => qb,
      execute,
    };
    tripRepo = {
      find: jest.fn().mockResolvedValue([{ id: 't1' }]),
      findOne: jest.fn().mockResolvedValue(trip),
      createQueryBuilder: () => qb,
    };
    bookingRepo = {
      find: jest.fn().mockResolvedValue([
        { id: 'b1', userId: 'p1' },
        { id: 'b2', userId: 'p2' },
      ]),
    };
    notifications = {
      create: jest.fn().mockResolvedValue({}),
      getPreferredLocale: jest.fn().mockResolvedValue('ar'),
    };
    job = new PreTripReminderJob(tripRepo, bookingRepo, notifications);
  });

  it('reminds every confirmed passenger and the driver of a trip due within the hour', async () => {
    await expect(job.sweep(new Date('2026-09-30T10:00:00Z'))).resolves.toBe(1);

    const where = tripRepo.find.mock.calls[0][0].where;
    expect(where.tripType).toBe('scheduled');

    const sent = notifications.create.mock.calls.map((c: any[]) => c[0]);
    expect(sent.map((n: any) => [n.userId, n.type])).toEqual([
      ['p1', 'presence_prompt'],
      ['p2', 'presence_prompt'],
      ['d1', 'presence_driver_prompt'],
    ]);
    expect(sent[0].title).toBe('تذكير: رحلتك بعد ساعة');
    expect(sent[2].body).toContain('الركاب المؤكَّدون: 2');
  });

  it('still reminds the driver when nobody has booked', async () => {
    bookingRepo.find.mockResolvedValue([]);

    await job.remind('t1');

    expect(notifications.create).toHaveBeenCalledTimes(1);
    expect(notifications.create.mock.calls[0][0].userId).toBe('d1');
  });

  it('sends nothing when another tick already claimed the trip', async () => {
    execute.mockResolvedValue({ affected: 0 });

    await expect(job.remind('t1')).resolves.toBe(false);
    expect(notifications.create).not.toHaveBeenCalled();
  });

  it('uses English for users whose app is in English', async () => {
    notifications.getPreferredLocale.mockResolvedValue('en');

    await job.remind('t1');

    expect(notifications.create.mock.calls[0][0].title).toBe(
      'Reminder: your trip is in an hour',
    );
  });
});
