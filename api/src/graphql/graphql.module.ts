import { Module } from '@nestjs/common';
import { AdminModule } from '../admin/admin.module';
import { AgenciesModule } from '../agencies/agencies.module';
import { AppointmentsModule } from '../appointments/appointments.module';
import { ChildrenModule } from '../children/children.module';
import { MatchingModule } from '../matching/matching.module';
import { ReviewsModule } from '../reviews/reviews.module';
import { ScreeningsModule } from '../screenings/screenings.module';
import { MessagingModule } from '../messaging/messaging.module';
import { PaymentsModule } from '../payments/payments.module';
import { SessionsModule } from '../sessions/sessions.module';
import { TherapistsModule } from '../therapists/therapists.module';
import { AdminResolver } from './admin.resolver';
import { AgencyResolver } from './agency.resolver';
import { MessagingResolver } from './messaging.resolver';
import { ParentBookingResolver } from './parent-booking.resolver';
import { PaymentsResolver } from './payments.resolver';
import { TherapistResolver } from './therapist.resolver';

@Module({
  imports: [
    ChildrenModule,
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
  ],
  providers: [
    ParentBookingResolver,
    TherapistResolver,
    AdminResolver,
    AgencyResolver,
    MessagingResolver,
    PaymentsResolver,
  ],
})
export class GraphqlFeatureModule {}
