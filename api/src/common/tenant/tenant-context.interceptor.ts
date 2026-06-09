import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { GqlExecutionContext } from '@nestjs/graphql';
import { Observable } from 'rxjs';
import { AuthUser } from '../decorators/current-user.decorator';
import { tenantContextStorage } from './tenant-context';

@Injectable()
export class TenantContextInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const user = this.resolveUser(context);
    if (!user?.tenantId) {
      return next.handle();
    }
    return tenantContextStorage.run(
      { tenantId: user.tenantId, userId: user.id },
      () => next.handle(),
    );
  }

  private resolveUser(context: ExecutionContext): AuthUser | undefined {
    if (context.getType<string>() === 'graphql') {
      return GqlExecutionContext.create(context).getContext<{ req: { user?: AuthUser } }>()
        .req.user;
    }
    const request = context.switchToHttp().getRequest<{ user?: AuthUser }>();
    return request.user;
  }
}
