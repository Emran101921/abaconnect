import { Args, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { ClinicalService } from '../clinical/clinical.service';
import { TherapistsService } from '../therapists/therapists.service';
import {
  CreateTreatmentPlanInput,
  SaveProgressNoteInput,
  SubmitSessionFeedbackInput,
  UpdateTreatmentPlanInput,
} from './inputs/clinical.input';
import { TherapyType } from '../../generated/prisma/client';
import {
  TherapistBadgeType,
  TherapistWeeklyProgressType,
  TreatmentPlanGoalType,
  TreatmentPlanType,
} from './types/clinical.types';
import { ParentProgressNoteType } from './types/parent-ext.types';

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

  @Query(() => TherapistWeeklyProgressType, { name: 'therapistWeeklyProgress' })
  @Roles('THERAPIST')
  async therapistWeeklyProgress(
    @CurrentUser() user: AuthUser,
  ): Promise<TherapistWeeklyProgressType> {
    return this.clinical.therapistWeeklyProgress(user.id);
  }

  @Query(() => [ParentProgressNoteType], { name: 'myProgressNotes' })
  @Roles('PARENT')
  async myProgressNotes(
    @CurrentUser() user: AuthUser,
  ): Promise<ParentProgressNoteType[]> {
    const rows = await this.clinical.listProgressNotesForParentUser(user.id);
    return rows.map((n) => this.mapProgressNote(n));
  }

  @Mutation(() => TreatmentPlanType, { name: 'createTreatmentPlan' })
  @Roles('THERAPIST')
  async createTreatmentPlan(
    @CurrentUser() user: AuthUser,
    @Args('input') input: CreateTreatmentPlanInput,
  ): Promise<TreatmentPlanType> {
    const p = await this.clinical.createPlanForTherapist(user.id, {
      ...input,
      goals: input.goals,
    });
    return this.mapPlan(p);
  }

  @Mutation(() => TreatmentPlanType, { name: 'updateTreatmentPlan' })
  @Roles('THERAPIST')
  async updateTreatmentPlan(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateTreatmentPlanInput,
  ): Promise<TreatmentPlanType> {
    const p = await this.clinical.updatePlanForTherapist(user.id, input.planId, {
      title: input.title,
      isActive: input.isActive,
      goals: input.goals,
    });
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

  @Mutation(() => ParentProgressNoteType, { name: 'submitSessionFeedback' })
  @Roles('PARENT')
  async submitSessionFeedback(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SubmitSessionFeedbackInput,
  ): Promise<ParentProgressNoteType> {
    const n = await this.clinical.submitSessionFeedback(
      user.id,
      input.sessionId,
      input.feedback,
    );
    return this.mapProgressNote(n);
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

  private mapGoals(raw: unknown): TreatmentPlanGoalType[] {
    if (!Array.isArray(raw)) return [];
    return raw
      .filter((g): g is Record<string, unknown> => g != null && typeof g === 'object')
      .map((g) => ({
        id: String(g.id ?? ''),
        label: String(g.label ?? ''),
        status: g.status != null ? String(g.status) : undefined,
      }))
      .filter((g) => g.id && g.label);
  }

  private mapPlan(p: {
    id: string;
    title: string;
    therapyType: TherapyType;
    startDate: Date;
    isActive: boolean;
    goals?: unknown;
    child?: {
      id: string;
      firstName: string;
      lastName: string;
      dateOfBirth: Date;
    };
    therapist?: { user: { firstName: string; lastName: string } };
  }): TreatmentPlanType {
    const goals = this.mapGoals(p.goals);
    const goalsDoneCount = goals.filter((g) => g.status === 'done').length;
    return {
      id: p.id,
      title: p.title,
      therapyType: p.therapyType,
      startDate: p.startDate,
      isActive: p.isActive,
      goals,
      goalsDoneCount,
      goalsTotalCount: goals.length,
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

  private mapProgressNote(n: {
    id: string;
    sessionId: string;
    summary: string;
    parentFeedback?: string | null;
    signedAt?: Date | null;
    session: {
      child: { firstName: string; lastName: string };
      therapist: { user: { firstName: string; lastName: string } };
    };
  }): ParentProgressNoteType {
    return {
      id: n.id,
      sessionId: n.sessionId,
      childName: `${n.session.child.firstName} ${n.session.child.lastName}`,
      therapistName: `${n.session.therapist.user.firstName} ${n.session.therapist.user.lastName}`,
      summary: n.summary,
      parentFeedback: n.parentFeedback ?? undefined,
      signedAt: n.signedAt ?? undefined,
    };
  }
}
