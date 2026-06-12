import { Module } from '@nestjs/common';
import { AdminModule } from '../admin/admin.module';
import { AgenciesModule } from '../agencies/agencies.module';
import { AiModule } from '../ai/ai.module';
import { AnalyticsModule } from '../analytics/analytics.module';
import { AppointmentsModule } from '../appointments/appointments.module';
import { ClinicalModule } from '../clinical/clinical.module';
import { ChildrenModule } from '../children/children.module';
import { ComplaintsModule } from '../complaints/complaints.module';
import { DisputesModule } from '../disputes/disputes.module';
import { PayoutsModule } from '../payouts/payouts.module';
import { ComplianceModule } from '../compliance/compliance.module';
import { DocumentsModule } from '../documents/documents.module';
import { GpsModule } from '../gps/gps.module';
import { InsuranceModule } from '../insurance/insurance.module';
import { MatchingModule } from '../matching/matching.module';
import { ParentsModule } from '../parents/parents.module';
import { MessagingModule } from '../messaging/messaging.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';
import { ReviewsModule } from '../reviews/reviews.module';
import { ScreeningsModule } from '../screenings/screenings.module';
import { SessionsModule } from '../sessions/sessions.module';
import { TelehealthModule } from '../telehealth/telehealth.module';
import { TherapistsModule } from '../therapists/therapists.module';
import { AdminResolver } from './admin.resolver';
import { AgencyResolver } from './agency.resolver';
import { MessagingResolver } from './messaging.resolver';
import { ClinicalResolver } from './clinical.resolver';
import { ParentBookingResolver } from './parent-booking.resolver';
import { BillingResolver } from './billing.resolver';
import { PaymentsResolver } from './payments.resolver';
import { PlatformResolver } from './platform.resolver';
import { TherapistResolver } from './therapist.resolver';
import { MarketplaceModule } from '../marketplace/marketplace.module';
import { MarketplaceResolver } from './marketplace.resolver';

@Module({
  imports: [
    ChildrenModule,
    ParentsModule,
    AppointmentsModule,
    MatchingModule,
    TherapistsModule,
    SessionsModule,
    AdminModule,
    AgenciesModule,
    ReviewsModule,
    ScreeningsModule,
    MessagingModule,
    PaymentsModule,
    TelehealthModule,
    DocumentsModule,
    NotificationsModule,
    InsuranceModule,
    ComplianceModule,
    GpsModule,
    AnalyticsModule,
    AiModule,
    ComplaintsModule,
    ClinicalModule,
    DisputesModule,
    PayoutsModule,
    MarketplaceModule,
  ],
  providers: [
    ParentBookingResolver,
    ClinicalResolver,
    TherapistResolver,
    AdminResolver,
    AgencyResolver,
    MessagingResolver,
    PaymentsResolver,
    BillingResolver,
    PlatformResolver,
    MarketplaceResolver,
  ],
})
export class GraphqlFeatureModule {}
