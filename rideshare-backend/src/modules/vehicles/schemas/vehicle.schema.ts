import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type VehicleDocument = Vehicle & Document;

@Schema({ timestamps: true })
export class Vehicle {
  @Prop({ type: String, required: true, ref: 'User' })
  driverId: string;

  @Prop({ type: String, required: true })
  vehicleType: string;

  @Prop({ type: String, required: true, maxlength: 20 })
  plateNumber: string;

  @Prop({ type: String, required: true, maxlength: 100 })
  model: string;

  @Prop({ type: Number, required: true, min: 1, max: 50 })
  seats: number;

  @Prop({ type: String, default: null })
  licenseImageUrl: string;

  @Prop({ type: String, default: null })
  vehicleLicenseImageUrl: string;

  @Prop({ type: Boolean, default: false })
  isVerified: boolean;
}

export const VehicleSchema = SchemaFactory.createForClass(Vehicle);

VehicleSchema.index({ driverId: 1 }, { unique: true });
