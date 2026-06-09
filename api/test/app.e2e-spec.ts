import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { closeE2eApp, createE2eApp } from './e2e-app.util';

describe('API (e2e)', () => {
  let app: INestApplication | undefined;

  beforeAll(async () => {
    app = await createE2eApp();
  });

  afterAll(async () => {
    if (app) {
      await closeE2eApp(app);
    }
  });

  it('/api/v1/health (GET)', async () => {
    await request(app!.getHttpServer()).get('/api/v1/health').expect(200);
  });

  it('sets security headers via helmet', async () => {
    const res = await request(app!.getHttpServer()).get('/api/v1');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  it('rejects unauthenticated access to protected parent routes', async () => {
    await request(app!.getHttpServer()).get('/api/v1/parents').expect(401);
  });
});
