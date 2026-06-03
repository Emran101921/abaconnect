import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface AuditLogEntry {
  action: string;
  actorId?: string;
  metadata?: Record<string, unknown>;
  timestamp: Date;
}

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Record<string, unknown>) {
    void this.prisma;
    return { id: 'stub', ...data };
  }

  async findAll() {
    return [];
  }

  async findOne(id: string) {
    return { id };
  }

  async update(id: string, data: Record<string, unknown>) {
    return { id, ...data };
  }

  async remove(id: string) {
    return { id, deleted: true };
  }

  async log(
    action: string,
    actorId?: string,
    metadata?: Record<string, unknown>,
  ): Promise<AuditLogEntry> {
    const entry: AuditLogEntry = {
      action,
      actorId,
      metadata,
      timestamp: new Date(),
    };
    // await this.prisma.auditLog.create({ data: entry });
    void this.prisma;
    return entry;
  }
}
