import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type OtpCodeDocument = OtpCode & Document;

@Schema({
  timestamps: true,
  collection: 'otpcodes',
})
export class OtpCode {
  @Prop({
    type: String,
    required: true,
    match: /^\+[1-9]\d{1,14}$/,
  })
  phoneNumber: string;

  @Prop({
    type: String,
    required: true,
    length: 6,
  })
  code: string;

  @Prop({
    type: Date,
    required: true,
    default: () => new Date(Date.now() + 5 * 60 * 1000), // 5 minutes from now
  })
  expiresAt: Date;

  @Prop({
    type: Boolean,
    required: true,
    default: false,
  })
  isUsed: boolean;

  @Prop({ type: Date })
  createdAt: Date;

  @Prop({ type: Date })
  updatedAt: Date;
}

export const OtpCodeSchema = SchemaFactory.createForClass(OtpCode);

// Indexes
OtpCodeSchema.index({ phoneNumber: 1, code: 1 });
OtpCodeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 }); // TTL index for auto-deletion
