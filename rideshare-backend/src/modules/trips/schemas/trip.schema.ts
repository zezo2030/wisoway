import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { Seat, SeatSchema } from './seat.schema';

export type TripDocument = Trip & Document;

@Schema({ timestamps: true })
export class Trip {
  @Prop({ type: String, required: true, ref: 'User' })
  driverId: string;

  @Prop({ type: String, default: null })
  driverName: string;

  @Prop({
    type: {
      name: { type: String, required: true, maxlength: 255 },
      latitude: { type: Number, required: true, min: -90, max: 90 },
      longitude: { type: Number, required: true, min: -180, max: 180 },
      address: { type: String, maxlength: 500, default: null },
    },
    required: true,
  })
  from: {
    name: string;
    latitude: number;
    longitude: number;
    address?: string;
  };

  @Prop({
    type: {
      name: { type: String, required: true, maxlength: 255 },
      latitude: { type: Number, required: true, min: -90, max: 90 },
      longitude: { type: Number, required: true, min: -180, max: 180 },
      address: { type: String, maxlength: 500, default: null },
    },
    required: true,
  })
  to: {
    name: string;
    latitude: number;
    longitude: number;
    address?: string;
  };

  @Prop({ type: Date, required: true })
  departureTime: Date;

  @Prop({ type: Number, required: true, min: 0 })
  price: number;

  @Prop({
    type: String,
    required: true,
    enum: ['EGP', 'JOD', 'SAR', 'AED', 'QAR'],
    default: 'JOD',
  })
  currency: string;

  @Prop({ type: Number, required: true, min: 1, max: 50 })
  totalSeats: number;

  @Prop({ type: Number, required: true, min: 0 })
  availableSeats: number;

  @Prop({
    type: {
      rows: { type: Number, required: true, min: 1, max: 10 },
      seatsPerRow: { type: Number, required: true, min: 1, max: 6 },
      preventGenderMixing: { type: Boolean, default: false },
    },
    required: true,
  })
  seatLayout: {
    rows: number;
    seatsPerRow: number;
    preventGenderMixing: boolean;
  };

  @Prop({ type: [SeatSchema], required: true })
  seats: Seat[];

  @Prop({
    type: String,
    required: true,
    enum: ['active', 'hidden', 'completed', 'cancelled', 'expired'],
    default: 'active',
  })
  status: string;

  @Prop({ type: String, required: true, default: 'not_paid' })
  communicationFeeStatus: string;

  @Prop({ type: String, default: null })
  carImageUrl: string;

  @Prop({ type: Boolean, required: true, default: true })
  isVisible: boolean;

  /** Whether driver wallet was charged once for this trip (one charge per trip) */
  @Prop({ type: Boolean, required: false, default: false })
  driverWalletChargeApplied?: boolean;

  @Prop({ type: Date, required: false })
  driverWalletChargeAt?: Date;
}

export const TripSchema = SchemaFactory.createForClass(Trip);

TripSchema.index({ driverId: 1 });
TripSchema.index({ status: 1, isVisible: 1, availableSeats: 1 });
TripSchema.index({ departureTime: 1 });
TripSchema.index({ 'from.latitude': 1, 'from.longitude': '2dsphere' });
TripSchema.index({ 'to.latitude': 1, 'to.longitude': '2dsphere' });
