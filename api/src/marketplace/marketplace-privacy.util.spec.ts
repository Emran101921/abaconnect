import {
  deriveConcernTagsFromScreening,
  sanitizePublicDescription,
  toPublicMarketplaceRequest,
} from './marketplace-privacy.util';

describe('marketplace privacy util', () => {
  it('sanitizes diagnostic language from public descriptions', () => {
    expect(sanitizePublicDescription('Child has autism and requires ABA')).toBe(
      'Child has [redacted] and [redacted]',
    );
  });

  it('maps screening recommendations to concern tags without diagnosis wording', () => {
    const tags = deriveConcernTagsFromScreening(
      [
        {
          code: 'SPEECH',
          explanation:
            'Responses suggest communication delays that may benefit from evaluation.',
        },
      ],
      { speech: true, aba: true },
    );
    expect(tags).toContain('communication delay');
    expect(tags).toContain('behavior concerns');
    expect(tags.join(' ')).not.toMatch(/autism|diagnos/i);
  });

  it('never exposes forbidden child fields in public marketplace cards', () => {
    const publicCard = toPublicMarketplaceRequest({
      id: 'req-1',
      anonymousPublicId: 'SR-20491',
      status: 'ACTIVE',
      serviceCategories: ['SPEECH'],
      concernTags: ['communication delay'],
      ageRange: 'MONTHS_25_36',
      zipCode: '11230',
      city: 'Brooklyn',
      state: 'NY',
      zipCentroidLat: 40.62,
      zipCentroidLng: -73.95,
      mapPinJitterLat: 40.621,
      mapPinJitterLng: -73.951,
      locationType: 'HOME',
      preferredSchedule: { weekdays: ['afternoon'] },
      languagePreference: 'English',
      authorizationStatus: 'PARENT_SCREENING_ONLY',
      urgency: 'ROUTINE',
      publicDescription: 'May benefit from speech evaluation',
      approximateLocationEnabled: true,
      exactAddressShared: false,
      createdAt: new Date(),
      updatedAt: new Date(),
      tenantId: 't',
      childId: 'c',
      parentUserId: 'p',
      screeningResponseId: null,
      removedAt: null,
      removedReason: null,
    } as never);

    expect(publicCard.anonymousPublicId).toBe('SR-20491');
    expect(publicCard.serviceAreaLabel).toContain('11230');
    expect((publicCard as Record<string, unknown>).firstName).toBeUndefined();
    expect((publicCard as Record<string, unknown>).dateOfBirth).toBeUndefined();
    expect((publicCard as Record<string, unknown>).guardianPhone).toBeUndefined();
  });
});
