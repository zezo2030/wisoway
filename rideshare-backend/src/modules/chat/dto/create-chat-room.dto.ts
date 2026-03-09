import { IsString, IsNotEmpty, IsMongoId } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateChatRoomDto {
  @ApiProperty({ description: 'Trip ID' })
  @IsString()
  @IsNotEmpty()
  @IsMongoId()
  tripId: string;
}
