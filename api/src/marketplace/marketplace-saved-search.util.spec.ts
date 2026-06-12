import { requestMatchesSavedSearchFilters } from './marketplace-saved-search.util';

describe('marketplace saved search matching', () => {
  const baseRequest = {
    zipCode: '11230',
    ageRange: 'MONTHS_25_36',
    languagePreference: 'English',
    locationType: 'HOME' as const,
    urgency: 'ROUTINE' as const,
    authorizationStatus: 'PARENT_SCREENING_ONLY' as const,
    serviceCategories: ['SPEECH', 'EVALUATION'],
    zipCentroidLat: 40.62,
    zipCentroidLng: -73.95,
  };

  const profile = {
    coverageZipCodes: ['11230', '11201'],
  };

  it('matches when filters are empty', () => {
    expect(requestMatchesSavedSearchFilters(baseRequest, {}, profile)).toBe(
      true,
    );
  });

  it('rejects mismatched service category', () => {
    expect(
      requestMatchesSavedSearchFilters(
        baseRequest,
        { serviceCategory: 'ABA' },
        profile,
      ),
    ).toBe(false);
  });

  it('matches ZIP and language filters together', () => {
    expect(
      requestMatchesSavedSearchFilters(
        baseRequest,
        { zipCode: '11230', language: 'english' },
        profile,
      ),
    ).toBe(true);
  });

  it('rejects requests outside saved radius', () => {
    expect(
      requestMatchesSavedSearchFilters(
        { ...baseRequest, zipCentroidLat: 30.27, zipCentroidLng: -97.74 },
        { radiusMiles: 5 },
        { coverageZipCodes: ['11230'] },
      ),
    ).toBe(false);
  });
});
