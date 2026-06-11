import { Controller, Get, Param, Res } from '@nestjs/common';
import { Response } from 'express';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { ServiceLogService } from './service-log.service';

@Controller('service-logs')
export class ServiceLogsController {
  constructor(private readonly serviceLogs: ServiceLogService) {}

  @Get('therapist')
  @Roles('THERAPIST')
  listForTherapist(@CurrentUser() user: AuthUser) {
    return this.serviceLogs.listForTherapistUser(user.id).then((rows) =>
      rows.map((log) => {
        const data = log.logData as Record<string, unknown>;
        return {
          id: log.id,
          sessionId: log.sessionId,
          childName: `${log.session.child.firstName} ${log.session.child.lastName}`,
          therapistSignatureName: log.therapistSignatureName,
          therapistSignedAt: log.therapistSignedAt?.toISOString() ?? null,
          parentSignatureName: log.parentSignatureName,
          parentSignedAt: log.parentSignedAt?.toISOString() ?? null,
          parentName: data.parentName ?? null,
          sessionDate:
            log.session.appointment?.scheduledStart.toISOString().slice(0, 10) ??
            null,
        };
      }),
    );
  }

  @Get('therapist/:sessionId/pdf')
  @Roles('THERAPIST')
  async downloadTherapistPdf(
    @CurrentUser() user: AuthUser,
    @Param('sessionId') sessionId: string,
    @Res() res: Response,
  ): Promise<void> {
    const { buffer, filename } =
      await this.serviceLogs.buildPdfForTherapist(user.id, sessionId);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${encodeURIComponent(filename)}"`,
    );
    res.send(buffer);
  }

  @Get('parent')
  @Roles('PARENT')
  listForParent(@CurrentUser() user: AuthUser) {
    return this.serviceLogs.listForParentUser(user.id).then((rows) =>
      rows.map((log) => ({
        id: log.id,
        sessionId: log.sessionId,
        childName: `${log.session.child.firstName} ${log.session.child.lastName}`,
        therapistName: `${log.session.therapist.user.firstName} ${log.session.therapist.user.lastName}`,
        parentSignedAt: log.parentSignedAt?.toISOString() ?? null,
        sessionDate:
          log.session.appointment?.scheduledStart.toISOString().slice(0, 10) ??
          null,
      })),
    );
  }

  @Get('parent/:sessionId/pdf')
  @Roles('PARENT')
  async downloadParentPdf(
    @CurrentUser() user: AuthUser,
    @Param('sessionId') sessionId: string,
    @Res() res: Response,
  ): Promise<void> {
    const { buffer, filename } = await this.serviceLogs.buildPdfForParent(
      user.id,
      sessionId,
    );
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${encodeURIComponent(filename)}"`,
    );
    res.send(buffer);
  }

  @Get('agency/:sessionId/pdf')
  @Roles('AGENCY_ADMIN')
  async downloadAgencyPdf(
    @CurrentUser() user: AuthUser,
    @Param('sessionId') sessionId: string,
    @Res() res: Response,
  ): Promise<void> {
    if (!user.tenantId) {
      res.status(400).send({ message: 'Tenant required' });
      return;
    }
    const { buffer, filename } = await this.serviceLogs.buildPdfForAgency(
      user.tenantId,
      sessionId,
      user.id,
    );
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${encodeURIComponent(filename)}"`,
    );
    res.send(buffer);
  }
}
