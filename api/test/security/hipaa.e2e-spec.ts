import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../../src/app.module';
import helmet from 'helmet';

describe('HIPAA Security (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.use(helmet());
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    app.setGlobalPrefix('api/v1');
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('sets security headers via helmet', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  it('rejects unauthenticated access to protected parent routes', async () => {
    await request(app.getHttpServer()).get('/api/v1/parents').expect(401);
  });
});
