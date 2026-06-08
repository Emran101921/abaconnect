export function isEipFormFullySigned(
  data: Record<string, unknown> | null | undefined,
): boolean {
  if (!data) return false;

  const hasText = (value: unknown) =>
    typeof value === 'string' && value.trim().length > 0;

  const hasGps = (lat: unknown, lng: unknown) =>
    typeof lat === 'number' &&
    typeof lng === 'number' &&
    !Number.isNaN(lat) &&
    !Number.isNaN(lng);

  const interventionistSigned =
    hasText(data.interventionistSignature) &&
    hasGps(
      data.interventionistSignatureLatitude,
      data.interventionistSignatureLongitude,
    );

  const parentSigned =
    hasText(data.parentSignature) &&
    hasGps(data.parentSignatureLatitude, data.parentSignatureLongitude);

  return interventionistSigned && parentSigned;
}
