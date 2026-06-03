import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TelehealthService {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Record<string, unknown>) {
    // return this.prisma.telehealt.create({ data });
    void this.prisma;
    return { id: 'stub', ...data };
  }

  async findAll() {
    // return this.prisma.telehealth.findMany();
    void this.prisma;
    return [];
  }

  async findOne(id: string) {
    if (!id) {
      throw new NotFoundException('Resource not found');
    }
    // return this.prisma.telehealth.findUnique({ where: { id } });
    void this.prisma;
    return { id };
  }

  async update(id: string, data: Record<string, unknown>) {
    // return this.prisma.telehealth.update({ where: { id }, data });
    void this.prisma;
    return { id, ...data };
  }

  async remove(id: string) {
    // return this.prisma.telehealth.delete({ where: { id } });
    void this.prisma;
    return { id, deleted: true };
  }
}
