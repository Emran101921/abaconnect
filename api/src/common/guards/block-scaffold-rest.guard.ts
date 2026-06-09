import {
  CanActivate,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

/** Blocks legacy REST CRUD scaffolds; PHI must use role-scoped GraphQL. */
@Injectable()
export class BlockScaffoldRestGuard implements CanActivate {
  canActivate(): boolean {
    throw new ForbiddenException(
      'This REST endpoint is disabled. Use the GraphQL API.',
    );
  }
}
