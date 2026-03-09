import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const CurrentUser = createParamDecorator(
  (data: string | undefined, ctx: ExecutionContext) => {
    const type = ctx.getType<'http' | 'ws' | 'rpc'>();
    const user =
      type === 'http'
        ? ctx.switchToHttp().getRequest()?.user
        : ctx.switchToWs().getClient()?.user;

    if (!data) {
      return user;
    }

    // Common controllers request "id", while mongoose user objects often expose "_id".
    if (data === 'id') {
      const idValue = user?.id ?? user?._id;
      return typeof idValue === 'string' ? idValue : idValue?.toString?.();
    }

    return user?.[data];
  },
);
