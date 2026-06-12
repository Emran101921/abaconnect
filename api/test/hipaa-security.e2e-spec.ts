import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { closeE2eApp, createE2eApp } from './e2e-app.util';

describe('HIPAA security architecture (e2e)', () => {
  let app: INestApplication | undefined;
  let parentToken: string;
  let adminToken: string;

  beforeAll(async () => {
    app = await createE2eApp();
    const parentLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set({
        'x-device-id': 'smoke-ci-device',
        'x-device-model': 'CI',
        'x-device-platform': 'ci',
      })
      .send({ email: 'parent1@demo.local', password: 'Parent1Demo!' })
      .expect(201);
    parentToken = parentLogin.body.accessToken as string;

    const adminLogin = await request(app!.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: 'admin@abaconnect.local', password: 'Admin123!' })
      .expect(201);
    adminToken = adminLogin.body.accessToken as string;
  });

  afterAll(async () => {
    if (app) await closeE2eApp(app);
  });

  it('denies parent access to admin security dashboard', async () => {
    await request(app!.getHttpServer())
      .get('/api/v1/admin/security/dashboard')
      .set('Authorization', `Bearer ${parentToken}`)
      .expect(403);
  });

  it('allows platform admin security dashboard', async () => {
    const res = await request(app!.getHttpServer())
      .get('/api/v1/admin/security/dashboard')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body).toHaveProperty('activeUsers');
    expect(res.body).toHaveProperty('failedLogins24h');
    expect(res.body).toHaveProperty('securityAlerts');
  });

  it('supports audit log search for admins', async () => {
    const res = await request(app!.getHttpServer())
      .get('/api/v1/admin/security/audit-logs/search')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(Array.isArray(res.body)).toBe(true);
  });

  it('blocks privileged role self-registration', async () => {
    await request(app!.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email: `billing-${Date.now()}@example.com`,
        password: 'SecurePass1!',
        firstName: 'Bill',
        lastName: 'Staff',
        role: 'BILLING_STAFF',
      })
      .expect(400);
  });

  it('does not expose PHI encryption key in health response', async () => {
    const res = await request(app!.getHttpServer())
      .get('/api/v1/health')
      .expect(200);

    const body = JSON.stringify(res.body);
    expect(body).not.toContain('PHI_ENCRYPTION_KEY');
    expect(body).not.toContain(process.env.PHI_ENCRYPTION_KEY ?? '___none___');
  });

  it('lists pending compliance documents for authenticated user', async () => {
    const res = await request(app!.getHttpServer())
      .get('/api/v1/compliance/documents/me/pending')
      .set('Authorization', `Bearer ${parentToken}`)
      .expect(200);

    expect(Array.isArray(res.body)).toBe(true);
  });
});
