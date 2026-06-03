import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  async findByParentUserId(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      return [];
    }
    return this.prisma.review.findMany({
      where: { parentId: parent.id },
      include: {
        therapist: { include: { user: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async createForParentUserId(
    userId: string,
    data: {
      therapistId: string;
      rating: number;
      title?: string;
      comment?: string;
    },
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }
    if (data.rating < 1 || data.rating > 5) {
      throw new BadRequestException('Rating must be between 1 and 5');
    }

    const therapist = await this.prisma.therapist.findFirst({
      where: { id: data.therapistId, tenantId: parent.tenantId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found');
    }

    const review = await this.prisma.review.create({
      data: {
        parentId: parent.id,
        therapistId: therapist.id,
        authorId: userId,
        rating: data.rating,
        title: data.title,
        comment: data.comment,
      },
      include: { therapist: { include: { user: true } } },
    });

    const stats = await this.prisma.review.aggregate({
      where: { therapistId: therapist.id, isPublished: true },
      _avg: { rating: true },
      _count: true,
    });

    await this.prisma.therapist.update({
      where: { id: therapist.id },
      data: {
        ratingAverage: stats._avg.rating ?? therapist.ratingAverage,
        ratingCount: stats._count,
      },
    });

    return review;
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL submitReview');
  }

  async findAll() {
    return this.prisma.review.findMany({ take: 50 });
  }

  async findOne(id: string) {
    const review = await this.prisma.review.findUnique({ where: { id } });
    if (!review) {
      throw new NotFoundException('Review not found');
    }
    return review;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.review.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.review.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.review.delete({ where: { id } });
    return { id, deleted: true };
  }
}
