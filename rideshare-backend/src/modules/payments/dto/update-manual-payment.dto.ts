import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PRIVATE_DOCUMENT_PREFIX } from '../../uploads/private-documents.service';

/** Body of `PATCH /payments/:id`. Only the keys present are written. */
export class UpdateManualPaymentDto {
  @ApiPropertyOptional({
    description: 'Receipt reference returned by POST /uploads/documents',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  @Matches(new RegExp(`^${PRIVATE_DOCUMENT_PREFIX}`), {
    message: 'Receipt must be uploaded through /uploads/documents',
  })
  proofImageUrl?: string;

  @ApiPropertyOptional({ example: '01012345678' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  walletNumber?: string;

  @ApiPropertyOptional({ description: 'Transfer reference or note' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  transactionId?: string;
}
