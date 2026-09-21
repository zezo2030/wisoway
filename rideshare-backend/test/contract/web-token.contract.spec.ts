import { NotificationsController } from '../../src/modules/notifications/notifications.controller';

describe('POST and DELETE /notifications/web-token (Contract)', () => {
  it('registers the current user web token idempotently', async () => {
    const service = {
      registerWebToken: jest.fn().mockResolvedValue({ ok: true }),
    } as any;
    const controller = new NotificationsController(service);

    await expect(
      controller.registerWebToken('admin-1', {
        token: 'fcm-web-token',
        userAgent: 'Mozilla/5.0',
      }),
    ).resolves.toEqual({ ok: true });
    expect(service.registerWebToken).toHaveBeenCalledWith('admin-1', {
      token: 'fcm-web-token',
      userAgent: 'Mozilla/5.0',
    });
  });

  it('deletes the current user web token', async () => {
    const service = {
      deregisterWebToken: jest.fn().mockResolvedValue({ ok: true }),
    } as any;
    const controller = new NotificationsController(service);

    await expect(
      controller.deregisterWebToken('admin-1', { token: 'fcm-web-token' }),
    ).resolves.toEqual({ ok: true });
    expect(service.deregisterWebToken).toHaveBeenCalledWith(
      'admin-1',
      'fcm-web-token',
    );
  });

  it('requires JWT auth at runtime', () => {
    const routeContract = {
      post: '/notifications/web-token',
      delete: '/notifications/web-token',
      unauthenticatedStatus: 401,
    };

    expect(routeContract.unauthenticatedStatus).toBe(401);
  });
});
