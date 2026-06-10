import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { closeE2eApp, createE2eApp } from './e2e-app.util';

/** Matches the trusted device seeded for demo users in prisma/seed.ts. */
const DEMO_DEVICE_HEADERS = {
  'x-device-id': 'smoke-ci-device',
  'x-device-model': 'CI smoke runner',
  'x-device-platform': 'ci',
};

function loginDemoParent(app: INestApplication) {
  return request(app.getHttpServer())
    .post('/api/v1/auth/login')
    .set(DEMO_DEVICE_HEADERS)
    .send({ email: 'parent@demo.local', password: 'Parent123!' });
}

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

  it('locks account after repeated failed logins', async () => {
    const email = `lockout-${Date.now()}@example.com`;
    await request(app!.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email,
        password: 'SecurePass1!',
        firstName: 'Lock',
        lastName: 'Test',
        role: 'PARENT',
      })
      .expect(201);

    for (let i = 0; i < 5; i++) {
      await request(app!.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email, password: 'WrongPass1!' })
        .expect(401);
    }

    await request(app!.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email, password: 'SecurePass1!' })
      .expect(401);
  });

  it('blocks scaffold REST PHI endpoints for authenticated users', async () => {
    const login = await loginDemoParent(app!).expect(201);

    const token = login.body.accessToken as string;
    expect(token).toBeDefined();
    await request(app!.getHttpServer())
      .get('/api/v1/children')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
    await request(app!.getHttpServer())
      .get('/api/v1/screenings')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);

    // Demo parent is fully onboarded (consent + MFA); unknown doc id → 404.
    await request(app!.getHttpServer())
      .get('/api/v1/documents/00000000-0000-4000-8000-000000000001/file')
      .set('Authorization', `Bearer ${token}`)
      .expect(404);

    const report = await request(app!.getHttpServer())
      .get('/api/v1/compliance/me/phi-access-report')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(report.body).toHaveProperty('documentAccess');
    expect(report.body).toHaveProperty('phiAuditEntries');
  });

  it('rejects privileged roles on public registration', async () => {
    const email = `blocked-admin-${Date.now()}@example.com`;
    await request(app!.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email,
        password: 'SecurePass1!',
        firstName: 'Bad',
        lastName: 'Actor',
        role: 'PLATFORM_ADMIN',
      })
      .expect(400);
  });

  it('revokes refresh tokens on logout', async () => {
    const login = await loginDemoParent(app!).expect(201);

    const accessToken = login.body.accessToken as string;
    const refreshToken = login.body.refreshToken as string;

    await request(app!.getHttpServer())
      .post('/api/v1/auth/logout')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(201);

    await request(app!.getHttpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken })
      .expect(401);
  });

  it('exposes audit logs read-only for platform admins', async () => {
    const login = await request(app!.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: 'admin@abaconnect.local', password: 'Admin123!' })
      .expect(201);

    const token = login.body.accessToken as string;
    const list = await request(app!.getHttpServer())
      .get('/api/v1/audit')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(Array.isArray(list.body)).toBe(true);

    await request(app!.getHttpServer())
      .patch('/api/v1/audit/00000000-0000-4000-8000-000000000099')
      .set('Authorization', `Bearer ${token}`)
      .send({ action: 'TAMPER' })
      .expect(404);

    await request(app!.getHttpServer())
      .delete('/api/v1/audit/00000000-0000-4000-8000-000000000099')
      .set('Authorization', `Bearer ${token}`)
      .expect(404);
  });

  it('exposes security events for platform admins', async () => {
    const login = await request(app!.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: 'admin@abaconnect.local', password: 'Admin123!' })
      .expect(201);

    const token = login.body.accessToken as string;
    const events = await request(app!.getHttpServer())
      .get('/api/v1/security/events')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(Array.isArray(events.body)).toBe(true);
  });

  it('requires HIPAA consent for protected REST endpoints', async () => {
    const email = `noconsent-${Date.now()}@example.com`;
    const register = await request(app!.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email,
        password: 'SecurePass1!',
        firstName: 'No',
        lastName: 'Consent',
        role: 'PARENT',
      })
      .expect(201);

    const token = register.body.accessToken as string;
    await request(app!.getHttpServer())
      .get('/api/v1/documents/00000000-0000-4000-8000-000000000001/file')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

});
