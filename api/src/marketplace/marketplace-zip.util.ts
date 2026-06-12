/** Approximate ZIP centroid — never expose exact home address on marketplace map. */
export function zipToApproxCentroid(zipCode: string): { lat: number; lng: number } {
  const zip = zipCode.replace(/\D/g, '').slice(0, 5);
  const z = parseInt(zip, 10);
  if (!Number.isFinite(z) || zip.length < 5) {
    return { lat: 40.7128, lng: -74.006 };
  }
  const lat = 25 + ((z % 1000) / 1000) * 24;
  const lng = -125 + ((Math.floor(z / 1000) % 100) / 100) * 55;
  return { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
}

/** Small jitter so map pins are approximate, not exact household locations. */
export function jitterMapPin(
  lat: number,
  lng: number,
  seed: string,
): { lat: number; lng: number } {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
  }
  const latOffset = ((hash % 200) - 100) / 10000;
  const lngOffset = (((hash >> 8) % 200) - 100) / 10000;
  return {
    lat: Number((lat + latOffset).toFixed(6)),
    lng: Number((lng + lngOffset).toFixed(6)),
  };
}

export function haversineMiles(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 3958.8;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return Number((R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(1));
}
