import * as bcrypt from 'bcrypt';
import { seedAdminUser } from './admin.seed';
import { PgUserRole } from '../../../database/entities/shared.enums';

/**
 * The dashboard is unreachable without an admin row, and nothing else creates
 * one, so this seed is the only way back in after the users table is emptied.
 * It has to write to Postgres — the store the app actually reads.
 */
describe('seedAdminUser', () => {
  const OLD_ENV = process.env;

  beforeEach(() => {
    process.env = { ...OLD_ENV };
    delete process.env.ADMIN_EMAIL;
    delete process.env.ADMIN_PASSWORD;
    delete process.env.ADMIN_PHONE;
    delete process.env.ADMIN_NAME;
  });

  afterAll(() => {
    process.env = OLD_ENV;
  });

  function repo(existing: unknown = null) {
    return {
      findOne: jest.fn().mockResolvedValue(existing),
      create: jest.fn((v: unknown) => v),
      save: jest.fn(async (v: unknown) => v),
    };
  }

  it('creates the admin when the table holds none', async () => {
    const userRepo = repo(null);

    const result = await seedAdminUser(userRepo as never);

    expect(result.created).toBe(true);
    expect(userRepo.findOne).toHaveBeenCalledWith({
      where: { role: PgUserRole.ADMIN },
    });
    expect(userRepo.save).toHaveBeenCalledTimes(1);

    const saved = userRepo.save.mock.calls[0][0] as Record<string, unknown>;
    expect(saved.role).toBe(PgUserRole.ADMIN);
    expect(saved.phoneNumber).toBe('+201000000000');
    expect(saved.isActive).toBe(true);
  });

  it('stores the password hashed, never in the clear', async () => {
    const userRepo = repo(null);

    await seedAdminUser(userRepo as never);

    const saved = userRepo.save.mock.calls[0][0] as Record<string, string>;
    expect(saved.passwordHash).not.toBe('Admin@123456');
    await expect(
      bcrypt.compare('Admin@123456', saved.passwordHash),
    ).resolves.toBe(true);
  });

  it('honours the environment overrides', async () => {
    process.env.ADMIN_PHONE = '+962790000000';
    process.env.ADMIN_PASSWORD = 'Str0ngPass!';
    process.env.ADMIN_NAME = 'Ops';
    const userRepo = repo(null);

    await seedAdminUser(userRepo as never);

    const saved = userRepo.save.mock.calls[0][0] as Record<string, string>;
    expect(saved.phoneNumber).toBe('+962790000000');
    expect(saved.name).toBe('Ops');
    await expect(bcrypt.compare('Str0ngPass!', saved.passwordHash)).resolves.toBe(
      true,
    );
  });

  it('leaves an existing admin alone', async () => {
    const userRepo = repo({ id: 'admin-1' });

    const result = await seedAdminUser(userRepo as never);

    expect(result.created).toBe(false);
    expect(userRepo.save).not.toHaveBeenCalled();
  });

  it('never logs the password', async () => {
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});
    await seedAdminUser(repo(null) as never);

    const printed = log.mock.calls.flat().join(' ');
    expect(printed).not.toContain('Admin@123456');
    log.mockRestore();
  });
});
