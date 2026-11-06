import { ConflictException, ForbiddenException } from '@nestjs/common';
import { UsersService } from './users.service';
import { PgUserRole } from '../../database/entities/shared.enums';

describe('UsersService.update — name and email are final', () => {
  const build = (
    account: { name?: string; email?: string | null },
    emailOwner: unknown = null,
  ) => {
    const user = {
      id: 'u1',
      role: PgUserRole.PASSENGER,
      phoneNumber: '+962790000000',
      name: 'Mohammad Khader',
      email: 'mohammad@example.com' as string | null,
      ...account,
    };
    const userRepo = {
      findOne: jest.fn().mockResolvedValue(user),
      merge: jest.fn((target: object, values: object) =>
        Object.assign(target, values),
      ),
      save: jest.fn((saved: unknown) => Promise.resolve(saved)),
      createQueryBuilder: () => ({
        where: () => ({ getOne: () => Promise.resolve(emailOwner) }),
      }),
    };
    const service = new UsersService(userRepo as never, {} as never);
    return { service, userRepo, user };
  };

  it('refuses a new name', async () => {
    const { service, userRepo } = build({});
    await expect(
      service.update('u1', { name: 'Someone Else' }),
    ).rejects.toThrow(ForbiddenException);
    expect(userRepo.save).not.toHaveBeenCalled();
  });

  it('accepts the same name, which older apps send on every save', async () => {
    const { service, user } = build({});
    await service.update('u1', { name: 'Mohammad Khader', gender: 'male' });
    expect(user.name).toBe('Mohammad Khader');
  });

  it('lets a phone-number placeholder become a real name', async () => {
    const { service, user } = build({ name: '+962790000000' });
    await service.update('u1', { name: 'Mohammad Khader' });
    expect(user.name).toBe('Mohammad Khader');
  });

  it('refuses a different email once one is set', async () => {
    const { service, userRepo } = build({});
    await expect(
      service.update('u1', { email: 'other@example.com' }),
    ).rejects.toThrow(ForbiddenException);
    expect(userRepo.save).not.toHaveBeenCalled();
  });

  it('lets an account with no email add one', async () => {
    const { service, user } = build({ email: null });
    await service.update('u1', { email: 'new@example.com' });
    expect(user.email).toBe('new@example.com');
  });

  it('refuses an email another account already uses', async () => {
    const { service, userRepo } = build({ email: null }, { id: 'u2' });
    await expect(
      service.update('u1', { email: 'taken@example.com' }),
    ).rejects.toThrow(ConflictException);
    expect(userRepo.save).not.toHaveBeenCalled();
  });
});
