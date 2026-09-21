import { AdminAlertsService } from '../../src/modules/admin/admin-alerts.service';
import { AdminAlertType, PgUserRole } from '../../src/database/entities';

function repository<T>(overrides: Partial<Record<string, jest.Mock>> = {}) {
  return {
    find: jest.fn(),
    findOne: jest.fn(),
    create: jest.fn((value: T) => value),
    save: jest.fn(async (value: T) => ({ id: 'notification-1', ...value })),
    ...overrides,
  } as any;
}

describe('AdminAlertsService (Integration)', () => {
  it('enqueues driver_registration only to opted-in admins and writes in-app fallback', async () => {
    const preferenceRepo = repository({
      find: jest.fn(async ({ where }: any) =>
        where?.enabled === false ? [{ userId: 'admin-disabled' }] : [],
      ),
    });
    const userRepo = repository({
      find: jest.fn(async () => [
        { id: 'admin-enabled' },
        { id: 'admin-disabled' },
      ]),
    });
    const notificationRepo = repository();
    const service = new AdminAlertsService(
      preferenceRepo,
      userRepo,
      notificationRepo,
      { emitToUser: jest.fn() } as any,
      {
        sendPush: jest.fn(async () => ({ successCount: 1, failureCount: 0 })),
      } as any,
    );

    await service.notifyDriverRegistration({
      id: 'driver-1',
      role: PgUserRole.DRIVER,
      name: 'Dana',
    } as any);

    expect(notificationRepo.save).toHaveBeenCalledTimes(1);
    expect(notificationRepo.save.mock.calls[0][0]).toMatchObject({
      userId: 'admin-enabled',
      type: 'admin_driver_registration',
      data: { link: '/users/driver-1', driverId: 'driver-1' },
    });
  });

  it('enqueues fee_payment for communication fees but excludes wallet top-ups and disabled prefs', async () => {
    const preferenceRepo = repository({
      find: jest.fn(async ({ where }: any) =>
        where?.alertType === AdminAlertType.FEE_PAYMENT &&
        where?.enabled === false
          ? [{ userId: 'admin-disabled' }]
          : [],
      ),
    });
    const notificationRepo = repository();
    const pushService = {
      sendPush: jest.fn(async () => ({ successCount: 1, failureCount: 0 })),
    };
    const service = new AdminAlertsService(
      preferenceRepo,
      repository({
        find: jest.fn(async () => [
          { id: 'admin-enabled' },
          { id: 'admin-disabled' },
        ]),
      }),
      notificationRepo,
      { emitToUser: jest.fn() } as any,
      pushService as any,
    );

    await service.notifyFeePayment({
      id: 'payment-1',
      amount: '5.00',
      currency: 'JOD',
      paymentType: 'communication_fee',
    });
    await service.notifyFeePayment({
      id: 'payment-2',
      amount: '25.00',
      currency: 'JOD',
      paymentType: 'wallet_topup',
    });

    expect(notificationRepo.save).toHaveBeenCalledTimes(1);
    expect(pushService.sendPush).toHaveBeenCalledWith(
      'admin-enabled',
      expect.objectContaining({
        type: 'admin_fee_payment',
        data: expect.objectContaining({
          link: '/payments',
          paymentId: 'payment-1',
        }),
        targetPlatforms: ['web'],
      }),
    );
  });
});
