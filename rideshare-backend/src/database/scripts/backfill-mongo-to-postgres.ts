import 'reflect-metadata';
import mongoose from 'mongoose';
import { AppDataSource } from '../data-source';
import { UserEntity } from '../entities/user.entity';
import { TripEntity } from '../entities/trip.entity';
import { WalletAccountEntity } from '../entities/wallet-account.entity';
import {
  PgUserRole,
  TripStatus,
  WalletAccountType,
} from '../entities/shared.enums';

type LegacyUser = {
  _id: string;
  email?: string;
  phoneNumber?: string;
  name?: string;
  passwordHash?: string;
  role?: 'passenger' | 'driver' | 'admin';
  isActive?: boolean;
  fcmToken?: string;
  walletBalance?: number;
  walletCurrency?: string;
};

type LegacyTrip = {
  _id: string;
  driverId: string;
  from: { name: string; latitude: number; longitude: number };
  to: { name: string; latitude: number; longitude: number };
  departureTime: Date;
  price: number;
  currency?: string;
  totalSeats: number;
  availableSeats: number;
  status: 'active' | 'hidden' | 'completed' | 'cancelled';
  isVisible?: boolean;
};

async function run() {
  const mongoUri =
    process.env.MONGODB_URI || 'mongodb://localhost:27017/rideshare';
  await mongoose.connect(mongoUri);
  await AppDataSource.initialize();
  const mongoDb = mongoose.connection.db;
  if (!mongoDb) {
    throw new Error('MongoDB connection is not initialized');
  }

  const usersCollection = mongoDb.collection<LegacyUser>('users');
  const tripsCollection = mongoDb.collection<LegacyTrip>('trips');

  const userRepo = AppDataSource.getRepository(UserEntity);
  const tripRepo = AppDataSource.getRepository(TripEntity);
  const walletRepo = AppDataSource.getRepository(WalletAccountEntity);

  const legacyUsers = await usersCollection.find({}).toArray();
  const userIdMap = new Map<string, string>();

  for (const user of legacyUsers) {
    const saved = await userRepo.save(
      userRepo.create({
        email: user.email || null,
        phoneNumber: user.phoneNumber || null,
        name: user.name || 'User',
        passwordHash: user.passwordHash || null,
        role: (user.role || 'passenger') as PgUserRole,
        isActive: user.isActive ?? true,
        fcmToken: user.fcmToken || null,
      } as Partial<UserEntity>),
    );
    userIdMap.set(String(user._id), saved.id);

    const accountType =
      user.role === 'driver'
        ? WalletAccountType.DRIVER
        : WalletAccountType.RIDER;
    const balance = Number(user.walletBalance || 0);
    await walletRepo.save(
      walletRepo.create({
        userId: saved.id,
        accountType,
        currency: user.walletCurrency || 'EGP',
        balance: balance.toFixed(2),
        isActive: true,
      }),
    );
  }

  const legacyTrips = await tripsCollection.find({}).toArray();
  for (const trip of legacyTrips) {
    const mappedDriverId = userIdMap.get(String(trip.driverId));
    if (!mappedDriverId) {
      continue;
    }
    await tripRepo.save(
      tripRepo.create({
        driverId: mappedDriverId,
        fromName: trip.from.name,
        toName: trip.to.name,
        fromPoint: {
          type: 'Point',
          coordinates: [trip.from.longitude, trip.from.latitude],
        },
        toPoint: {
          type: 'Point',
          coordinates: [trip.to.longitude, trip.to.latitude],
        },
        departureTime: new Date(trip.departureTime),
        price: Number(trip.price).toFixed(2),
        currency: trip.currency || 'EGP',
        totalSeats: trip.totalSeats,
        availableSeats: trip.availableSeats,
        status: trip.status as TripStatus,
        isVisible: trip.isVisible ?? true,
      } as Partial<TripEntity>),
    );
  }

  await AppDataSource.destroy();
  await mongoose.disconnect();

  console.log(
    `Backfill completed. Users: ${legacyUsers.length}, Trips: ${legacyTrips.length}`,
  );
}

run().catch(async (error) => {
  console.error('Backfill failed', error);
  try {
    await AppDataSource.destroy();
  } catch {}
  try {
    await mongoose.disconnect();
  } catch {}
  process.exit(1);
});
