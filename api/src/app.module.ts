import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { GraphqlFeatureModule } from './graphql/graphql.module';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { ThrottlerModule } from '@nestjs/throttler';
import { BullModule } from '@nestjs/bull';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ParentsModule } from './parents/parents.module';
import { ChildrenModule } from './children/children.module';
import { TherapistsModule } from './therapists/therapists.module';
import { AgenciesModule } from './agencies/agencies.module';
import { AppointmentsModule } from './appointments/appointments.module';
import { SessionsModule } from './sessions/sessions.module';
import { DocumentsModule } from './documents/documents.module';
import { MessagingModule } from './messaging/messaging.module';
import { PaymentsModule } from './payments/payments.module';
import { InsuranceModule } from './insurance/insurance.module';
import { ReviewsModule } from './reviews/reviews.module';
import { MatchingModule } from './matching/matching.module';
import { TelehealthModule } from './telehealth/telehealth.module';
import { GpsModule } from './gps/gps.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AdminModule } from './admin/admin.module';
import { AuditModule } from './audit/audit.module';
import { ComplianceModule } from './compliance/compliance.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { AiModule } from './ai/ai.module';
import { ScreeningsModule } from './screenings/screenings.module';
import { ComplaintsModule } from './complaints/complaints.module';
import { DisputesModule } from './disputes/disputes.module';
import { PayoutsModule } from './payouts/payouts.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: true,
      context: ({ req }: { req: unknown }) => ({ req }),
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: 100,
      },
    ]),
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        redis: {
          host: config.get<string>('REDIS_HOST') ?? 'localhost',
          port: config.get<number>('REDIS_PORT') ?? 6379,
        },
      }),
    }),
    PrismaModule,
    AuthModule,
    UsersModule,
    ParentsModule,
    ChildrenModule,
    TherapistsModule,
    AgenciesModule,
    AppointmentsModule,
    SessionsModule,
    DocumentsModule,
    MessagingModule,
    PaymentsModule,
    InsuranceModule,
    ReviewsModule,
    MatchingModule,
    TelehealthModule,
    GpsModule,
    NotificationsModule,
    AdminModule,
    AuditModule,
    ComplianceModule,
    AnalyticsModule,
    AiModule,
    ScreeningsModule,
    ComplaintsModule,
    DisputesModule,
    PayoutsModule,
    GraphqlFeatureModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}
