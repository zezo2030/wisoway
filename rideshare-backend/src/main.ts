import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import * as path from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('Bootstrap');

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: ['error', 'warn', 'log', 'debug', 'verbose'],
  });

  // Serve uploaded files statically
  const uploadsPath = path.join(process.cwd(), 'uploads');
  app.useStaticAssets(uploadsPath, { prefix: '/uploads' });

  // Serve public share page statically
  const publicPath = path.join(process.cwd(), 'public');
  app.useStaticAssets(publicPath, { prefix: '/public' });

  // Security: Helmet
  app.use(helmet());

  // CORS
  app.enableCors({
    origin:
      process.env.NODE_ENV === 'production'
        ? process.env.ALLOWED_ORIGINS?.split(',') || ['https://yourdomain.com']
        : true, // Allow all origins in development
    credentials: true,
  });

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // API prefix
  const apiPrefix = process.env.API_PREFIX || 'api/v1';
  app.setGlobalPrefix(apiPrefix);

  // Swagger documentation
  const config = new DocumentBuilder()
    .setTitle('Rideshare Backend API')
    .setDescription('API documentation for the Rideshare Backend Platform')
    .setVersion('1.0')
    .addBearerAuth()
    .addTag('auth', 'Authentication endpoints')
    .addTag('users', 'User management')
    .addTag('vehicles', 'Vehicle management')
    .addTag('trips', 'Trip management')
    .addTag('bookings', 'Booking management')
    .addTag('payments', 'Payment processing')
    .addTag('chat', 'Real-time chat')
    .addTag('ratings', 'Ratings and reviews')
    .addTag('notifications', 'Push notifications')
    .addTag('uploads', 'File uploads')
    .addTag('locations', 'Location services')
    .addTag('admin', 'Admin dashboard')
    .addTag('health', 'Health checks')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT || 3000;
  const host = process.env.HOST || '0.0.0.0';
  await app.listen(port, host);

  logger.log(
    `Application is running on: http://${host === '0.0.0.0' ? 'localhost' : host}:${port}/${apiPrefix}`,
  );
  if (host === '0.0.0.0') {
    logger.log(
      `Accepting connections from network (use your machine IP for the app)`,
    );
  }
  logger.log(
    `Swagger documentation available at: http://localhost:${port}/api/docs`,
  );
}
bootstrap();
