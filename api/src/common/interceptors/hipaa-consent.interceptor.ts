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
import { ProviderOnboardingService } from '../../compliance/provider-onboarding.service';
import { AuthUser } from '../decorators/current-user.decorator';

const ONBOARDING_ROLES = new Set(['PARENT', 'THERAPIST', 'AGENCY_ADMIN']);

const GRAPHQL_ALLOWLIST = new Set([
  'myConsents',
  'grantConsent',
  'revokeConsent',
]);

const HTTP_PATH_PREFIXES = ['/auth', '/health', '/compliance'];

@Injectable()
export class HipaaConsentInterceptor implements NestInterceptor {
  constructor(
    private readonly compliance: ComplianceService,
    private readonly providerOnboarding: ProviderOnboardingService,
  ) {}

  async intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<unknown>> {
    const user = this.resolveUser(context);
    if (!user || !this.requiresOnboarding(user)) {
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
        'You must acknowledge the Notice of Privacy Practices before accessing clinical data',
      );
    }

    const mfaEnabled = await this.compliance.hasMfaEnabled(user.id);
    if (!mfaEnabled) {
      throw new ForbiddenException(
        'Two-factor authentication must be enabled before accessing clinical data',
      );
    }

    await this.providerOnboarding.assertPhiAccess(
      user.id,
      user.roles ?? [],
    );

    return next.handle();
  }

  private requiresOnboarding(user: AuthUser): boolean {
    const roles = user.roles ?? [];
    return roles.some((role) => ONBOARDING_ROLES.has(role));
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
