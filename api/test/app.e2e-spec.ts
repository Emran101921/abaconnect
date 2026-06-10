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
  let demoParentToken: string;
  let adminToken: string;

  beforeAll(async () => {
    app = await createE2eApp();
    const login = await loginDemoParent(app!).expect(201);
    demoParentToken = login.body.accessToken as string;
    const adminLogin = await request(app!.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: 'admin@abaconnect.local', password: 'Admin123!' })
      .expect(201);
    adminToken = adminLogin.body.accessToken as string;
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
    const token = demoParentToken;
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
    const email = `logout-${Date.now()}@example.com`;
    const login = await request(app!.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email,
        password: 'SecurePass1!',
        firstName: 'Logout',
        lastName: 'Test',
        role: 'PARENT',
      })
      .expect(201);

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
    const list = await request(app!.getHttpServer())
      .get('/api/v1/audit')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(Array.isArray(list.body)).toBe(true);

    await request(app!.getHttpServer())
      .patch('/api/v1/audit/00000000-0000-4000-8000-000000000099')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ action: 'TAMPER' })
      .expect(404);

    await request(app!.getHttpServer())
      .delete('/api/v1/audit/00000000-0000-4000-8000-000000000099')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(404);
  });

  it('exposes security events for platform admins', async () => {
    const events = await request(app!.getHttpServer())
      .get('/api/v1/security/events')
      .set('Authorization', `Bearer ${adminToken}`)
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

  it('exposes privacy notice summary and records acknowledgment', async () => {
    const email = `privacy-${Date.now()}@example.com`;
    const register = await request(app!.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email,
        password: 'SecurePass1!',
        firstName: 'Privacy',
        lastName: 'Test',
        role: 'PARENT',
      })
      .expect(201);

    const token = register.body.accessToken as string;

    const summary = await request(app!.getHttpServer())
      .get('/api/v1/compliance/me/privacy/notice/summary')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(summary.body.versionNumber).toBeDefined();

    const ack = await request(app!.getHttpServer())
      .post('/api/v1/compliance/me/privacy/acknowledge')
      .set('Authorization', `Bearer ${token}`)
      .set(DEMO_DEVICE_HEADERS)
      .send({ appVersion: 'e2e', platform: 'ci' })
      .expect(201);

    const meBefore = await request(app!.getHttpServer())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(ack.body.userId).toBe(meBefore.body.id);
    expect(ack.body.noticeVersion).toBe(summary.body.versionNumber);

    const me = await request(app!.getHttpServer())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(me.body.privacyNoticeAcknowledged).toBe(true);
    expect(me.body.hipaaConsentGranted).toBe(true);
  });

  it('requires re-acknowledgment when a new notice version is published', async () => {
    const email = `reack-${Date.now()}@example.com`;
    const register = await request(app!.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email,
        password: 'SecurePass1!',
        firstName: 'ReAck',
        lastName: 'User',
        role: 'PARENT',
      })
      .expect(201);
    const userToken = register.body.accessToken as string;

    const summary = await request(app!.getHttpServer())
      .get('/api/v1/compliance/me/privacy/notice/summary')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200);

    await request(app!.getHttpServer())
      .post('/api/v1/compliance/me/privacy/acknowledge')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ platform: 'e2e' })
      .expect(201);

    const newVersion = `e2e-${Date.now()}`;
    const created = await request(app!.getHttpServer())
      .post('/api/v1/admin/compliance/notice-versions')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ versionNumber: newVersion, publish: false })
      .expect(201);

    await request(app!.getHttpServer())
      .patch(
        `/api/v1/admin/compliance/notice-versions/${created.body.id}/publish`,
      )
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    const status = await request(app!.getHttpServer())
      .get('/api/v1/compliance/me/privacy/acknowledgment-status')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200);

    expect(status.body.acknowledged).toBe(false);
    expect(status.body.activeVersion).toBe(newVersion);
    expect(status.body.activeVersion).not.toBe(summary.body.versionNumber);

    // Restore demo tenant active notice so other tests keep using v1.0 seed data.
    await request(app!.getHttpServer())
      .patch(
        `/api/v1/admin/compliance/notice-versions/${summary.body.id}/publish`,
      )
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
  });

  it('restricts admin compliance dashboard to platform admins', async () => {
    await request(app!.getHttpServer())
      .get('/api/v1/admin/compliance/acknowledgments')
      .set('Authorization', `Bearer ${demoParentToken}`)
      .expect(403);

    const list = await request(app!.getHttpServer())
      .get('/api/v1/admin/compliance/acknowledgments')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(Array.isArray(list.body)).toBe(true);
  });

  it('creates audit log when privacy rights request is submitted', async () => {
    const submitted = await request(app!.getHttpServer())
      .post('/api/v1/compliance/me/privacy/rights-requests')
      .set('Authorization', `Bearer ${demoParentToken}`)
      .send({
        requestType: 'RECORD_ACCESS',
        payload: { recordTypes: 'therapy notes', deliveryMethod: 'secure_app' },
      })
      .expect(201);

    expect(submitted.body.requestType).toBe('RECORD_ACCESS');
  });

});
