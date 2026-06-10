import { Module } from '@nestjs/common';
import { SecurityController } from './security.controller';
import { SecurityEventService } from './security-event.service';
import { GeoIpService } from './geoip.service';

@Module({
  controllers: [SecurityController],
  providers: [SecurityEventService, GeoIpService],
  exports: [SecurityEventService, GeoIpService],
})
export class SecurityModule {}
