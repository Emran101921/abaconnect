import { ArgumentMetadata, Injectable, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { CLASS_TYPE_METADATA } from '@nestjs/graphql/dist/graphql.constants';
import helmet from 'helmet';
import { AppModule } from './app.module';

/** Skip class-validator whitelist for GraphQL @Args() and @InputType() classes. */
@Injectable()
class HttpValidationPipe extends ValidationPipe {
  async transform(value: unknown, metadata: ArgumentMetadata) {
    if (metadata.type !== 'body' && metadata.type !== 'query' && metadata.type !== 'param') {
      return value;
    }
    if (
      metadata.metatype &&
      Reflect.getMetadata(CLASS_TYPE_METADATA, metadata.metatype)
    ) {
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
