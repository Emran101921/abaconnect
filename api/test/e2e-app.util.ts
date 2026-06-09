import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bull';
import helmet from 'helmet';
import { AppModule } from '../src/app.module';

export async function createE2eApp(): Promise<INestApplication> {
  const moduleFixture: TestingModule = await Test.createTestingModule({
    imports: [AppModule],
  })
    .overrideProvider(getQueueToken('push'))
    .useValue({
      add: jest.fn(),
      process: jest.fn(),
      close: jest.fn().mockResolvedValue(undefined),
    })
    .compile();

  const app = moduleFixture.createNestApplication();
  app.use(helmet({ contentSecurityPolicy: false }));
  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
  app.setGlobalPrefix('api/v1');
  app.enableShutdownHooks();
  await app.init();
  return app;
}

export async function closeE2eApp(app: INestApplication): Promise<void> {
  await app.close();
}
