import { ForbiddenException } from '@nestjs/common';
import { UsersController } from './users.controller';
import { PgUserRole } from '../../database/entities/shared.enums';

describe('GET /users/:id', () => {
  const record = { id: 'u1', phoneNumber: '+962700000000' };
  const usersService = { findById: jest.fn().mockResolvedValue(record) };
  const controller = new UsersController(usersService as never);

  beforeEach(() => usersService.findById.mockClear());

  it('answers the account itself', async () => {
    await expect(
      controller.getUserById('u1', { id: 'u1', role: PgUserRole.PASSENGER }),
    ).resolves.toBe(record);
  });

  it('answers an admin', async () => {
    await expect(
      controller.getUserById('u1', { id: 'a1', role: PgUserRole.ADMIN }),
    ).resolves.toBe(record);
  });

  it.each([PgUserRole.PASSENGER, PgUserRole.DRIVER])(
    "refuses a %s another user's account",
    async (role) => {
      await expect(
        controller.getUserById('u1', { id: 'u2', role }),
      ).rejects.toThrow(ForbiddenException);
      expect(usersService.findById).not.toHaveBeenCalled();
    },
  );
});
