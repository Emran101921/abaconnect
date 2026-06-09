import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PhiAuditService } from '../audit/phi-audit.service';
import { PrismaService } from '../prisma/prisma.service';

export type ChildProfileInput = {
  firstName?: string;
  lastName?: string;
  dateOfBirth?: Date;
  gender?: string;
  primaryLanguage?: string;
  guardianName?: string;
  guardianPhone?: string;
  guardianEmail?: string;
  addressLine1?: string;
  zipCode?: string;
  pediatricianName?: string;
  insuranceType?: string;
  hadEarlyIntervention?: boolean;
  notes?: string;
};

@Injectable()
export class ChildrenService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly phiAudit: PhiAuditService,
  ) {}

  async findByParentUserId(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      return [];
    }
    const children = await this.prisma.child.findMany({
      where: { parentId: parent.id },
      orderBy: { firstName: 'asc' },
    });
    await this.phiAudit.logPhiAccess({
      tenantId: parent.tenantId,
      actorId: userId,
      action: 'READ',
      resourceType: 'children',
    });
    return children;
  }

  async updateForParentUserId(
    userId: string,
    childId: string,
    data: ChildProfileInput,
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }
    const child = await this.prisma.child.findFirst({
      where: { id: childId, parentId: parent.id },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    return this.prisma.child.update({
      where: { id: childId },
      data,
    });
  }

  async createForParentUserId(
    userId: string,
    data: ChildProfileInput & {
      firstName: string;
      lastName: string;
      dateOfBirth: Date;
    },
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }
    return this.prisma.child.create({
      data: {
        parentId: parent.id,
        tenantId: parent.tenantId,
        firstName: data.firstName,
        lastName: data.lastName,
        dateOfBirth: data.dateOfBirth,
        gender: data.gender,
        primaryLanguage: data.primaryLanguage,
        guardianName: data.guardianName,
        guardianPhone: data.guardianPhone,
        guardianEmail: data.guardianEmail,
        addressLine1: data.addressLine1,
        zipCode: data.zipCode,
        pediatricianName: data.pediatricianName,
        insuranceType: data.insuranceType,
        hadEarlyIntervention: data.hadEarlyIntervention,
        notes: data.notes,
      },
    });
  }

  async create(data: {
    parentId: string;
    tenantId: string;
    firstName: string;
    lastName: string;
    dateOfBirth: Date;
    gender?: string;
  }) {
    return this.prisma.child.create({ data });
  }

  async findAll() {
    return this.prisma.child.findMany({ take: 100 });
  }

  async findOne(id: string, actorId?: string) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (actorId) {
      await this.phiAudit.logPhiAccess({
        tenantId: child.tenantId,
        actorId,
        action: 'READ',
        resourceType: 'child',
        resourceId: child.id,
      });
    }
    return child;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.child.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.child.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.child.delete({ where: { id } });
    return { id, deleted: true };
  }
}
