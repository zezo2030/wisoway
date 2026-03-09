import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type BookingDocument = Booking & Document;

@Schema({ timestamps: true })
export class Booking {
  @Prop({ type: String, required: true, ref: 'Trip' })
  tripId: string;

  @Prop({ type: String, required: true, ref: 'User' })
  userId: string;

  @Prop({ type: String, required: true })
  seatNumber: string;

  @Prop({
    type: String,
    required: true,
    enum: ['pending', 'confirmed', 'cancelled', 'completed'],
    default: 'pending',
  })
  status: string;

  @Prop({ type: Boolean, required: true, default: false })
  hasDriverPaidToContact: boolean;

  @Prop({ type: Boolean, required: true, default: false })
  sharePhoneWithDriver: boolean;

  @Prop({ type: String, default: null })
  cancellationReason?: string;

  @Prop({ type: Date, default: null })
  cancelledAt?: Date;

  @Prop({
    type: String,
    enum: ['passenger', 'driver', 'system'],
    default: null,
  })
  cancelledBy?: string;
}

export const BookingSchema = SchemaFactory.createForClass(Booking);

// Indexes
BookingSchema.index({ userId: 1, tripId: 1 }, { unique: true });
BookingSchema.index({ tripId: 1 });
BookingSchema.index({ userId: 1 });
BookingSchema.index({ status: 1 });
