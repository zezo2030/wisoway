import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type MessageDocument = Message & Document;

@Schema({ timestamps: true })
export class Message {
  @Prop({ type: Types.ObjectId, ref: 'ChatRoom', required: true, index: true })
  chatRoomId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  senderId: Types.ObjectId;

  @Prop()
  senderName: string;

  @Prop({ required: true, minlength: 1, maxlength: 2000 })
  text: string;
}

export const MessageSchema = SchemaFactory.createForClass(Message);

MessageSchema.index({ chatRoomId: 1, createdAt: -1 });
