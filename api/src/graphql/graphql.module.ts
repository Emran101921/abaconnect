import { Module } from '@nestjs/common';
import { AdminModule } from '../admin/admin.module';
import { AppointmentsModule } from '../appointments/appointments.module';
import { ChildrenModule } from '../children/children.module';
import { MatchingModule } from '../matching/matching.module';
import { SessionsModule } from '../sessions/sessions.module';
import { TherapistsModule } from '../therapists/therapists.module';
import { AdminResolver } from './admin.resolver';
import { ParentBookingResolver } from './parent-booking.resolver';
import { TherapistResolver } from './therapist.resolver';

@Module({
  imports: [
    ChildrenModule,
    AppointmentsModule,
    MatchingModule,
    TherapistsModule,
    SessionsModule,
    AdminModule,
  ],
  providers: [ParentBookingResolver, TherapistResolver, AdminResolver],
})
export class GraphqlFeatureModule {}
