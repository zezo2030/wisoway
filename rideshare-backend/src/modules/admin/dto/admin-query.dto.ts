import {
  IsOptional,
  IsEnum,
  IsString,
  IsBoolean,
  IsInt,
  Min,
  Max,
  IsDateString,
  IsBooleanString,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';
import { UserRole } from '../../users/schemas/user.schema';
import { PaginationDto } from '../../../common/dto/pagination.dto';

/**
 * Query DTO for admin user list
 */
export class AdminUserQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  })
  @IsBoolean()
  isActive?: boolean;
}

/**
 * Query DTO for admin trip list
 */
export class AdminTripQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(['active', 'hidden', 'completed', 'cancelled', 'expired'])
  status?: string;

  @IsOptional()
  @IsString()
  driverId?: string;
}

/**
 * Query DTO for admin payment list
 */
export class AdminPaymentQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(['pending', 'approved', 'rejected', 'refunded'])
  status?: string;

  @IsOptional()
  @IsEnum(['wallet', 'paymob', 'manual', 'communication_fee'])
  method?: string;

  @IsOptional()
  @IsEnum(['trip', 'communication_fee', 'wallet_topup', 'wallet_trip_charge'])
  paymentType?: string;

  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  })
  @IsBoolean()
  walletOnly?: boolean;
}

/**
 * Query DTO for admin vehicle list
 */
export class AdminVehicleQueryDto extends PaginationDto {
  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  })
  @IsBoolean()
  isVerified?: boolean;

  @IsOptional()
  @IsString()
  driverId?: string;
}

/**
 * DTO for changing user role
 */
export class ChangeRoleDto {
  @IsEnum(UserRole)
  role: UserRole;
}

/**
 * DTO for toggling user ban status
 */
export class ToggleBanDto {
  @IsBoolean()
  isActive: boolean;
}

/**
 * DTO for verifying vehicle
 */
export class VerifyVehicleDto {
  @IsBoolean()
  isVerified: boolean;
}

/**
 * DTO for approving/rejecting driver
 */
export class ApproveDriverDto {
  @IsBoolean()
  approved: boolean;
}

/**
 * Query DTO for report generation
 */
export class ReportQueryDto {
  @IsEnum(['revenue', 'users', 'trips'])
  type: 'revenue' | 'users' | 'trips';

  @IsDateString()
  startDate: string;

  @IsDateString()
  endDate: string;
}

/**
 * Response interface for dashboard stats
 */
export interface DashboardStats {
  totalUsers: number;
  totalDrivers: number;
  totalPassengers: number;
  activeTrips: number;
  completedTrips: number;
  totalRevenue: number;
  pendingPayments: number;
  pendingManualTopups: number;
  pendingVehicleVerifications: number;
}

/**
 * Query DTO for admin booking list
 */
export class AdminBookingQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(['pending', 'confirmed', 'cancelled', 'completed'])
  status?: string;

  @IsOptional()
  @IsString()
  userId?: string;

  @IsOptional()
  @IsString()
  tripId?: string;
}

/**
 * Query DTO for admin rating list
 */
export class AdminRatingQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  userId?: string;

  @IsOptional()
  @IsString()
  tripId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  minRating?: number;
}

/**
 * Query DTO for admin notification list
 */
export class AdminNotificationQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  type?: string;
}

/**
 * Query DTO for admin chat rooms
 */
export class AdminChatQueryDto extends PaginationDto {}

/**
 * DTO for broadcasting a notification
 */
export class BroadcastNotificationDto {
  @IsString()
  title: string;

  @IsString()
  body: string;

  @IsOptional()
  @IsEnum(UserRole)
  targetRole?: UserRole;
}

/**
 * Response interface for reports
 */
export interface ReportResponse {
  type: 'revenue' | 'users' | 'trips';
  period: {
    start: string;
    end: string;
  };
  summary: {
    total: number;
    count: number;
  };
  breakdown: Array<{
    date: string;
    amount?: number;
    count: number;
  }>;
}
