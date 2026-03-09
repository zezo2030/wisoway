import { Model } from 'mongoose';
import {
  CommunicationFee,
  CommunicationFeeDocument,
} from '../schemas/communication-fee.schema';

/**
 * Seed data for communication fees by country
 * EG: 50 EGP (Egypt)
 * JO: 2 JOD (Jordan)
 * SA: 10 SAR (Saudi Arabia)
 * AE: 25 AED (UAE)
 * QA: 25 QAR (Qatar)
 */
export const communicationFeeSeedData = [
  {
    countryCode: 'EG',
    feeAmount: 50,
    currency: 'EGP',
    isActive: true,
  },
  {
    countryCode: 'JO',
    feeAmount: 2,
    currency: 'JOD',
    isActive: true,
  },
  {
    countryCode: 'SA',
    feeAmount: 10,
    currency: 'SAR',
    isActive: true,
  },
  {
    countryCode: 'AE',
    feeAmount: 25,
    currency: 'AED',
    isActive: true,
  },
  {
    countryCode: 'QA',
    feeAmount: 25,
    currency: 'QAR',
    isActive: true,
  },
];

/**
 * Seed communication fees collection
 */
export async function seedCommunicationFees(
  communicationFeeModel: Model<CommunicationFeeDocument>,
): Promise<void> {
  console.log('Seeding communication fees...');

  for (const feeData of communicationFeeSeedData) {
    const existing = await communicationFeeModel
      .findOne({
        countryCode: feeData.countryCode,
      })
      .exec();

    if (!existing) {
      await communicationFeeModel.create(feeData);
      console.log(
        `Created communication fee for ${feeData.countryCode}: ${feeData.feeAmount} ${feeData.currency}`,
      );
    } else {
      console.log(
        `Communication fee for ${feeData.countryCode} already exists, skipping...`,
      );
    }
  }

  console.log('Communication fees seeding completed!');
}

/**
 * Clear all communication fees (for testing)
 */
export async function clearCommunicationFees(
  communicationFeeModel: Model<CommunicationFeeDocument>,
): Promise<void> {
  await communicationFeeModel.deleteMany({}).exec();
  console.log('All communication fees cleared');
}
