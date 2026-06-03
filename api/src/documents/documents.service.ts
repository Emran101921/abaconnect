import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DocumentsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Record<string, unknown>) {
    // return this.prisma.document.create({ data });
    void this.prisma;
    return { id: 'stub', ...data };
  }

  async findAll() {
    // return this.prisma.documents.findMany();
    void this.prisma;
    return [];
  }

  async findOne(id: string) {
    if (!id) {
      throw new NotFoundException('Resource not found');
    }
    // return this.prisma.documents.findUnique({ where: { id } });
    void this.prisma;
    return { id };
  }

  async update(id: string, data: Record<string, unknown>) {
    // return this.prisma.documents.update({ where: { id }, data });
    void this.prisma;
    return { id, ...data };
  }

  async remove(id: string) {
    // return this.prisma.documents.delete({ where: { id } });
    void this.prisma;
    return { id, deleted: true };
  }
}
