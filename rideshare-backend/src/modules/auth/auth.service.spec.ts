import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { getRepositoryToken } from '@nestjs/typeorm';
import * as jwt from 'jsonwebtoken';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { DeviceFingerprintService } from './device-fingerprint.service';
import { AccountRiskService } from './account-risk.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AdminAlertsService } from '../admin/admin-alerts.service';
import { UserEntity } from '../../database/entities/user.entity';
import { VehicleEntity } from '../../database/entities/vehicle.entity';
import { PasswordResetSessionEntity } from '../../database/entities/password-reset-session.entity';
import { PgUserRole } from '../../database/entities/shared.enums';
import { DRIVER_REGISTRATION_TOKEN_PURPOSE } from './dto/register-driver.dto';

const JWT_SECRET = 'test-access-secret';

describe('AuthService — driver registration', () => {
  let service: AuthService;
  let vehicleCreate: jest.Mock;
  let vehicleSave: jest.Mock;
  let userRepo: {
    find: jest.Mock;
    findOne: jest.Mock;
    manager: { transaction: jest.Mock };
  };

  const registrationToken = () =>
    jwt.sign(
      { phone: '+962790000000', purpose: DRIVER_REGISTRATION_TOKEN_PURPOSE },
      JWT_SECRET,
      { expiresIn: 600 },
    );

  const baseDto = {
    name: 'Driver',
    password: 'Password1',
    vehicleType: 'sedan',
    plateNumber: 'ABC123',
    model: 'Camry',
    seats: 4,
    carImageUrl: 'https://cdn/car.jpg',
    licenseImageUrl: 'https://cdn/lic.jpg',
    vehicleLicenseImageUrl: 'https://cdn/form.jpg',
    insuranceImageUrl: 'https://cdn/ins.jpg',
  };

  beforeEach(async () => {
    vehicleCreate = jest.fn((v: Partial<VehicleEntity>) => v);
    vehicleSave = jest.fn((v: Partial<VehicleEntity>) => Promise.resolve(v));

    userRepo = {
      // No admins → notifyAdminsOfNewUser short-circuits.
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn(),
      manager: {
        transaction: jest.fn((cb: (em: unknown) => Promise<unknown>) =>
          cb({
            getRepository: (entity: unknown) =>
              entity === VehicleEntity
                ? {
                    create: vehicleCreate,
                    save: vehicleSave,
                    findOne: jest.fn(),
                  }
                : {
                    create: (u: Partial<UserEntity>) => u,
                    save: (u: Partial<UserEntity>) =>
                      Promise.resolve({ id: 'user-1', ...u }),
                    findOne: jest.fn(),
                  },
          }),
        ),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: UsersService,
          useValue: {
            findByPhone: jest.fn().mockResolvedValue(null),
            findById: jest.fn(),
            updateRefreshToken: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) =>
              key === 'JWT_ACCESS_SECRET' || key === 'JWT_REFRESH_SECRET'
                ? JWT_SECRET
                : undefined,
            ),
          },
        },
        { provide: DeviceFingerprintService, useValue: { hash: jest.fn() } },
        { provide: AccountRiskService, useValue: {} },
        { provide: NotificationsService, useValue: { create: jest.fn() } },
        {
          provide: AdminAlertsService,
          useValue: {
            notifyDriverRegistration: jest.fn().mockResolvedValue(undefined),
          },
        },
        { provide: getRepositoryToken(UserEntity), useValue: userRepo },
        {
          provide: getRepositoryToken(PasswordResetSessionEntity),
          useValue: {},
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  it('persists insuranceImageUrl on the vehicle', async () => {
    await service.registerDriver({
      ...baseDto,
      registrationToken: registrationToken(),
    } as never);

    expect(vehicleCreate).toHaveBeenCalledWith(
      expect.objectContaining({ insuranceImageUrl: 'https://cdn/ins.jpg' }),
    );
  });

  it('stores a null insurance url when the client omits it', async () => {
    const { insuranceImageUrl: _omitted, ...withoutInsurance } = baseDto;

    await service.registerDriver({
      ...withoutInsurance,
      registrationToken: registrationToken(),
    } as never);

    expect(vehicleCreate).toHaveBeenCalledWith(
      expect.objectContaining({ insuranceImageUrl: null }),
    );
  });
});

describe('AuthService — pending driver registration update', () => {
  let service: AuthService;
  let user: Partial<UserEntity>;
  let vehicle: Partial<VehicleEntity>;
  let userSave: jest.Mock;
  let vehicleSave: jest.Mock;

  const buildService = async (userRow: Partial<UserEntity> | null) => {
    user = userRow as Partial<UserEntity>;
    vehicle = {
      id: 'vehicle-1',
      driverId: 'user-1',
      vehicleType: 'sedan',
      plateNumber: 'OLD1',
      model: 'Camry',
      seats: 4,
      insuranceImageUrl: null,
      carImageUrl: 'https://cdn/car.jpg',
    };
    userSave = jest.fn((u: Partial<UserEntity>) => Promise.resolve(u));
    vehicleSave = jest.fn((v: Partial<VehicleEntity>) => Promise.resolve(v));

    const userRepo = {
      findOne: jest.fn().mockResolvedValue(userRow),
      manager: {
        transaction: jest.fn((cb: (em: unknown) => Promise<unknown>) =>
          cb({
            getRepository: (entity: unknown) =>
              entity === VehicleEntity
                ? {
                    findOne: jest.fn().mockResolvedValue(vehicle),
                    save: vehicleSave,
                  }
                : { save: userSave },
          }),
        ),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: {} },
        {
          provide: ConfigService,
          useValue: { get: jest.fn().mockReturnValue(JWT_SECRET) },
        },
        { provide: DeviceFingerprintService, useValue: {} },
        { provide: AccountRiskService, useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: AdminAlertsService, useValue: {} },
        { provide: getRepositoryToken(UserEntity), useValue: userRepo },
        {
          provide: getRepositoryToken(PasswordResetSessionEntity),
          useValue: {},
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  };

  it('updates vehicle docs when driver is not approved', async () => {
    await buildService({
      id: 'user-1',
      role: PgUserRole.DRIVER,
      isDriverApproved: false,
    });

    await service.updatePendingRegistration('user-1', {
      insuranceImageUrl: 'https://cdn/new-ins.jpg',
      plateNumber: 'NEW1',
    });

    expect(vehicle.insuranceImageUrl).toBe('https://cdn/new-ins.jpg');
    expect(vehicle.plateNumber).toBe('NEW1');
    expect(vehicleSave).toHaveBeenCalled();
    expect(user.isDriverApproved).toBe(false);
  });

  it('rejects when driver already approved', async () => {
    await buildService({
      id: 'user-1',
      role: PgUserRole.DRIVER,
      isDriverApproved: true,
    });

    await expect(
      service.updatePendingRegistration('user-1', { model: 'X' }),
    ).rejects.toThrow(/approved/i);
  });

  it('rejects an empty payload', async () => {
    await buildService({
      id: 'user-1',
      role: PgUserRole.DRIVER,
      isDriverApproved: false,
    });

    await expect(
      service.updatePendingRegistration('user-1', {}),
    ).rejects.toThrow(/at least one field/i);
  });

  it('rejects non-driver accounts', async () => {
    await buildService({
      id: 'user-1',
      role: PgUserRole.PASSENGER,
      isDriverApproved: false,
    });

    await expect(
      service.updatePendingRegistration('user-1', { model: 'X' }),
    ).rejects.toThrow(/driver/i);
  });
});

describe('AuthService — local OTP', () => {
  it('stores the code and writes it to the log instead of sending SMS', async () => {
    const createOtpCode = jest.fn().mockResolvedValue({ id: 'otp-1' });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: UsersService,
          useValue: { createOtpCode },
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) =>
              key === 'OTP_PROVIDER' || key === 'twilio.OTP_PROVIDER'
                ? 'local'
                : undefined,
            ),
          },
        },
        { provide: DeviceFingerprintService, useValue: {} },
        { provide: AccountRiskService, useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: AdminAlertsService, useValue: {} },
        { provide: getRepositoryToken(UserEntity), useValue: {} },
        {
          provide: getRepositoryToken(PasswordResetSessionEntity),
          useValue: {},
        },
      ],
    }).compile();

    const service = module.get<AuthService>(AuthService);
    const result = await service.sendOtp({ phoneNumber: '+962790000000' });

    expect(result.message).toBe('OTP sent successfully');
    expect(createOtpCode).toHaveBeenCalledTimes(1);
    expect(createOtpCode).toHaveBeenCalledWith(
      '+962790000000',
      expect.stringMatching(/^\d{6}$/),
    );
  });
});

