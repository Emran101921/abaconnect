import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Record<string, unknown>) {
    // return this.prisma.user.create({ data });
    void this.prisma;
    return { id: 'stub', ...data };
  }

  async findAll() {
    // return this.prisma.users.findMany();
    void this.prisma;
    return [];
  }

  async findOne(id: string) {
    if (!id) {
      throw new NotFoundException('Resource not found');
    }
    // return this.prisma.users.findUnique({ where: { id } });
    void this.prisma;
    return { id };
  }

  async update(id: string, data: Record<string, unknown>) {
    // return this.prisma.users.update({ where: { id }, data });
    void this.prisma;
    return { id, ...data };
  }

  async remove(id: string) {
    // return this.prisma.users.delete({ where: { id } });
    void this.prisma;
    return { id, deleted: true };
  }
}
