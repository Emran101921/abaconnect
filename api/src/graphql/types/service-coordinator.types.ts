import { Field, Float, ID, Int, ObjectType, registerEnumType } from '@nestjs/graphql';
import {
  AgencyRosterMemberRole,
  AgencyRosterStatus,
  EiScreeningPriority,
  EiScreeningStatus,
} from '../../../generated/prisma/client';

registerEnumType(AgencyRosterMemberRole, { name: 'AgencyRosterMemberRole' });
registerEnumType(AgencyRosterStatus, { name: 'AgencyRosterStatus' });
registerEnumType(EiScreeningPriority, { name: 'EiScreeningPriority' });
registerEnumType(EiScreeningStatus, { name: 'EiScreeningStatus' });

@ObjectType()
export class AgencyRosterMemberType {
  @Field()
  id: string;

  @Field()
  userId: string;

  @Field()
  email: string;

  @Field()
  firstName: string;

  @Field()
  lastName: string;

  @Field({ nullable: true })
  phone?: string;

  @Field(() => AgencyRosterMemberRole)
  role: AgencyRosterMemberRole;

  @Field(() => AgencyRosterStatus)
  status: AgencyRosterStatus;

  @Field(() => [String])
  languages: string[];

  @Field(() => Int)
  caseload: number;

  @Field({ nullable: true })
  notes?: string;

  @Field()
  addedByName: string;

  @Field()
  addedAt: Date;

  @Field({ nullable: true })
  lastLoginAt?: Date;

  @Field()
  isActive: boolean;
}

@ObjectType()
export class ScCaseSummaryType {
  @Field()
  assignmentId: string;

  @Field()
  childId: string;

  @Field()
  childName: string;

  @Field()
  dateOfBirth: Date;

  @Field()
  parentName: string;

  @Field()
  caseStatus: string;

  @Field()
  screeningStatus: string;

  @Field()
  evaluationStatus: string;

  @Field()
  ifspStatus: string;

  @Field({ nullable: true })
  nextFollowUpDate?: Date;

  @Field()
  isUrgent: boolean;

  @Field(() => EiScreeningPriority)
  priorityLevel: EiScreeningPriority;

  @Field(() => [String])
  assignedProviders: string[];
}

@ObjectType()
export class ScDashboardType {
  @Field(() => Int)
  totalCases: number;

  @Field(() => Int)
  urgentCases: number;

  @Field(() => Int)
  screeningsDue: number;

  @Field(() => Int)
  followUpsDue: number;

  @Field(() => Int)
  evaluationsPending: number;

  @Field(() => Int)
  ifspReviewsDue: number;

  @Field(() => [ScCaseSummaryType])
  cases: ScCaseSummaryType[];
}

@ObjectType()
export class EiScreeningType {
  @Field()
  id: string;

  @Field()
  childId: string;

  @Field()
  answersJson: string;

  @Field(() => EiScreeningStatus)
  status: EiScreeningStatus;

  @Field(() => EiScreeningPriority)
  priorityLevel: EiScreeningPriority;

  @Field()
  followUpRequired: boolean;

  @Field({ nullable: true })
  followUpDueDate?: Date;

  @Field({ nullable: true })
  notes?: string;

  @Field({ nullable: true })
  progressSummary?: string;

  @Field({ nullable: true })
  newConcerns?: string;

  @Field()
  createdAt: Date;

  @Field()
  updatedAt: Date;
}

@ObjectType()
export class EiScreeningResultType {
  @Field(() => EiScreeningType)
  screening: EiScreeningType;

  @Field(() => Int)
  completionPercent: number;
}

@ObjectType()
export class ServiceCoordinationNoteType {
  @Field()
  id: string;

  @Field()
  childId: string;

  @Field()
  noteType: string;

  @Field()
  noteText: string;

  @Field()
  actionRequired: boolean;

  @Field({ nullable: true })
  actionDueDate?: Date;

  @Field()
  createdAt: Date;
}

@ObjectType()
export class ScCaseDetailType {
  @Field()
  childId: string;

  @Field()
  childName: string;

  @Field()
  dateOfBirth: Date;

  @Field()
  parentName: string;

  @Field(() => ID)
  parentUserId: string;

  @Field({ nullable: true })
  parentEmail?: string;

  @Field({ nullable: true })
  parentPhone?: string;

  @Field({ nullable: true })
  guardianPhone?: string;

  @Field()
  screeningPrefillJson: string;

  @Field(() => EiScreeningType, { nullable: true })
  initialScreening?: EiScreeningType;

  @Field(() => [EiScreeningType])
  ongoingScreenings: EiScreeningType[];

  @Field(() => [ServiceCoordinationNoteType])
  notes: ServiceCoordinationNoteType[];
}

@ObjectType()
export class ScFollowUpReminderType {
  @Field()
  type: string;

  @Field()
  childId: string;

  @Field()
  childName: string;

  @Field()
  dueDate: Date;

  @Field()
  overdue: boolean;
}

@ObjectType()
export class AgencyCaseType {
  @Field()
  childId: string;

  @Field()
  childName: string;

  @Field()
  parentName: string;

  @Field({ nullable: true })
  assignedCoordinatorId?: string;

  @Field({ nullable: true })
  assignedCoordinatorName?: string;

  @Field({ nullable: true })
  assignmentId?: string;

  @Field()
  eiEligible: boolean;

  @Field({ nullable: true })
  eligibilityReason?: string;

  @Field({ nullable: true })
  riskLevel?: string;

  @Field()
  evaluationRequested: boolean;
}
