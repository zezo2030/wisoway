import { UsersService } from './users.service';

describe('UsersService.consumeOtpCode', () => {
  const build = (
    otp: { id: string; code: string; attempts: number } | null,
  ) => {
    const otpCodeRepo = {
      findOne: jest.fn().mockResolvedValue(otp),
      update: jest.fn().mockResolvedValue(undefined),
    };
    const service = new UsersService({} as never, otpCodeRepo as never);
    return { service, otpCodeRepo };
  };

  it('burns the code on a match', async () => {
    const { service, otpCodeRepo } = build({
      id: 'o1',
      code: '123456',
      attempts: 0,
    });
    await expect(
      service.consumeOtpCode('+962790000000', '123456'),
    ).resolves.toBe(true);
    expect(otpCodeRepo.update).toHaveBeenCalledWith('o1', { isUsed: true });
  });

  it('counts a wrong code without burning it', async () => {
    const { service, otpCodeRepo } = build({
      id: 'o1',
      code: '123456',
      attempts: 1,
    });
    await expect(
      service.consumeOtpCode('+962790000000', '000000'),
    ).resolves.toBe(false);
    expect(otpCodeRepo.update).toHaveBeenCalledWith('o1', {
      attempts: 2,
      isUsed: false,
    });
  });

  it('burns the code on the fifth wrong try', async () => {
    const { service, otpCodeRepo } = build({
      id: 'o1',
      code: '123456',
      attempts: 4,
    });
    await expect(
      service.consumeOtpCode('+962790000000', '000000'),
    ).resolves.toBe(false);
    expect(otpCodeRepo.update).toHaveBeenCalledWith('o1', {
      attempts: 5,
      isUsed: true,
    });
  });

  it('rejects when there is no live code', async () => {
    const { service } = build(null);
    await expect(
      service.consumeOtpCode('+962790000000', '123456'),
    ).resolves.toBe(false);
  });
});
