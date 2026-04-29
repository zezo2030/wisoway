import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD, APP_FILTER, APP_INTERCEPTOR, APP_PIPE } from '@nestjs/core';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { appConfig } from './config/app.config';
import { databaseConfig } from './config/database.config';
import { jwtConfig } from './config/jwt.config';
import { s3Config } from './config/s3.config';
import { redisConfig } from './config/redis.config';
import { twilioConfig } from './config/twilio.config';
import { a2aCliqConfig } from './config/a2a-cliq.config';
import { platformConfig } from './config/configuration';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { BanGuard } from './common/guards/ban.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { RestrictedAccountInterceptor } from './common/interceptors/restricted.interceptor';
import { ValidationPipe } from './common/pipes/validation.pipe';
import { HealthModule } from './modules/health/health.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { UploadsModule } from './modules/uploads/uploads.module';
import { VehiclesModule } from './modules/vehicles/vehicles.module';
import { TripsModule } from './modules/trips/trips.module';
import { LocationsModule } from './modules/locations/locations.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { PaymentsModule } from './modules/payments/payments.module';
// TODO: re-enable after TypeORM migration: RatingsModule
import { ChatPostgresModule } from './modules/chat/chat-postgres.module';
// import { RatingsModule } from './modules/ratings/ratings.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { JobsModule } from './jobs/jobs.module';
import { AdminModule } from './modules/admin/admin.module';
import { PostgresModule } from './database/postgres.module';
import { TrackingModule } from './modules/tracking/tracking.module';
import { WalletModule } from './modules/wallet/wallet.module';
import { SecurityModule } from './modules/security/security.module';
import { AuditModule } from './common/audit/audit.module';
import { PendingChargesModule } from './modules/pending-charges/pending-charges.module';
import { TripTimeModule } from './modules/trip-time/trip-time.module';
import { ShareLinksModule } from './modules/share-links/share-links.module';
import { SettlementModule } from './modules/settlement/settlement.module';
import { CallsModule } from './modules/calls/calls.module';
import { ComplaintsModule } from './modules/complaints/complaints.module';
import { RefundsModule } from './modules/refunds/refunds.module';
import { SupportModule } from './modules/support/support.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [
        appConfig,
        databaseConfig,
        jwtConfig,
        s3Config,
        redisConfig,
        twilioConfig,
        a2aCliqConfig,
        platformConfig,
      ],
      envFilePath: '.env',
    }),
    PostgresModule,
    // Single limit: multiple forRoot entries all apply to every route, so the old
    // 20/min bucket capped *all* traffic (including /bookings/my), not only public APIs.
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 200,
      },
    ]),
    HealthModule,
    AuthModule,
    UsersModule,
    UploadsModule,
    VehiclesModule,
    TripsModule,
    LocationsModule,
    BookingsModule,
    PaymentsModule,
    ChatPostgresModule,
    // RatingsModule,
    NotificationsModule,
    JobsModule,
    AdminModule,
    TrackingModule,
    WalletModule,
    SecurityModule,
    AuditModule,
    PendingChargesModule,
    TripTimeModule,
    ShareLinksModule,
    SettlementModule,
    CallsModule,
    ComplaintsModule,
    RefundsModule,
    SupportModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      // BanGuard runs immediately after JwtAuthGuard so every authenticated
      // request from a banned account is blocked before reaching any handler.
      provide: APP_GUARD,
      useClass: BanGuard,
    },
    {
      provide: APP_GUARD,
      useClass: RolesGuard,
    },
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: TransformInterceptor,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: LoggingInterceptor,
    },
    {
      // RestrictedAccountInterceptor blocks write operations for restricted
      // accounts; runs after logging so the attempt is always recorded.
      provide: APP_INTERCEPTOR,
      useClass: RestrictedAccountInterceptor,
    },
    {
      provide: APP_PIPE,
      useClass: ValidationPipe,
    },
  ],
})
export class AppModule {}
