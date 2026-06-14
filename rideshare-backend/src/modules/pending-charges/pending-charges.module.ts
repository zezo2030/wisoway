import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PendingChargeEntity } from '../../database/entities/pending-charge.entity';
import { WalletAccountEntity } from '../../database/entities/wallet-account.entity';
import { WalletTransactionEntity } from '../../database/entities/wallet-transaction.entity';
import { WalletModule } from '../wallet/wallet.module';
import { PendingChargesController } from './pending-charges.controller';
import { PendingChargesService } from './pending-charges.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PendingChargeEntity,
      WalletAccountEntity,
      WalletTransactionEntity,
    ]),
    WalletModule,
  ],
  controllers: [PendingChargesController],
  providers: [PendingChargesService],
  exports: [PendingChargesService],
})
export class PendingChargesModule {}
