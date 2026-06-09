import {
  CallHandler,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { GqlExecutionContext } from '@nestjs/graphql';
import { Observable } from 'rxjs';
import { ComplianceService } from '../../compliance/compliance.service';
import { AuthUser } from '../decorators/current-user.decorator';

const GRAPHQL_ALLOWLIST = new Set([
  'myConsents',
  'grantConsent',
  'revokeConsent',
]);

const HTTP_PATH_PREFIXES = ['/auth', '/health', '/compliance'];

@Injectable()
export class HipaaConsentInterceptor implements NestInterceptor {
  constructor(private readonly compliance: ComplianceService) {}

  async intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<unknown>> {
    const user = this.resolveUser(context);
    if (!user || !this.requiresConsent(user)) {
      return next.handle();
    }

    if (context.getType<string>() === 'http') {
      const request = context.switchToHttp().getRequest<{
        path?: string;
        url?: string;
        originalUrl?: string;
      }>();
      const path = request.path ?? request.originalUrl ?? request.url ?? '';
      if (this.isAllowedHttpPath(path)) {
        return next.handle();
      }
    } else {
      const fieldName = this.graphqlFieldName(context);
      if (fieldName && this.isAllowedGraphqlField(fieldName)) {
        return next.handle();
      }
    }

    const hasConsent = await this.compliance.hasActiveHipaaConsent(user.id);
    if (!hasConsent) {
      throw new ForbiddenException(
        'HIPAA privacy consent is required before accessing clinical data',
      );
    }

    return next.handle();
  }

  private requiresConsent(user: AuthUser): boolean {
    const roles = user.roles ?? [];
    return roles.includes('PARENT') || roles.includes('THERAPIST');
  }

  private isAllowedHttpPath(path: string): boolean {
    const normalized = path.split('?')[0];
    return HTTP_PATH_PREFIXES.some(
      (prefix) =>
        normalized === prefix ||
        normalized.startsWith(`${prefix}/`) ||
        normalized.includes(`/api/v1${prefix}`),
    );
  }

  private isAllowedGraphqlField(fieldName: string): boolean {
    if (GRAPHQL_ALLOWLIST.has(fieldName)) return true;
    if (fieldName.startsWith('mfa')) return true;
    return fieldName === 'me';
  }

  private graphqlFieldName(context: ExecutionContext): string | undefined {
    if (context.getType<string>() !== 'graphql') return undefined;
    const info = GqlExecutionContext.create(context).getInfo<{
      fieldName?: string;
    }>();
    return info.fieldName;
  }

  private resolveUser(context: ExecutionContext): AuthUser | undefined {
    if (context.getType<string>() === 'graphql') {
      return GqlExecutionContext.create(context).getContext<{
        req: { user?: AuthUser };
      }>().req.user;
    }
    const request = context.switchToHttp().getRequest<{ user?: AuthUser }>();
    return request.user;
  }
}
