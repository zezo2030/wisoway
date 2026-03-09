import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { UserEntity } from '../../database/entities/user.entity';
import { OtpCodeEntity } from '../../database/entities/otp-code.entity';
import { PendingRegistrationEntity } from '../../database/entities/pending-registration.entity';
import { PgUserRole } from '../../database/entities/shared.enums';
import { UpdateUserDto } from './dto/update-user.dto';

export interface UserStats {
  totalTrips: number;
  totalBookings: number;
  completedTrips: number;
  rating: number;
  totalRatings: number;
  memberSince: Date;
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(UserEntity)
    private userRepo: Repository<UserEntity>,
    @InjectRepository(OtpCodeEntity)
    private otpCodeRepo: Repository<OtpCodeEntity>,
    @InjectRepository(PendingRegistrationEntity)
    private pendingRegistrationRepo: Repository<PendingRegistrationEntity>,
  ) {}

  async create(userData: Partial<UserEntity>): Promise<UserEntity> {
    if (this.shouldHashPassword(userData.passwordHash)) {
      userData.passwordHash = await bcrypt.hash(userData.passwordHash!, 12);
    }
    const user = this.userRepo.create(userData);
    return this.userRepo.save(user);
  }

  async findByEmail(email: string): Promise<UserEntity | null> {
    return this.userRepo.findOne({ where: { email } });
  }

  async findByEmailWithPassword(email: string): Promise<UserEntity | null> {
    return this.userRepo
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.email = :email', { email })
      .getOne();
  }

  async findByPhone(phoneNumber: string): Promise<UserEntity | null> {
    return this.userRepo.findOne({ where: { phoneNumber } });
  }

  async findById(id: string): Promise<UserEntity> {
    const user = await this.userRepo.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  async findByProviderId(
    provider: string,
    providerId: string,
  ): Promise<UserEntity | null> {
    return this.userRepo.findOne({ where: { provider, providerId } });
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<UserEntity> {
    const user = await this.findById(id);
    this.userRepo.merge(user, updateUserDto as any);
    return this.userRepo.save(user);
  }

  async updateRole(id: string, role: string): Promise<UserEntity> {
    const user = await this.findById(id);
    user.role = role as PgUserRole;
    return this.userRepo.save(user);
  }

  async updateRefreshToken(id: string, refreshToken: string): Promise<void> {
    const hashedToken = await bcrypt.hash(refreshToken, 12);
    await this.userRepo.update(id, { refreshToken: hashedToken });
  }

  async updateFcmToken(id: string, fcmToken: string): Promise<void> {
    await this.userRepo.update(id, { fcmToken });
  }

  async linkPhone(id: string, phoneNumber: string): Promise<UserEntity> {
    const existingUser = await this.findByPhone(phoneNumber);
    if (existingUser && existingUser.id !== id) {
      throw new ConflictException(
        'Phone number already linked to another account',
      );
    }
    const user = await this.findById(id);
    user.phoneNumber = phoneNumber;
    user.isPhoneVerified = true;
    return this.userRepo.save(user);
  }

  async linkProvider(
    id: string,
    provider: string,
    providerId: string,
  ): Promise<UserEntity> {
    const user = await this.findById(id);
    user.provider = provider;
    user.providerId = providerId;
    return this.userRepo.save(user);
  }

  async delete(id: string): Promise<void> {
    const result = await this.userRepo.delete(id);
    if (result.affected === 0) {
      throw new NotFoundException('User not found');
    }
  }

  async getUserStats(id: string): Promise<UserStats> {
    const user = await this.findById(id);
    return {
      totalTrips: 0,
      totalBookings: 0,
      completedTrips: 0,
      rating: user.rating,
      totalRatings: user.totalRatings,
      memberSince: user.createdAt,
    };
  }

  async updateRating(userId: string, newRating: number): Promise<void> {
    const user = await this.findById(userId);
    const totalRatings = user.totalRatings + 1;
    const currentTotal = Number(user.rating) * user.totalRatings;
    const newAverage = (currentTotal + newRating) / totalRatings;

    user.rating = parseFloat(newAverage.toFixed(2));
    user.totalRatings = totalRatings;
    await this.userRepo.save(user);
  }

  async deactivate(id: string): Promise<void> {
    await this.userRepo.update(id, { isActive: false });
  }

  async activate(id: string): Promise<void> {
    await this.userRepo.update(id, { isActive: true });
  }

  // OTP Code methods
  async createOtpCode(
    phoneNumber: string,
    code: string,
  ): Promise<OtpCodeEntity> {
    await this.otpCodeRepo.delete({ phoneNumber, isUsed: false });
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
    const otpCode = this.otpCodeRepo.create({ phoneNumber, code, expiresAt });
    return this.otpCodeRepo.save(otpCode);
  }

  async findOtpCode(
    phoneNumber: string,
    code: string,
  ): Promise<OtpCodeEntity | null> {
    return this.otpCodeRepo.findOne({
      where: { phoneNumber, code, isUsed: false },
    });
  }

  async markOtpCodeAsUsed(otpCodeId: string): Promise<void> {
    await this.otpCodeRepo.update(otpCodeId, { isUsed: true });
  }

  async cleanupExpiredOtpCodes(): Promise<void> {
    await this.otpCodeRepo.delete({ expiresAt: LessThan(new Date()) });
  }

  // Pending Registration methods
  async createPendingRegistration(
    data: any,
  ): Promise<PendingRegistrationEntity> {
    if (this.shouldHashPassword(data.passwordHash)) {
      data.passwordHash = await bcrypt.hash(data.passwordHash, 12);
    }

    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    const pending = await this.pendingRegistrationRepo.findOne({
      where: { phoneNumber: data.phoneNumber },
    });
    if (pending) {
      this.pendingRegistrationRepo.merge(pending, { ...data, expiresAt });
      return this.pendingRegistrationRepo.save(pending);
    } else {
      const newPending = this.pendingRegistrationRepo.create({
        ...data,
        expiresAt,
      } as Partial<PendingRegistrationEntity>);
      return this.pendingRegistrationRepo.save(newPending);
    }
  }

  async findPendingByPhone(
    phoneNumber: string,
  ): Promise<PendingRegistrationEntity | null> {
    return this.pendingRegistrationRepo
      .createQueryBuilder('pending')
      .addSelect('pending.passwordHash')
      .where('pending.phoneNumber = :phoneNumber', { phoneNumber })
      .getOne();
  }

  async findPendingByEmail(
    email: string,
  ): Promise<PendingRegistrationEntity | null> {
    return this.pendingRegistrationRepo.findOne({ where: { email } });
  }

  async deletePendingByPhone(phoneNumber: string): Promise<void> {
    await this.pendingRegistrationRepo.delete({ phoneNumber });
  }

  private shouldHashPassword(passwordHash?: string | null): passwordHash is string {
    if (!passwordHash) {
      return false;
    }

    return (
      !passwordHash.startsWith('$2b$') &&
      !passwordHash.startsWith('$2a$') &&
      !passwordHash.startsWith('$2y$')
    );
  }
}
