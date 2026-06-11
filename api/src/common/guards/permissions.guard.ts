import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { GqlExecutionContext } from '@nestjs/graphql';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { AuthUser } from '../decorators/current-user.decorator';
import { Permission, roleHasPermission } from '../../security/permissions';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<Permission[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!required?.length) return true;

    const user = this.getUser(context);
    const roles = user?.roles ?? [];
    const allowed = required.some((perm) =>
      roles.some((role) => roleHasPermission(role, perm)),
    );
    if (!allowed) {
      throw new ForbiddenException('Insufficient permissions for this action');
    }
    return true;
  }

  private getUser(context: ExecutionContext): AuthUser | undefined {
    if (context.getType<string>() === 'graphql') {
      return GqlExecutionContext.create(context).getContext<{
        req: { user?: AuthUser };
      }>().req.user;
    }
    return context.switchToHttp().getRequest<{ user?: AuthUser }>().user;
  }
}
