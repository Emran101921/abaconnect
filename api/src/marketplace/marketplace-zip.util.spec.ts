import {
  haversineMiles,
  jitterMapPin,
  zipToApproxCentroid,
} from './marketplace-zip.util';

describe('zipToApproxCentroid', () => {
  it('returns Brooklyn-area coordinates for 11230', () => {
    const { lat, lng } = zipToApproxCentroid('11230');
    expect(lat).toBeGreaterThan(40);
    expect(lat).toBeLessThan(41);
    expect(lng).toBeGreaterThan(-74.5);
    expect(lng).toBeLessThan(-73.5);
  });

  it('returns Austin-area coordinates for 78701', () => {
    const { lat, lng } = zipToApproxCentroid('78701');
    expect(lat).toBeGreaterThan(30);
    expect(lat).toBeLessThan(31);
    expect(lng).toBeGreaterThan(-98);
    expect(lng).toBeLessThan(-97);
  });

  it('strips non-digits before lookup', () => {
    const plain = zipToApproxCentroid('11230');
    const formatted = zipToApproxCentroid('11230-1234');
    expect(formatted).toEqual(plain);
  });
});

describe('jitterMapPin', () => {
  it('stays within roughly one mile of the centroid', () => {
    const centroid = zipToApproxCentroid('11230');
    const jittered = jitterMapPin(centroid.lat, centroid.lng, 'child-123');
    const miles = haversineMiles(
      centroid.lat,
      centroid.lng,
      jittered.lat,
      jittered.lng,
    );
    expect(miles).toBeLessThan(1.5);
  });

  it('is stable for the same seed', () => {
    const centroid = zipToApproxCentroid('11230');
    expect(jitterMapPin(centroid.lat, centroid.lng, 'child-123')).toEqual(
      jitterMapPin(centroid.lat, centroid.lng, 'child-123'),
    );
  });
});
