import { MarketplaceAgeRange } from '../../generated/prisma/client';

export function calculateAgeRange(dateOfBirth: Date): MarketplaceAgeRange {
  const now = new Date();
  let months =
    (now.getFullYear() - dateOfBirth.getFullYear()) * 12 +
    (now.getMonth() - dateOfBirth.getMonth());
  if (now.getDate() < dateOfBirth.getDate()) months -= 1;
  if (months < 0) months = 0;

  if (months <= 12) return 'MONTHS_0_12';
  if (months <= 24) return 'MONTHS_13_24';
  if (months <= 36) return 'MONTHS_25_36';
  const years = Math.floor(months / 12);
  if (years <= 5) return 'YEARS_3_5';
  if (years <= 8) return 'YEARS_6_8';
  if (years <= 12) return 'YEARS_9_12';
  return 'YEARS_13_PLUS';
}

export function formatAgeRangeLabel(range: MarketplaceAgeRange): string {
  switch (range) {
    case 'MONTHS_0_12':
      return '0-12 months';
    case 'MONTHS_13_24':
      return '13-24 months';
    case 'MONTHS_25_36':
      return '25-36 months';
    case 'YEARS_3_5':
      return '3-5 years';
    case 'YEARS_6_8':
      return '6-8 years';
    case 'YEARS_9_12':
      return '9-12 years';
    case 'YEARS_13_PLUS':
      return '13+ years';
    default:
      return range;
  }
}
