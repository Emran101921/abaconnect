import { Controller, Get, Header, Res } from '@nestjs/common';
import { Response } from 'express';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AppointmentsService } from './appointments.service';

@Controller('therapist/appointments')
@Roles('THERAPIST')
export class TherapistAppointmentsController {
  constructor(private readonly appointmentsService: AppointmentsService) {}

  @Get('ical')
  @Header('Content-Type', 'text/calendar; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="abaconnect-therapist.ics"')
  async exportIcal(@CurrentUser() user: AuthUser, @Res() res: Response): Promise<void> {
    const ics = await this.appointmentsService.buildIcalForTherapistUser(user.id);
    res.send(ics);
  }
}
