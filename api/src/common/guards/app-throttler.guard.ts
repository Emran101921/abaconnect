import { ExecutionContext, Injectable } from '@nestjs/common';
import { GqlExecutionContext } from '@nestjs/graphql';
import { ThrottlerGuard } from '@nestjs/throttler';

/** ThrottlerGuard with GraphQL request context support (global APP_GUARD). */
@Injectable()
export class AppThrottlerGuard extends ThrottlerGuard {
  protected getRequestResponse(context: ExecutionContext): {
    req: Record<string, unknown>;
    res: Record<string, unknown>;
  } {
    if (context.getType<string>() === 'graphql') {
      const gqlCtx = GqlExecutionContext.create(context).getContext<{
        req?: Record<string, unknown>;
        res?: Record<string, unknown>;
      }>();
      return {
        req: gqlCtx.req ?? {},
        res: gqlCtx.res ?? {},
      };
    }
    return super.getRequestResponse(context);
  }

  protected async getTracker(req: Record<string, unknown>): Promise<string> {
    const ip = req.ip;
    return typeof ip === 'string' && ip.length > 0 ? ip : 'unknown';
  }
}
