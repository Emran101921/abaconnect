import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { closeE2eApp, createE2eApp } from './e2e-app.util';

describe('Marketplace privacy (e2e)', () => {
  let app: INestApplication | undefined;
  let parentToken: string;
  let therapistToken: string;
  let childId: string;
  let screeningId: string;
  let marketplaceRequestId: string;
  let providerProfileId: string;

  beforeAll(async () => {
    app = await createE2eApp();
    const deviceHeaders = {
      'x-device-id': 'smoke-ci-device',
      'x-device-model': 'CI',
      'x-device-platform': 'ci',
    };

    const parentLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set(deviceHeaders)
      .send({ email: 'parent1@demo.local', password: 'Parent1Demo!' })
      .expect(201);
    parentToken = parentLogin.body.accessToken as string;

    const therapistLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set(deviceHeaders)
      .send({ email: 'therapist@demo.local', password: 'Therapist123!' })
      .expect(201);
    therapistToken = therapistLogin.body.accessToken as string;

    const childRes = await request(app.getHttpServer())
      .post('/graphql')
      .set('Authorization', `Bearer ${parentToken}`)
      .set(deviceHeaders)
      .send({
        query: `
          mutation($input: AddChildInput!) {
            addChild(input: $input) { id }
          }
        `,
        variables: {
          input: {
            firstName: 'Alex',
            lastName: 'Demo',
            dateOfBirth: '2023-06-01',
            zipCode: '11230',
            primaryLanguage: 'English',
          },
        },
      })
      .expect(200);
    expect(childRes.body.errors).toBeUndefined();
    childId = childRes.body.data.addChild.id as string;

    const templatesRes = await request(app.getHttpServer())
      .post('/graphql')
      .set('Authorization', `Bearer ${parentToken}`)
      .set(deviceHeaders)
      .send({
        query: `query { screeningTemplates { id therapyType } }`,
      })
      .expect(200);
    const eiTemplate = (
      templatesRes.body.data.screeningTemplates as Array<{
        id: string;
        therapyType: string;
      }>
    ).find((t) => t.therapyType === 'EARLY_INTERVENTION');
    expect(eiTemplate).toBeDefined();

    const screeningRes = await request(app.getHttpServer())
      .post('/graphql')
      .set('Authorization', `Bearer ${parentToken}`)
      .set(deviceHeaders)
      .send({
        query: `
          mutation($input: SubmitScreeningInput!) {
            submitScreening(input: $input) { id }
          }
        `,
        variables: {
          input: {
            childId,
            templateId: eiTemplate!.id,
            responsesJson: JSON.stringify({ speech_delay: true }),
            consentGranted: true,
          },
        },
      })
      .expect(200);
    expect(screeningRes.body.errors).toBeUndefined();
    screeningId = screeningRes.body.data.submitScreening.id as string;

    const createReq = await request(app.getHttpServer())
      .post(`/api/v1/children/${childId}/marketplace-request`)
      .set('Authorization', `Bearer ${parentToken}`)
      .set(deviceHeaders)
      .send({
        screeningResponseId: screeningId,
        anonymousConsentGranted: true,
        locationType: 'HOME',
        languagePreference: 'English',
        urgency: 'ROUTINE',
      })
      .expect(201);
    marketplaceRequestId = createReq.body.id as string;
    expect(createReq.body.anonymousPublicId).toMatch(/^SR-/);
    expect(createReq.body.firstName).toBeUndefined();
    expect(createReq.body.guardianPhone).toBeUndefined();

    const providerRes = await request(app.getHttpServer())
      .get('/api/v1/marketplace-requests')
      .set('Authorization', `Bearer ${therapistToken}`)
      .set(deviceHeaders)
      .query({ zipCode: '11230', radiusMiles: 50 })
      .expect(200);
    const items = providerRes.body.items as Array<{ id: string }>;
    expect(items.some((i) => i.id === marketplaceRequestId)).toBe(true);
  });

  afterAll(async () => {
    if (app) await closeE2eApp(app);
  });

  it('denies identifiable child details before parent consent', async () => {
    await request(app!.getHttpServer())
      .get(`/api/v1/provider/authorized-child-details/${marketplaceRequestId}`)
      .set('Authorization', `Bearer ${therapistToken}`)
      .expect(403);
  });

  it('public marketplace card hides PHI fields', async () => {
    const res = await request(app!.getHttpServer())
      .get(`/api/v1/marketplace-requests/${marketplaceRequestId}/public`)
      .set('Authorization', `Bearer ${therapistToken}`)
      .expect(200);

    expect(res.body.anonymousPublicId).toBeDefined();
    expect(res.body.serviceAreaLabel).toContain('11230');
    expect(res.body.firstName).toBeUndefined();
    expect(res.body.dateOfBirth).toBeUndefined();
    expect(res.body.exactAddressShared).toBe(false);
  });

  it('allows authorized details only after parent grants consent', async () => {
    const interests = await request(app!.getHttpServer())
      .post(`/api/v1/marketplace-requests/${marketplaceRequestId}/interests`)
      .set('Authorization', `Bearer ${therapistToken}`)
      .send({ message: "I'm available for evaluation support." })
      .expect(201);

    providerProfileId = interests.body.providerProfileId as string;
    if (!providerProfileId) {
      const parentInterests = await request(app!.getHttpServer())
        .get(
          `/api/v1/parent/marketplace-requests/${marketplaceRequestId}/interests`,
        )
        .set('Authorization', `Bearer ${parentToken}`)
        .expect(200);
      providerProfileId = parentInterests.body[0].provider.id as string;
    }

    await request(app!.getHttpServer())
      .post(
        `/api/v1/marketplace-requests/${marketplaceRequestId}/consent/share-with-provider`,
      )
      .set('Authorization', `Bearer ${parentToken}`)
      .send({ providerProfileId })
      .expect(201);

    const details = await request(app!.getHttpServer())
      .get(`/api/v1/provider/authorized-child-details/${marketplaceRequestId}`)
      .set('Authorization', `Bearer ${therapistToken}`)
      .expect(200);

    expect(details.body.child.firstName).toBe('Alex');
    expect(details.body.parentContact.email).toContain('@');

    await request(app!.getHttpServer())
      .post(
        `/api/v1/marketplace-requests/${marketplaceRequestId}/revoke-consent`,
      )
      .set('Authorization', `Bearer ${parentToken}`)
      .send({ providerProfileId })
      .expect(201);

    await request(app!.getHttpServer())
      .get(`/api/v1/provider/authorized-child-details/${marketplaceRequestId}`)
      .set('Authorization', `Bearer ${therapistToken}`)
      .expect(403);
  });
});
