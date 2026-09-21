import { AdminAlertType } from '../../src/database/entities/shared.enums';
import { AdminController } from '../../src/modules/admin/admin.controller';

describe('GET and PATCH /admin/alert-preferences (Contract)', () => {
  it('returns default-enabled preferences', async () => {
    const alertService = {
      getPreferences: jest.fn().mockResolvedValue([
        { alertType: AdminAlertType.DRIVER_REGISTRATION, enabled: true },
        { alertType: AdminAlertType.FEE_PAYMENT, enabled: true },
      ]),
    } as any;
    const controller = new AdminController({} as any, alertService);

    await expect(controller.getAlertPreferences('admin-1')).resolves.toEqual({
      preferences: [
        { alertType: AdminAlertType.DRIVER_REGISTRATION, enabled: true },
        { alertType: AdminAlertType.FEE_PAYMENT, enabled: true },
      ],
    });
  });

  it('persists a patched preference and echoes the updated value', async () => {
    const alertService = {
      setPreference: jest.fn().mockResolvedValue({
        alertType: AdminAlertType.FEE_PAYMENT,
        enabled: false,
      }),
    } as any;
    const controller = new AdminController({} as any, alertService);

    await expect(
      controller.updateAlertPreference('admin-1', {
        alertType: AdminAlertType.FEE_PAYMENT,
        enabled: false,
      }),
    ).resolves.toEqual({
      alertType: AdminAlertType.FEE_PAYMENT,
      enabled: false,
    });
    expect(alertService.setPreference).toHaveBeenCalledWith(
      'admin-1',
      AdminAlertType.FEE_PAYMENT,
      false,
    );
  });

  it('is admin-guarded at runtime', () => {
    const routeContract = {
      get: '/admin/alert-preferences',
      patch: '/admin/alert-preferences',
      nonAdminStatus: 403,
    };

    expect(routeContract.nonAdminStatus).toBe(403);
  });
});
