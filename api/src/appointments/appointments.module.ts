import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { AppointmentsController } from './appointments.controller';
import { ParentAppointmentsController } from './parent-appointments.controller';
import { TherapistAppointmentsController } from './therapist-appointments.controller';
import { AppointmentsService } from './appointments.service';

@Module({
  imports: [NotificationsModule],
  controllers: [
    AppointmentsController,
    ParentAppointmentsController,
    TherapistAppointmentsController,
  ],
  providers: [AppointmentsService],
  exports: [AppointmentsService],
})
export class AppointmentsModule {}
