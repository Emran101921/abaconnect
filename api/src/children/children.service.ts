import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ChildrenService {
  constructor(private readonly prisma: PrismaService) {}

  async findByParentUserId(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      return [];
    }
    return this.prisma.child.findMany({
      where: { parentId: parent.id },
      orderBy: { firstName: 'asc' },
    });
  }

  async createForParentUserId(
    userId: string,
    data: {
      firstName: string;
      lastName: string;
      dateOfBirth: Date;
      gender?: string;
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

  async findOne(id: string) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
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
