import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bull';
import { execSync } from 'child_process';
import helmet from 'helmet';
import { join } from 'path';
import { AppModule } from '../src/app.module';
import { GraphqlValidationPipe } from '../src/common/pipes/graphql-validation.pipe';

const globalSeedState = globalThis as typeof globalThis & {
  __abaconnectE2eSeeded?: boolean;
};

function ensureE2eSeedData(): void {
  if (globalSeedState.__abaconnectE2eSeeded) {
    return;
  }
  execSync('npx prisma migrate deploy', {
    cwd: join(__dirname, '..'),
    env: process.env,
    stdio: 'pipe',
  });
  execSync('npx prisma db seed', {
    cwd: join(__dirname, '..'),
    env: process.env,
    stdio: 'pipe',
  });
  globalSeedState.__abaconnectE2eSeeded = true;
}

export async function createE2eApp(): Promise<INestApplication> {
  ensureE2eSeedData();
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
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }),
    new GraphqlValidationPipe(),
  );
  app.setGlobalPrefix('api/v1');
  app.enableShutdownHooks();
  await app.init();
  return app;
}

export async function closeE2eApp(app: INestApplication): Promise<void> {
  await app.close();
}
