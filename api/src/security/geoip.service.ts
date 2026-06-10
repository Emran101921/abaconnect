import { Injectable, Logger } from '@nestjs/common';

export interface GeoLocation {
  /** Human-readable "City, Region, Country" stamp. */
  label: string;
  city?: string;
  region?: string;
  country?: string;
  latitude?: number;
  longitude?: number;
}

interface IpApiResponse {
  status?: string;
  city?: string;
  regionName?: string;
  country?: string;
  lat?: number;
  lon?: number;
}

/**
 * Best-effort IP geolocation for stamping auth events with an approximate
 * location. This is intentionally non-blocking and fault tolerant: any failure
 * (network, timeout, private IP, disabled) resolves to `null` so the auth flow
 * is never held up by geolocation.
 *
 * Disabled by default. Set GEOIP_ENABLED=true to turn it on in environments
 * where outbound lookups are acceptable. Private/loopback IPs are always
 * skipped so local development and tests never make network calls.
 */
@Injectable()
export class GeoIpService {
  private readonly logger = new Logger(GeoIpService.name);

  private get enabled(): boolean {
    return process.env.GEOIP_ENABLED === 'true';
  }

  private get providerUrl(): string {
    // ip-api.com offers a keyless lookup; override via env for a paid/HTTPS
    // provider in production. `{ip}` is substituted with the client IP.
    return (
      process.env.GEOIP_PROVIDER_URL ??
      'http://ip-api.com/json/{ip}?fields=status,city,regionName,country,lat,lon'
    );
  }

  isPrivateIp(ip?: string | null): boolean {
    if (!ip) return true;
    const normalized = ip.replace(/^::ffff:/, '').trim();
    if (
      normalized === '' ||
      normalized === '::1' ||
      normalized === '127.0.0.1' ||
      normalized.startsWith('127.') ||
      normalized.startsWith('10.') ||
      normalized.startsWith('192.168.') ||
      normalized.startsWith('169.254.') ||
      normalized.startsWith('fc') ||
      normalized.startsWith('fd') ||
      normalized.startsWith('fe80')
    ) {
      return true;
    }
    // 172.16.0.0 – 172.31.255.255
    const m = /^172\.(\d{1,3})\./.exec(normalized);
    if (m) {
      const second = Number(m[1]);
      if (second >= 16 && second <= 31) return true;
    }
    return false;
  }

  async lookup(ip?: string | null): Promise<GeoLocation | null> {
    if (!this.enabled || this.isPrivateIp(ip)) {
      return null;
    }
    const cleanIp = (ip as string).replace(/^::ffff:/, '').trim();
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 2500);
      const response = await fetch(
        this.providerUrl.replace('{ip}', encodeURIComponent(cleanIp)),
        { signal: controller.signal },
      );
      clearTimeout(timeout);
      if (!response.ok) {
        return null;
      }
      const data = (await response.json()) as IpApiResponse;
      if (data.status && data.status !== 'success') {
        return null;
      }
      const parts = [data.city, data.regionName, data.country].filter(
        (p): p is string => Boolean(p),
      );
      if (parts.length === 0) {
        return null;
      }
      return {
        label: parts.join(', '),
        city: data.city,
        region: data.regionName,
        country: data.country,
        latitude: data.lat,
        longitude: data.lon,
      };
    } catch (error) {
      // Geolocation is advisory only — never fail auth because of it.
      this.logger.debug(
        `GeoIP lookup failed for ${cleanIp}: ${(error as Error).message}`,
      );
      return null;
    }
  }
}
