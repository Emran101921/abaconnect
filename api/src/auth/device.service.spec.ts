import { DeviceService } from './device.service';

describe('DeviceService', () => {
  const geoip = { lookup: jest.fn().mockResolvedValue({ label: 'Austin, TX, US' }) };
  const securityEvents = { log: jest.fn().mockResolvedValue(undefined) };
  const prisma = {
    authDevice: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
    },
  };

  let service: DeviceService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new DeviceService(
      prisma as never,
      geoip as never,
      securityEvents as never,
    );
  });

  it('treats missing device id as a new untrusted device', async () => {
    const result = await service.recordLogin(
      { id: 'user-1', tenantId: 'tenant-1' },
      { ipAddress: '203.0.113.10' },
    );
    expect(result.isNewDevice).toBe(true);
    expect(prisma.authDevice.upsert).not.toHaveBeenCalled();
  });

  it('marks an unknown device as new', async () => {
    prisma.authDevice.findUnique.mockResolvedValue(null);
    prisma.authDevice.upsert.mockResolvedValue({});

    const result = await service.recordLogin(
      { id: 'user-1', tenantId: 'tenant-1' },
      {
        deviceId: 'device-a',
        deviceModel: 'iPhone 17',
        platform: 'ios',
        ipAddress: '203.0.113.10',
      },
    );

    expect(result.isNewDevice).toBe(true);
    expect(prisma.authDevice.upsert).toHaveBeenCalled();
    expect(securityEvents.log).toHaveBeenCalledWith(
      expect.objectContaining({ eventType: 'NEW_DEVICE_LOGIN' }),
    );
  });

  it('treats a trusted device as known', async () => {
    prisma.authDevice.findUnique.mockResolvedValue({
      trusted: true,
      deviceModel: 'iPhone 17',
    });
    prisma.authDevice.upsert.mockResolvedValue({});

    const result = await service.recordLogin(
      { id: 'user-1', tenantId: 'tenant-1' },
      {
        deviceId: 'device-a',
        deviceModel: 'iPhone 17',
        platform: 'ios',
        ipAddress: '203.0.113.10',
      },
    );

    expect(result.isNewDevice).toBe(false);
    expect(securityEvents.log).not.toHaveBeenCalled();
  });
});
