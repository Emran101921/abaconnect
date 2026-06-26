const hasText = (value: unknown) =>
  typeof value === 'string' && value.trim().length > 0;

const asCoord = (value: unknown): number | null => {
  if (typeof value === 'number' && !Number.isNaN(value)) return value;
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
};

const hasGps = (lat: unknown, lng: unknown) => {
  const latitude = asCoord(lat);
  const longitude = asCoord(lng);
  return latitude != null && longitude != null;
};

export function missingFieldsForParentSignature(
  data: Record<string, unknown> | null | undefined,
): string[] {
  if (!data) return ['Session note form'];

  const missing: string[] = [];
  const add = (label: string, ok: boolean) => {
    if (!ok) missing.push(label);
  };

  add("Child's name", hasText(data.childName));
  add('DOB', hasText(data.childDob));
  add('Sex', hasText(data.childSex));
  add('Interventionist name', hasText(data.interventionistName));
  add('Credentials', hasText(data.credentials));
  add('NPI', hasText(data.npi));
  add('State license number', hasText(data.licenseNumber));
  add('Service type', hasText(data.serviceType));
  add('Session date', hasText(data.sessionDate));

  const location = data.ifspServiceLocation;
  if (!hasText(location)) {
    missing.push('IFSP service location');
  } else if (location === 'Other') {
    missing.push('Specified IFSP service location');
  }

  add('Time from', hasText(data.timeFrom));
  add('Time to', hasText(data.timeTo));

  const intensity = data.intensity;
  if (typeof intensity !== 'string' || intensity.trim().length === 0) {
    missing.push('Intensity');
  } else if (intensity === 'Other') {
    missing.push('Specified intensity');
  }

  add('Session delivered', hasText(data.sessionDelivered));
  add('Date note written', hasText(data.dateNoteWritten));
  add('ICD-10 code', hasText(data.icd10Code));

  const hasParticipant =
    data.participantChild === true ||
    data.participantParent === true ||
    hasText(data.participantOther);
  add('Session participants', hasParticipant);

  add('IFSP outcomes (#1)', hasText(data.q1IfspOutcomes));
  add('Session description (#2)', hasText(data.q2SessionDescription));

  const hasQ3 =
    data.q3ObservedRoutines === true ||
    data.q3ParentTriedActivity === true ||
    data.q3DemonstratedActivity === true ||
    data.q3ReviewedCommTool === true ||
    hasText(data.q3Other);
  add('Parent/caregiver technique (#3)', hasQ3);

  add('Home strategies (#4)', hasText(data.q4HomeStrategies));

  if (data.sessionCancelled === true) {
    add('Cancellation reason', hasText(data.cancellationReason));
  }
  if (data.isMakeup === true) {
    add('Make-up for missed session date', hasText(data.makeupForDate));
  }

  add('Relationship to child', hasText(data.parentRelationship));
  return missing;
}

export function isReadyForParentSignature(
  data: Record<string, unknown> | null | undefined,
): boolean {
  return missingFieldsForParentSignature(data).length === 0;
}

export function hasInterventionistSignature(
  data: Record<string, unknown> | null | undefined,
): boolean {
  if (!data) return false;
  return (
    hasText(data.interventionistSignature) &&
    hasGps(
      data.interventionistSignatureLatitude,
      data.interventionistSignatureLongitude,
    )
  );
}

export function hasParentSignature(
  data: Record<string, unknown> | null | undefined,
): boolean {
  if (!data) return false;
  return (
    hasText(data.parentSignature) &&
    hasGps(data.parentSignatureLatitude, data.parentSignatureLongitude)
  );
}

export function isRemoteParentSignatureRequested(
  data: Record<string, unknown> | null | undefined,
): boolean {
  return data?.parentSignatureRemoteRequested === true;
}

export function isEipFormFullySigned(
  data: Record<string, unknown> | null | undefined,
): boolean {
  if (!data) return false;

  return hasInterventionistSignature(data) && hasParentSignature(data);
}
