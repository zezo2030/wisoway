import { Model } from 'mongoose';
import * as bcrypt from 'bcrypt';
import {
  User,
  UserDocument,
  UserRole,
  AuthProvider,
} from '../../users/schemas/user.schema';

/**
 * Admin seed configuration
 * These values can be overridden via environment variables
 */
const ADMIN_CONFIG = {
  email: process.env.ADMIN_EMAIL || 'admin@rideshare.com',
  password: process.env.ADMIN_PASSWORD || 'Admin@123456',
  name: process.env.ADMIN_NAME || 'System Admin',
  phoneNumber: process.env.ADMIN_PHONE || '+201000000000',
};

/**
 * Seed initial admin user
 * This function creates the default admin user if it doesn't exist
 *
 * @param userModel - The User model to use for database operations
 * @returns Promise<boolean> - True if admin was created, false if already exists
 */
export async function seedAdminUser(
  userModel: Model<UserDocument>,
): Promise<{ created: boolean; message: string }> {
  try {
    // Check if admin user already exists
    const existingAdmin = await userModel.findOne({
      role: UserRole.ADMIN,
    });

    if (existingAdmin) {
      return {
        created: false,
        message: 'Admin user already exists',
      };
    }

    // Hash the password
    const hashedPassword = await bcrypt.hash(ADMIN_CONFIG.password, 12);

    // Create admin user
    const adminUser = new userModel({
      email: ADMIN_CONFIG.email,
      passwordHash: hashedPassword,
      name: ADMIN_CONFIG.name,
      phoneNumber: ADMIN_CONFIG.phoneNumber,
      role: UserRole.ADMIN,
      provider: AuthProvider.EMAIL,
      isEmailVerified: true,
      isPhoneVerified: true,
      isActive: true,
      rating: 0,
      totalRatings: 0,
    });

    await adminUser.save();

    console.log('='.repeat(60));
    console.log('ADMIN USER CREATED SUCCESSFULLY');
    console.log('='.repeat(60));
    console.log(`Email: ${ADMIN_CONFIG.email}`);
    console.log(`Password: ${ADMIN_CONFIG.password}`);
    console.log('Please change the default password after first login!');
    console.log('='.repeat(60));

    return {
      created: true,
      message: `Admin user created with email: ${ADMIN_CONFIG.email}`,
    };
  } catch (error) {
    console.error('Error seeding admin user:', error);
    throw error;
  }
}

/**
 * Create additional admin users
 *
 * @param userModel - The User model to use for database operations
 * @param admins - Array of admin user configurations
 */
export async function seedAdditionalAdmins(
  userModel: Model<UserDocument>,
  admins: Array<{
    email: string;
    password: string;
    name: string;
    phoneNumber?: string;
  }>,
): Promise<{ created: number; skipped: number }> {
  let created = 0;
  let skipped = 0;

  for (const admin of admins) {
    const existingAdmin = await userModel.findOne({ email: admin.email });

    if (existingAdmin) {
      skipped++;
      continue;
    }

    const hashedPassword = await bcrypt.hash(admin.password, 12);

    await userModel.create({
      email: admin.email,
      passwordHash: hashedPassword,
      name: admin.name,
      phoneNumber: admin.phoneNumber,
      role: UserRole.ADMIN,
      provider: AuthProvider.EMAIL,
      isEmailVerified: true,
      isPhoneVerified: true,
      isActive: true,
      rating: 0,
      totalRatings: 0,
    });

    created++;
  }

  return { created, skipped };
}

/**
 * Reset admin password
 *
 * @param userModel - The User model to use for database operations
 * @param email - Admin email
 * @param newPassword - New password
 */
export async function resetAdminPassword(
  userModel: Model<UserDocument>,
  email: string,
  newPassword: string,
): Promise<{ success: boolean; message: string }> {
  const admin = await userModel.findOne({
    email,
    role: UserRole.ADMIN,
  });

  if (!admin) {
    return {
      success: false,
      message: 'Admin user not found',
    };
  }

  const hashedPassword = await bcrypt.hash(newPassword, 12);
  admin.passwordHash = hashedPassword;
  await admin.save();

  return {
    success: true,
    message: 'Admin password reset successfully',
  };
}

export default seedAdminUser;
