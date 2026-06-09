import { ArgumentMetadata, Injectable, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { GraphqlValidationPipe } from './common/pipes/graphql-validation.pipe';
import { validateProductionEnv } from './config/validate-env';

/** Skip whitelist validation for GraphQL @Args() and @InputType() classes. */
@Injectable()
class HttpValidationPipe extends ValidationPipe {
  async transform(value: unknown, metadata: ArgumentMetadata) {
    if (metadata.type === 'custom') {
      return value;
    }
    const gqlClassType =
      metadata.metatype &&
      Reflect.getMetadata('graphql:class_type', metadata.metatype);
    if (gqlClassType) {
      return value;
    }
    return super.transform(value, metadata);
  }
}

function parseCorsOrigins(): string[] | boolean {
  const raw = process.env.CORS_ORIGINS?.trim();
  if (!raw) {
    return process.env.NODE_ENV === 'production' ? false : true;
  }
  return raw
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

async function bootstrap() {
  validateProductionEnv();
  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.use(
    helmet({
      contentSecurityPolicy: process.env.NODE_ENV === 'production',
    }),
  );
  app.enableCors({
    origin: parseCorsOrigins(),
    credentials: true,
  });
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new HttpValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
    new GraphqlValidationPipe(),
  );
  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');
  console.log(
    `API listening on http://0.0.0.0:${port} (emulator: http://10.0.2.2:${port})`,
  );
}
bootstrap();
