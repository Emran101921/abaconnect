import { ExecutionContext, Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * ThrottlerGuard for the global APP_GUARD slot.
 *
 * GraphQL runs through a single POST /graphql endpoint and its context does
 * not expose an Express response (no `res.header`), which makes the stock
 * guard throw. Rate-limit-sensitive flows (login, register, reset, MFA) are
 * all REST endpoints, so we skip throttling for GraphQL operations.
 */
@Injectable()
export class AppThrottlerGuard extends ThrottlerGuard {
  protected async shouldSkip(context: ExecutionContext): Promise<boolean> {
    return context.getType<string>() === 'graphql';
  }
}
