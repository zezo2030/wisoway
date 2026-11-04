import {
  ArgumentsHost,
  ForbiddenException,
  HttpStatus,
  NotFoundException,
} from '@nestjs/common';
import { HttpExceptionFilter } from './http-exception.filter';

function run(exception: unknown) {
  const json = jest.fn();
  const status = jest.fn().mockReturnValue({ json });
  const host = {
    switchToHttp: () => ({
      getResponse: () => ({ status }),
      getRequest: () => ({ url: '/x', method: 'POST' }),
    }),
  } as unknown as ArgumentsHost;

  new HttpExceptionFilter().catch(exception, host);

  return {
    status: status.mock.calls[0][0] as number,
    body: json.mock.calls[0][0] as Record<string, any>,
  };
}

describe('HttpExceptionFilter', () => {
  it('passes a business code to clients at the top of the body', () => {
    const { status, body } = run(
      new ForbiddenException({ code: 'PHONE_HIDDEN', message: 'hidden' }),
    );

    expect(status).toBe(HttpStatus.FORBIDDEN);
    expect(body.code).toBe('PHONE_HIDDEN');
    expect(body.error.code).toBe(HttpStatus.FORBIDDEN);
    expect(body.error.message).toBe('hidden');
  });

  it('passes the fields a client reads alongside the code', () => {
    const { body } = run(
      new ForbiddenException({
        code: 'ACCOUNT_BANNED',
        message: 'banned',
        banReason: 'fraud',
        supportWhatsApp: '+966500000000',
      }),
    );

    expect(body.banReason).toBe('fraud');
    expect(body.supportWhatsApp).toBe('+966500000000');
  });

  it('adds nothing for an exception without a code', () => {
    const { body } = run(new NotFoundException('missing'));

    expect(Object.keys(body).sort()).toEqual(['error', 'success']);
  });
});
