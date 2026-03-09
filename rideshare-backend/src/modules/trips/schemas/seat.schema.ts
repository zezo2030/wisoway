import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type SeatDocument = Seat & Document;

@Schema({ _id: false })
export class Seat {
  @Prop({ type: String, required: true })
  seatNumber: string;

  @Prop({ type: String, default: null })
  userId: string;

  @Prop({ type: String, default: null })
  userName: string;

  @Prop({ type: String, enum: ['male', 'female'], default: null })
  gender: string;

  @Prop({ type: Date, default: null })
  bookedAt: Date;

  @Prop({
    type: String,
    enum: ['available', 'booked', 'locked'],
    default: 'available',
  })
  status: string;
}

export const SeatSchema = SchemaFactory.createForClass(Seat);
