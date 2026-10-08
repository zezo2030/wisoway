import { ForbiddenException } from '@nestjs/common';
import { UsersService } from './users.service';
import { PgUserRole } from '../../database/entities/shared.enums';

describe('UsersService.requestOwnRole (PATCH /users/me/role)', () => {
  const build = (role: PgUserRole) => {
    const user = { id: 'u1', role };
    const userRepo = {
      findOne: jest.fn().mockResolvedValue(user),
      save: jest.fn(),
    };
    const service = new UsersService(userRepo as never, {} as never);
    return { service, userRepo, user };
  };

  it.each([PgUserRole.PASSENGER, PgUserRole.DRIVER])(
    'never lets a %s make themselves an admin',
    async (role) => {
      const { service, userRepo } = build(role);
      await expect(service.requestOwnRole('u1', 'admin')).rejects.toThrow(
        ForbiddenException,
      );
      expect(userRepo.save).not.toHaveBeenCalled();
    },
  );

  it('does not turn a passenger into a driver (that needs a vehicle and approval)', async () => {
    const { service, userRepo } = build(PgUserRole.PASSENGER);
    await expect(service.requestOwnRole('u1', 'driver')).rejects.toThrow(
      ForbiddenException,
    );
    expect(userRepo.save).not.toHaveBeenCalled();
  });

  it('answers "passenger" with the account unchanged, even for a driver', async () => {
    const { service, userRepo, user } = build(PgUserRole.DRIVER);
    await expect(service.requestOwnRole('u1', 'passenger')).resolves.toBe(user);
    expect(user.role).toBe(PgUserRole.DRIVER);
    expect(userRepo.save).not.toHaveBeenCalled();
  });
});
