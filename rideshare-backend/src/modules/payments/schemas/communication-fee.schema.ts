import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type CommunicationFeeDocument = CommunicationFee & Document;

@Schema({ timestamps: true })
export class CommunicationFee {
  @Prop({
    type: String,
    required: true,
    unique: true,
    minlength: 2,
    maxlength: 5,
  })
  countryCode: string;

  @Prop({ type: Number, required: true, min: 0.01 })
  feeAmount: number;

  @Prop({ type: String, required: true })
  currency: string;

  @Prop({ type: Boolean, required: true, default: true })
  isActive: boolean;
}

export const CommunicationFeeSchema =
  SchemaFactory.createForClass(CommunicationFee);

// Index
