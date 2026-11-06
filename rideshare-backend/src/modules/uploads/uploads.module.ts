import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { UploadsService } from './uploads.service';
import { UploadsController } from './uploads.controller';
import { PrivateDocumentsService } from './private-documents.service';

@Module({
  imports: [
    MulterModule.register({
      limits: {
        fileSize: 10 * 1024 * 1024, // 10MB max
      },
    }),
  ],
  controllers: [UploadsController],
  providers: [UploadsService, PrivateDocumentsService],
  exports: [UploadsService, PrivateDocumentsService],
})
export class UploadsModule {}
