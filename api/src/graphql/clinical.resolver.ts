import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { ClinicalService } from '../clinical/clinical.service';
import { TherapistsService } from '../therapists/therapists.service';
import {
  CreateTreatmentPlanInput,
  SaveProgressNoteInput,
} from './inputs/clinical.input';
import { TherapyType } from '../../generated/prisma/client';
import { TherapistBadgeType, TreatmentPlanType } from './types/clinical.types';

@Resolver()
export class ClinicalResolver {
  constructor(
    private readonly clinical: ClinicalService,
    private readonly therapists: TherapistsService,
  ) {}

  @Query(() => [TreatmentPlanType], { name: 'myTreatmentPlans' })
  @Roles('PARENT')
  async myTreatmentPlans(
    @CurrentUser() user: AuthUser,
  ): Promise<TreatmentPlanType[]> {
    const rows = await this.clinical.listPlansForParentUser(user.id);
    return rows.map((p) => this.mapPlan(p));
  }

  @Query(() => [TreatmentPlanType], { name: 'therapistTreatmentPlans' })
  @Roles('THERAPIST')
  async therapistTreatmentPlans(
    @CurrentUser() user: AuthUser,
  ): Promise<TreatmentPlanType[]> {
    const rows = await this.clinical.listPlansForTherapistUser(user.id);
    return rows.map((p) => this.mapPlan(p));
  }

  @Mutation(() => TreatmentPlanType, { name: 'createTreatmentPlan' })
  @Roles('THERAPIST')
  async createTreatmentPlan(
    @CurrentUser() user: AuthUser,
    @Args('input') input: CreateTreatmentPlanInput,
  ): Promise<TreatmentPlanType> {
    const p = await this.clinical.createPlanForTherapist(user.id, input);
    return this.mapPlan(p);
  }

  @Mutation(() => Boolean, { name: 'saveProgressNote' })
  @Roles('THERAPIST')
  async saveProgressNote(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SaveProgressNoteInput,
  ): Promise<boolean> {
    await this.clinical.saveProgressNote(user.id, input);
    return true;
  }

  @Query(() => [TherapistBadgeType], { name: 'myTherapistBadges' })
  @Roles('THERAPIST')
  async myTherapistBadges(
    @CurrentUser() user: AuthUser,
  ): Promise<TherapistBadgeType[]> {
    const t = await this.therapists.findByUserId(user.id);
    const badges = await this.clinical.listBadgesForTherapist(t.id);
    return badges.map((b) => ({
      type: b.type,
      label: b.label ?? undefined,
      awardedAt: b.awardedAt,
    }));
  }

  private mapPlan(p: {
    id: string;
    title: string;
    therapyType: TherapyType;
    startDate: Date;
    isActive: boolean;
    child?: { id: string; firstName: string; lastName: string; dateOfBirth: Date };
    therapist?: { user: { firstName: string; lastName: string } };
  }): TreatmentPlanType {
    return {
      id: p.id,
      title: p.title,
      therapyType: p.therapyType,
      startDate: p.startDate,
      isActive: p.isActive,
      child: p.child
        ? {
            id: p.child.id,
            firstName: p.child.firstName,
            lastName: p.child.lastName,
            dateOfBirth: p.child.dateOfBirth,
          }
        : undefined,
      therapistName: p.therapist
        ? `${p.therapist.user.firstName} ${p.therapist.user.lastName}`
        : undefined,
    };
  }
}
