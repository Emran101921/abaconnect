import { ArgumentMetadata, Injectable, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module';

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

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.use(helmet({ contentSecurityPolicy: false }));
  app.enableCors({ origin: true, credentials: true });
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new HttpValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
