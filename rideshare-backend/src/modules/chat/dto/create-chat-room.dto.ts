import { IsString, IsNotEmpty, IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateChatRoomDto {
  @ApiProperty({ description: 'Trip ID' })
  @IsString()
  @IsNotEmpty()
  @IsUUID()
  tripId: string;
}
