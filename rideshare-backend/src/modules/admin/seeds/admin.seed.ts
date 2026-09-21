import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { UserEntity } from '../../../database/entities/user.entity';
import { PgUserRole } from '../../../database/entities/shared.enums';

/**
 * Admin seed configuration, read when the seed runs rather than when this file
 * is imported — import order should not decide which credentials get used.
 */
function adminConfig() {
  return {
    email: process.env.ADMIN_EMAIL || 'admin@rideshare.com',
    password: process.env.ADMIN_PASSWORD || 'Admin@123456',
    name: process.env.ADMIN_NAME || 'System Admin',
    phoneNumber: process.env.ADMIN_PHONE || '+201000000000',
  };
}

/**
 * Creates the default admin account when the users table has no admin.
 *
 * This runs against Postgres — the store the app reads. An earlier version
 * spoke to Mongoose, left over from before the migration, so it never created
 * anything and the dashboard was unreachable once the users table was emptied.
 *
 * @returns whether an admin was created, plus a message for the caller to log.
 */
export async function seedAdminUser(
  userRepo: Repository<UserEntity>,
): Promise<{ created: boolean; message: string }> {
  const config = adminConfig();

  const existingAdmin = await userRepo.findOne({
    where: { role: PgUserRole.ADMIN },
  });

  if (existingAdmin) {
    return { created: false, message: 'Admin user already exists' };
  }

  const admin = userRepo.create({
    email: config.email,
    passwordHash: await bcrypt.hash(config.password, 12),
    name: config.name,
    phoneNumber: config.phoneNumber,
    role: PgUserRole.ADMIN,
    provider: 'email',
    isEmailVerified: true,
    isPhoneVerified: true,
    isActive: true,
  });

  await userRepo.save(admin);

  // The password is deliberately not logged: on a default install it is a
  // known value, and logs are the wrong place to repeat it.
  console.log(
    `Admin user created (${config.email} / ${config.phoneNumber}). ` +
      'Sign in and change the password if it is still the default.',
  );

  return {
    created: true,
    message: `Admin user created with email: ${config.email}`,
  };
}

export default seedAdminUser;
