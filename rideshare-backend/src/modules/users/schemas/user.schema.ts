import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type UserDocument = User & Document;

export enum UserRole {
  PASSENGER = 'passenger',
  DRIVER = 'driver',
  ADMIN = 'admin',
}

export enum AuthProvider {
  EMAIL = 'email',
  GOOGLE = 'google',
  FACEBOOK = 'facebook',
  PHONE = 'phone',
}

export enum Gender {
  MALE = 'male',
  FEMALE = 'female',
}

@Schema({
  timestamps: true,
  collection: 'users',
})
export class User {
  _id: Types.ObjectId;

  @Prop({
    type: String,
    required: false,
    unique: true,
    sparse: true,
    lowercase: true,
    trim: true,
    match: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
  })
  email: string;

  @Prop({
    type: String,
    required: false,
    select: false,
  })
  passwordHash: string;

  @Prop({
    type: String,
    required: false,
    unique: true,
    sparse: true,
    match: /^\+[1-9]\d{1,14}$/,
  })
  phoneNumber: string;

  @Prop({
    type: String,
    required: true,
    minlength: 2,
    maxlength: 100,
    trim: true,
  })
  name: string;

  @Prop({
    type: String,
    required: false,
    enum: [Gender.MALE, Gender.FEMALE],
  })
  gender: Gender;

  @Prop({
    type: String,
    required: true,
    enum: [UserRole.PASSENGER, UserRole.DRIVER, UserRole.ADMIN],
    default: UserRole.PASSENGER,
  })
  role: UserRole;

  @Prop({
    type: String,
    required: false,
    maxlength: 500,
  })
  photoUrl: string;

  @Prop({
    type: String,
    required: true,
    enum: [
      AuthProvider.EMAIL,
      AuthProvider.GOOGLE,
      AuthProvider.FACEBOOK,
      AuthProvider.PHONE,
    ],
    default: AuthProvider.EMAIL,
  })
  provider: AuthProvider;

  @Prop({
    type: String,
    required: false,
  })
  providerId: string;

  @Prop({
    type: Number,
    required: true,
    min: 0,
    max: 5,
    default: 0,
  })
  rating: number;

  @Prop({
    type: Number,
    required: true,
    min: 0,
    default: 0,
  })
  totalRatings: number;

  @Prop({
    type: Boolean,
    required: true,
    default: false,
  })
  isPhoneVerified: boolean;

  @Prop({
    type: Boolean,
    required: true,
    default: false,
  })
  isEmailVerified: boolean;

  @Prop({
    type: Boolean,
    required: true,
    default: false,
  })
  isDriverApproved: boolean;

  @Prop({
    type: Boolean,
    required: true,
    default: true,
  })
  isActive: boolean;

  @Prop({
    type: String,
    required: false,
  })
  fcmToken: string;

  @Prop({
    type: String,
    required: false,
    select: false,
  })
  refreshToken: string;

  /** Driver wallet: balance in walletCurrency (used for trip communication charges) */
  @Prop({ type: Number, required: false, min: 0, default: 0 })
  walletBalance?: number;

  @Prop({ type: String, required: false, default: 'EGP', maxlength: 5 })
  walletCurrency?: string;

  /** Driver: whether the one lifetime free trip has been used */
  @Prop({ type: Boolean, required: false, default: false })
  hasUsedLifetimeFreeTrip?: boolean;

  @Prop({ type: Date })
  createdAt: Date;

  @Prop({ type: Date })
  updatedAt: Date;
}

export const UserSchema = SchemaFactory.createForClass(User);

// Indexes
UserSchema.index({ role: 1 });
UserSchema.index({ provider: 1, providerId: 1 });

// Exclude password and refreshToken from JSON serialization
UserSchema.set('toJSON', {
  transform: (doc, ret) => {
    const { passwordHash, refreshToken, ...rest } = ret;
    return rest;
  },
});

UserSchema.set('toObject', {
  transform: (doc, ret) => {
    const { passwordHash, refreshToken, ...rest } = ret;
    return rest;
  },
});
