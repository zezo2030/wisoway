import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserEntity } from '../../database/entities/user.entity';
import { OtpCodeEntity } from '../../database/entities/otp-code.entity';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
@Module({
  imports: [
    TypeOrmModule.forFeature([UserEntity, OtpCodeEntity]),
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