/**
 * The app offers "sign in with your phone number" as a first-class action, so a
 * correct OTP has to be able to sign an existing account in. It previously
 * rejected anyone who already had a password, which left that button unable to
 * sign anybody in.
 */
describe('AuthService — OTP sign-in for existing accounts', () => {
  const PHONE = '+962790000001';

  async function arrange(user: Partial<UserEntity> | null) {
    const userRepo = {
      createQueryBuilder: jest.fn().mockReturnValue({
        addSelect: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(user),
      }),
      update: jest.fn().mockResolvedValue(undefined),
    };
    const usersService = {
      findOtpCode: jest.fn().mockResolvedValue({ id: 'otp-1' }),
      markOtpCodeAsUsed: jest.fn().mockResolvedValue(undefined),
      verifyOtpCode: jest.fn().mockResolvedValue(true),
      findById: jest.fn().mockResolvedValue(user),
      findByPhone: jest.fn().mockResolvedValue(user),
      linkPhone: jest.fn().mockResolvedValue(user),
      create: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: usersService },
        {
          provide: ConfigService,
          useValue: { get: jest.fn(() => 'local') },
        },
        { provide: DeviceFingerprintService, useValue: {} },
        { provide: AccountRiskService, useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: AdminAlertsService, useValue: {} },
        { provide: getRepositoryToken(UserEntity), useValue: userRepo },
        {
          provide: getRepositoryToken(PasswordResetSessionEntity),
          useValue: {},
        },
      ],
    }).compile();

    const service = module.get<AuthService>(AuthService);
    jest
      .spyOn(service as any, 'generateTokens')
      .mockResolvedValue({ accessToken: 'a', refreshToken: 'r' });
    return { service, userRepo, usersService };
  }

  const existing = {
    id: 'user-1',
    phoneNumber: PHONE,
    name: 'Existing',
    passwordHash: 'already-hashed',
    isPhoneVerified: true,
    isActive: true,
  } as Partial<UserEntity>;

  it('signs in an existing account when the OTP is correct', async () => {
    const { service } = await arrange(existing);

    const result = await service.verifyOtp({ phoneNumber: PHONE, code: '123456' });

    expect(result.accessToken).toBe('a');
    expect(result.user.id).toBe('user-1');
    expect(result.accountState).toBe('active');
  });

  it('never overwrites an existing password with one sent alongside the OTP', async () => {
    const { service, userRepo } = await arrange(existing);

    await service.verifyOtp({
      phoneNumber: PHONE,
      code: '123456',
      password: 'AttackerPass1',
    } as any);

    expect(userRepo.update).not.toHaveBeenCalled();
  });

  it('still reports a banned account rather than signing it in silently', async () => {
    const { service } = await arrange({ ...existing, bannedAt: new Date() });

    const result = await service.verifyOtp({ phoneNumber: PHONE, code: '123456' });

    expect(result.accountState).toBe('banned');
  });

  it('still finishes setup for an account that has no password yet', async () => {
    const { service, userRepo } = await arrange({
      ...existing,
      passwordHash: null,
    });

    await service.verifyOtp({
      phoneNumber: PHONE,
      code: '123456',
      password: 'NewPass1234',
    } as any);

    expect(userRepo.update).toHaveBeenCalledTimes(1);
  });
});
