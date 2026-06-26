import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { CallsPermissionsService } from './calls-permissions.service';
import { PrismaService } from '../prisma/prisma.service';

describe('CallsPermissionsService', () => {
  let service: CallsPermissionsService;
  const prisma = {
    user: { findUnique: jest.fn(), findFirst: jest.fn() },
    agency: { findUnique: jest.fn() },
    parent: { findFirst: jest.fn() },
    therapist: { findFirst: jest.fn() },
    appointment: { findFirst: jest.fn(), findMany: jest.fn() },
    childServiceCoordinatorAssignment: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    agencyRoster: { findFirst: jest.fn() },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CallsPermissionsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = module.get(CallsPermissionsService);
  });

  it('blocks platform admin from initiating calls', async () => {
    prisma.user.findUnique
      .mockResolvedValueOnce({
        id: 'admin-1',
        role: 'PLATFORM_ADMIN',
        isActive: true,
        tenantId: 't1',
        agencyId: null,
      })
      .mockResolvedValueOnce({
        id: 'parent-1',
        role: 'PARENT',
        isActive: true,
        tenantId: 't1',
        agencyId: null,
      });

    await expect(service.assertCanCall('admin-1', 'parent-1')).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('blocks agency admin from initiating calls', async () => {
    prisma.user.findUnique
      .mockResolvedValueOnce({
        id: 'agency-1',
        role: 'AGENCY_ADMIN',
        isActive: true,
        tenantId: 't1',
        agencyId: 'a1',
      })
      .mockResolvedValueOnce({
        id: 'parent-1',
        role: 'PARENT',
        isActive: true,
        tenantId: 't1',
        agencyId: null,
      });

    await expect(service.assertCanCall('agency-1', 'parent-1')).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('blocks therapist calling unassigned parent', async () => {
    prisma.user.findUnique
      .mockResolvedValueOnce({
        id: 'therapist-user',
        role: 'THERAPIST',
        isActive: true,
        tenantId: 't1',
        agencyId: null,
      })
      .mockResolvedValueOnce({
        id: 'parent-user',
        role: 'PARENT',
        isActive: true,
        tenantId: 't1',
        agencyId: null,
      });
    prisma.therapist.findFirst.mockResolvedValue({ id: 'th-1' });
    prisma.appointment.findFirst.mockResolvedValue(null);

    await expect(
      service.assertCanCall('therapist-user', 'parent-user', 'child-1'),
    ).rejects.toThrow(ForbiddenException);
  });

  it('allows parent calling assigned therapist', async () => {
    prisma.user.findUnique
      .mockResolvedValueOnce({
        id: 'parent-user',
        role: 'PARENT',
        isActive: true,
        tenantId: 't1',
        agencyId: null,
      })
      .mockResolvedValueOnce({
        id: 'therapist-user',
        role: 'THERAPIST',
        isActive: true,
        tenantId: 't1',
        agencyId: null,
      });
    prisma.parent.findFirst.mockResolvedValue({
      children: [{ id: 'child-1' }],
    });
    prisma.appointment.findFirst.mockResolvedValue({
      id: 'apt-1',
      agencyId: 'a1',
    });
    prisma.agency.findUnique.mockResolvedValue({
      id: 'a1',
      callingEnabled: true,
    });

    const ctx = await service.assertCanCall(
      'parent-user',
      'therapist-user',
      'child-1',
    );
    expect(ctx.childId).toBe('child-1');
    expect(ctx.agencyId).toBe('a1');
  });
});
