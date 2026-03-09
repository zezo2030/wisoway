import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type RatingDocument = Rating & Document;

@Schema({ timestamps: true })
export class Rating {
  @Prop({ type: Types.ObjectId, required: true, ref: 'User', index: true })
  fromUserId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, ref: 'User', index: true })
  toUserId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, ref: 'Trip', index: true })
  tripId: Types.ObjectId;

  @Prop({ required: true, min: 1, max: 5 })
  rating: number;

  @Prop({ maxlength: 500 })
  comment?: string;

  @Prop({ enum: ['passenger', 'driver', 'admin'] })
  userRole?: string;

  @Prop({ enum: ['passenger', 'driver', 'admin'] })
  ratedRole?: string;

  @Prop({ default: Date.now })
  createdAt?: Date;
}

export const RatingSchema = SchemaFactory.createForClass(Rating);

RatingSchema.index({ fromUserId: 1, tripId: 1 }, { unique: true });
