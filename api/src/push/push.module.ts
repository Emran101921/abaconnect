import { BullModule } from '@nestjs/bull';
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { PushProcessor } from './push.processor';
import { PushService } from './push.service';

@Module({
  imports: [PrismaModule, BullModule.registerQueue({ name: 'push' })],
  providers: [PushService, PushProcessor],
  exports: [PushService, BullModule],
})
export class PushModule {}
