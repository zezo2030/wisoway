import { NestFactory } from '@nestjs/core';
import { AppModule } from './src/app.module';
import { getRepositoryToken } from '@nestjs/typeorm';
import { UserEntity } from './src/database/entities/user.entity';
import { Repository } from 'typeorm';
import { PgUserRole } from './src/database/entities/shared.enums';
import * as bcrypt from 'bcrypt';

/**
 * Admin seed configuration
 * Override via env: ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_NAME, ADMIN_PHONE
 */
const ADMIN_CONFIG = {
  email: process.env.ADMIN_EMAIL || 'admin@rideshare.com',
  password: process.env.ADMIN_PASSWORD || 'Admin@123456',
  name: process.env.ADMIN_NAME || 'System Admin',
  phoneNumber: process.env.ADMIN_PHONE || '+201000000000',
};

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const userRepo = app.get<Repository<UserEntity>>(
    getRepositoryToken(UserEntity),
  );

  const existingAdmin = await userRepo.findOne({
    where: { role: PgUserRole.ADMIN },
  });

  if (existingAdmin) {
    console.log('='.repeat(60));
    console.log('ADMIN USER ALREADY EXISTS');
    console.log('='.repeat(60));
    console.log(`Email: ${existingAdmin.email}`);
    console.log('='.repeat(60));
    await app.close();
    return;
  }

  const hashedPassword = await bcrypt.hash(ADMIN_CONFIG.password, 12);

  await userRepo.save(
    userRepo.create({
      email: ADMIN_CONFIG.email,
      passwordHash: hashedPassword,
      name: ADMIN_CONFIG.name,
      phoneNumber: ADMIN_CONFIG.phoneNumber,
      role: PgUserRole.ADMIN,
      provider: 'email',
      isEmailVerified: true,
      isPhoneVerified: true,
      isActive: true,
      rating: 0,
      totalRatings: 0,
    }),
  );

  console.log('='.repeat(60));
  console.log('ADMIN USER CREATED SUCCESSFULLY');
  console.log('='.repeat(60));
  console.log(`Email: ${ADMIN_CONFIG.email}`);
  console.log(`Password: ${ADMIN_CONFIG.password}`);
  console.log('Please change the default password after first login!');
  console.log('='.repeat(60));

  await app.close();
}
bootstrap().catch((err) => {
  console.error('Error seeding admin:', err);
  process.exit(1);
});
