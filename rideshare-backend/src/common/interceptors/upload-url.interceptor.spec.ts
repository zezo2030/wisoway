import { CallHandler, ExecutionContext } from '@nestjs/common';
import { lastValueFrom, of } from 'rxjs';
import { UploadUrlInterceptor } from './upload-url.interceptor';

describe('UploadUrlInterceptor', () => {
  const run = (body: unknown) => {
    const context = {
      getType: () => 'http',
      switchToHttp: () => ({
        getRequest: () => ({
          headers: { 'x-forwarded-proto': 'https' },
          get: () => 'vision-way.tech',
        }),
      }),
    } as unknown as ExecutionContext;
    const next = { handle: () => of(body) } as CallHandler;
    return lastValueFrom(new UploadUrlInterceptor().intercept(context, next));
  };

  it('points a stored upload at the host the client used', async () => {
    await expect(
      run({ url: 'http://localhost:3000/uploads/general/a.jpg' }),
    ).resolves.toEqual({
      url: 'https://vision-way.tech/uploads/general/a.jpg',
    });
  });

  it('points a signed private document at the host the client used', async () => {
    await expect(
      run({
        url: 'http://localhost:3003/api/v1/uploads/documents/1/abc/a.jpg',
      }),
    ).resolves.toEqual({
      url: 'https://vision-way.tech/api/v1/uploads/documents/1/abc/a.jpg',
    });
  });

  it('leaves other API links alone', async () => {
    const url = 'http://localhost:3003/api/v1/payments/1';
    await expect(run({ url })).resolves.toEqual({ url });
  });
});
