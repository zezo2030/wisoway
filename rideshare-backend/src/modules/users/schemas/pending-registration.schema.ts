import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type PendingRegistrationDocument = PendingRegistration & Document;

export enum PendingRegistrationRole {
  PASSENGER = 'passenger',
  DRIVER = 'driver',
}

export enum PendingRegistrationGender {
  MALE = 'male',
  FEMALE = 'female',
}

@Schema({
  timestamps: true,
  collection: 'pending_registrations',
})
export class PendingRegistration {
  _id: Types.ObjectId;

  @Prop({
    type: String,
    required: true,
    unique: true,
    match: /^\+[1-9]\d{1,14}$/,
  })
  phoneNumber: string;

  @Prop({
    type: String,
    required: true,
    unique: true,
    sparse: true,
    lowercase: true,
    trim: true,
    match: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
  })
  email: string;

  @Prop({
    type: String,
    required: true,
    select: false,
  })
  passwordHash: string;

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
    enum: [PendingRegistrationGender.MALE, PendingRegistrationGender.FEMALE],
  })
  gender: PendingRegistrationGender;

  @Prop({
    type: String,
    required: true,
    enum: [PendingRegistrationRole.PASSENGER, PendingRegistrationRole.DRIVER],
    default: PendingRegistrationRole.PASSENGER,
  })
  role: PendingRegistrationRole;

  @Prop({
    type: Date,
    required: true,
    default: () => new Date(Date.now() + 5 * 60 * 1000),
    index: { expireAfterSeconds: 0 },
  })
  expiresAt: Date;

  @Prop({ type: Date })
  createdAt: Date;

  @Prop({ type: Date })
  updatedAt: Date;
}

export const PendingRegistrationSchema =
  SchemaFactory.createForClass(PendingRegistration);

// Indexes
PendingRegistrationSchema.index({ phoneNumber: 1 }, { unique: true });
PendingRegistrationSchema.index({ email: 1 }, { unique: true, sparse: true });
