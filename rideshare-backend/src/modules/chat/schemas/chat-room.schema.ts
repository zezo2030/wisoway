import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type ChatRoomDocument = ChatRoom & Document;

@Schema({ timestamps: true })
export class ChatRoom {
  @Prop({ type: Types.ObjectId, ref: 'Trip', required: true, index: true })
  tripId: Types.ObjectId;

  @Prop([
    {
      userId: { type: Types.ObjectId, ref: 'User', required: true },
      joinedAt: { type: Date, default: Date.now },
    },
  ])
  participants: { userId: Types.ObjectId; joinedAt: Date }[];

  @Prop()
  lastMessage: string;

  @Prop()
  lastMessageTime: Date;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  lastMessageSenderId: Types.ObjectId;
}

export const ChatRoomSchema = SchemaFactory.createForClass(ChatRoom);

ChatRoomSchema.index({ 'participants.userId': 1 });
ChatRoomSchema.index({ lastMessageTime: -1 });
