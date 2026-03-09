import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type PaymentDocument = Payment & Document;

@Schema({ timestamps: true })
export class Payment {
  @Prop({ type: String, ref: 'Trip', default: null })
  tripId?: string;

  @Prop({ type: String, ref: 'Booking', default: null })
  bookingId?: string;

  @Prop({ type: String, required: true, ref: 'User' })
  userId: string;

  @Prop({ type: Number, required: true, min: 0.01 })
  amount: number;

  @Prop({ type: String, required: true, default: 'EGP' })
  currency: string;

  @Prop({
    type: String,
    required: true,
    enum: ['stripe', 'paymob', 'manual', 'communication_fee', 'cliq_a2a'],
  })
  method: string;

  @Prop({
    type: String,
    required: true,
    enum: ['pending', 'approved', 'rejected', 'refunded'],
    default: 'pending',
  })
  status: string;

  @Prop({
    type: String,
    required: true,
    enum: ['trip', 'communication_fee', 'wallet_topup', 'wallet_trip_charge'],
    default: 'trip',
  })
  paymentType: string;

  /** For wallet: credit = top-up, debit = trip charge */
  @Prop({
    type: String,
    required: false,
    enum: ['credit', 'debit'],
  })
  direction?: string;

  @Prop({ type: String, default: null })
  proofImageUrl?: string;

  @Prop({ type: String, default: null })
  walletNumber?: string;

  @Prop({ type: String, default: null })
  transactionId?: string;

  @Prop({ type: String, default: null })
  paymentGatewayRef?: string;

  @Prop({ type: String, default: null })
  recipientAliasType?: string;

  @Prop({ type: String, default: null })
  recipientAliasValue?: string;

  @Prop({ type: String, default: null })
  adminNote?: string;
}

export const PaymentSchema = SchemaFactory.createForClass(Payment);

// Indexes
PaymentSchema.index({ userId: 1 });
PaymentSchema.index({ tripId: 1 });
PaymentSchema.index({ bookingId: 1 });
PaymentSchema.index({ status: 1 });
