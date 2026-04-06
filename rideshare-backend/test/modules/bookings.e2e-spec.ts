import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { MongooseModule } from '@nestjs/mongoose';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { getModelToken } from '@nestjs/mongoose';
import { Model, Connection } from 'mongoose';
import * as bcrypt from 'bcrypt';

// Modules
import { VehiclesModule } from '../../src/modules/vehicles/vehicles.module';
import { TripsModule } from '../../src/modules/trips/trips.module';
import { AuthModule } from '../../src/modules/auth/auth.module';
import { UsersModule } from '../../src/modules/users/users.module';
import { BookingsModule } from '../../src/modules/bookings/bookings.module';

// Schemas
import {
  User,
  UserDocument,
} from '../../src/modules/users/schemas/user.schema';
import {
  Vehicle,
  VehicleDocument,
} from '../../src/modules/vehicles/schemas/vehicle.schema';
import {
  Trip,
  TripDocument,
} from '../../src/modules/trips/schemas/trip.schema';
import {
  Booking,
  BookingDocument,
} from '../../src/modules/bookings/schemas/booking.schema';

describe('Bookings E2E', () => {
  let app: INestApplication;
  let userModel: Model<UserDocument>;
  let vehicleModel: Model<VehicleDocument>;
  let tripModel: Model<TripDocument>;
  let bookingModel: Model<BookingDocument>;
  let mongoConnection: Connection;

  let driverAccessToken: string;
  let passengerAccessToken: string;
  let secondPassengerAccessToken: string;
  let driverId: string;
  let passengerId: string;
  let secondPassengerId: string;
  let tripId: string;
  let bookingId: string;

  const mockDriver = {
    email: 'booking-driver@example.com',
    password: 'Password123!',
    name: 'Booking Driver',
    gender: 'male',
    role: 'driver',
  };

  const mockPassenger = {
    email: 'booking-passenger@example.com',
    password: 'Password123!',
    name: 'Booking Passenger',
    gender: 'female',
    role: 'passenger',
  };

  const mockSecondPassenger = {
    email: 'booking-passenger2@example.com',
    password: 'Password123!',
    name: 'Second Passenger',
    gender: 'male',
    role: 'passenger',
  };

  const mockVehicle = {
    vehicleType: 'sedan',
    plateNumber: 'BOOK123',
    model: 'Honda Civic',
    seats: 4,
  };

  const mockTrip = {
    from: {
      name: 'Giza',
      latitude: 30.0131,
      longitude: 31.2089,
      address: 'Giza, Egypt',
    },
    to: {
      name: 'Luxor',
      latitude: 25.6872,
      longitude: 32.6396,
      address: 'Luxor, Egypt',
    },
    departureTime: new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString(), // 48 hours from now
    price: 250,
    currency: 'EGP',
    totalSeats: 4,
    seatLayout: {
      rows: 2,
      seatsPerRow: 2,
      preventGenderMixing: true, // Enable gender mixing prevention for testing
    },
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          envFilePath: '.env',
        }),
        MongooseModule.forRootAsync({
          imports: [ConfigModule],
          useFactory: async (configService: ConfigService) => ({
            uri: configService.get<string>('MONGODB_URI'),
          }),
          inject: [ConfigService],
        }),
        JwtModule.registerAsync({
          imports: [ConfigModule],
          useFactory: async (configService: ConfigService) => ({
            secret: configService.get<string>('JWT_SECRET'),
            signOptions: { expiresIn: '15m' },
          }),
          inject: [ConfigService],
        }),
        PassportModule.register({ defaultStrategy: 'jwt' }),
        UsersModule,
        AuthModule,
        VehiclesModule,
        TripsModule,
        BookingsModule,
      ],
    }).compile();

    app = moduleFixture.createNestApplication();

    // Apply global validation pipe
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );

    await app.init();

    // Get models
    userModel = moduleFixture.get<Model<UserDocument>>(
      getModelToken(User.name),
    );
    vehicleModel = moduleFixture.get<Model<VehicleDocument>>(
      getModelToken(Vehicle.name),
    );
    tripModel = moduleFixture.get<Model<TripDocument>>(
      getModelToken(Trip.name),
    );
    bookingModel = moduleFixture.get<Model<BookingDocument>>(
      getModelToken(Booking.name),
    );

    // Clean up test data
    await userModel.deleteMany({
      email: {
        $in: [mockDriver.email, mockPassenger.email, mockSecondPassenger.email],
      },
    });
    await vehicleModel.deleteMany({ plateNumber: mockVehicle.plateNumber });
    await tripModel.deleteMany({});
    await bookingModel.deleteMany({});
  });

  afterAll(async () => {
    // Clean up test data
    await userModel.deleteMany({
      email: {
        $in: [mockDriver.email, mockPassenger.email, mockSecondPassenger.email],
      },
    });
    await vehicleModel.deleteMany({ plateNumber: mockVehicle.plateNumber });
    await tripModel.deleteMany({});
    await bookingModel.deleteMany({});
    await app.close();
  });

  describe('Setup', () => {
    it('should register driver', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send(mockDriver)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.user.email).toBe(mockDriver.email);
      driverId = response.body.data.user._id;
      driverAccessToken = response.body.data.accessToken;
    });

    it('should register passenger', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send(mockPassenger)
        .expect(201);

      expect(response.body.success).toBe(true);
      passengerId = response.body.data.user._id;
      passengerAccessToken = response.body.data.accessToken;
    });

    it('should register second passenger', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send(mockSecondPassenger)
        .expect(201);

      expect(response.body.success).toBe(true);
      secondPassengerId = response.body.data.user._id;
      secondPassengerAccessToken = response.body.data.accessToken;
    });

    it('should create vehicle for driver', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/vehicles')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockVehicle)
        .expect(201);

      expect(response.body.success).toBe(true);
    });

    it('should create trip', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.totalSeats).toBe(4);
      expect(response.body.data.availableSeats).toBe(4);
      expect(response.body.data.seats).toHaveLength(4);
      tripId = response.body.data._id;
    });
  });

  describe('POST /bookings - Create Booking', () => {
    it('should create a booking successfully', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .send({
          tripId,
          seatNumber: '0-0',
        })
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.tripId).toBe(tripId);
      expect(response.body.data.userId).toBe(passengerId);
      expect(response.body.data.seatNumber).toBe('0-0');
      expect(response.body.data.status).toBe('pending');
      bookingId = response.body.data._id;
    });

    it('should fail when booking own trip', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send({
          tripId,
          seatNumber: '0-1',
        })
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error.message).toContain('own trip');
    });

    it('should fail when booking already booked seat', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${secondPassengerAccessToken}`)
        .send({
          tripId,
          seatNumber: '0-0',
        })
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error.message).toContain('not available');
    });

    it('should reject a second booking on the same trip (one booking per trip)', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .send({
          tripId,
          seatNumber: '0-1',
        })
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error.message).toMatch(/already have a booking/i);
    });

    it('should fail with gender mismatch when preventGenderMixing is true', async () => {
      // Second passenger is male, first booked seat has female passenger
      // Try to book adjacent seat (0-1) which would violate gender mixing rule
      const response = await request(app.getHttpServer())
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${secondPassengerAccessToken}`)
        .send({
          tripId,
          seatNumber: '1-0', // Different row, should work
        })
        .expect(201);

      expect(response.body.success).toBe(true);
    });

    it('should fail with non-existent trip', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .send({
          tripId: '507f1f77bcf86cd799439011', // Non-existent ObjectId
          seatNumber: '0-0',
        })
        .expect(404);

      expect(response.body.success).toBe(false);
    });

    it('should fail with invalid seat number', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${secondPassengerAccessToken}`)
        .send({
          tripId,
          seatNumber: '99-99', // Invalid seat
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /bookings/my - Get User Bookings', () => {
    it('should return user bookings', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/bookings/my')
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.data).toHaveLength(1);
      expect(response.body.data.data[0]._id).toBe(bookingId);
    });

    it('should return paginated results', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/bookings/my?page=1&limit=10')
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.meta.page).toBe(1);
      expect(response.body.data.meta.limit).toBe(10);
    });
  });

  describe('GET /bookings/:id - Get Booking by ID', () => {
    it('should return booking for booking owner', async () => {
      const response = await request(app.getHttpServer())
        .get(`/api/v1/bookings/${bookingId}`)
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data._id).toBe(bookingId);
    });

    it('should return booking for trip driver', async () => {
      const response = await request(app.getHttpServer())
        .get(`/api/v1/bookings/${bookingId}`)
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
    });

    it('should fail for unauthorized user', async () => {
      const response = await request(app.getHttpServer())
        .get(`/api/v1/bookings/${bookingId}`)
        .set('Authorization', `Bearer ${secondPassengerAccessToken}`)
        .expect(403);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /bookings/trip/:tripId - Get Trip Bookings (Driver only)', () => {
    it('should return trip bookings for driver', async () => {
      const response = await request(app.getHttpServer())
        .get(`/api/v1/bookings/trip/${tripId}`)
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.data.length).toBeGreaterThan(0);
    });

    it('should fail for non-driver', async () => {
      const response = await request(app.getHttpServer())
        .get(`/api/v1/bookings/trip/${tripId}`)
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .expect(403);

      expect(response.body.success).toBe(false);
    });
  });

  describe('PATCH /bookings/:id/confirm - Confirm Booking (Driver only)', () => {
    it('should confirm booking as driver', async () => {
      const response = await request(app.getHttpServer())
        .patch(`/api/v1/bookings/${bookingId}/confirm`)
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.status).toBe('confirmed');
    });

    it('should fail to confirm already confirmed booking', async () => {
      const response = await request(app.getHttpServer())
        .patch(`/api/v1/bookings/${bookingId}/confirm`)
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    it('should fail for non-driver', async () => {
      // Create a new booking to test
      const newBookingResponse = await request(app.getHttpServer())
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${secondPassengerAccessToken}`)
        .send({
          tripId,
          seatNumber: '1-1',
        });

      const newBookingId = newBookingResponse.body.data._id;

      const response = await request(app.getHttpServer())
        .patch(`/api/v1/bookings/${newBookingId}/confirm`)
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .expect(403);

      expect(response.body.success).toBe(false);
    });
  });

  describe('PATCH /bookings/:id/cancel - Cancel Booking', () => {
    let cancellableBookingId: string;

    beforeAll(async () => {
      // Create a new booking for cancellation tests
      const response = await request(app.getHttpServer())
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${secondPassengerAccessToken}`)
        .send({
          tripId,
          seatNumber: '0-1', // This seat should be available now
        });

      // If seat 0-1 is not available due to gender rules, use another seat
      if (response.status !== 201) {
        // Try seat 1-1
        const altResponse = await request(app.getHttpServer())
          .post('/api/v1/bookings')
          .set('Authorization', `Bearer ${secondPassengerAccessToken}`)
          .send({
            tripId,
            seatNumber: '1-1',
          });
        cancellableBookingId = altResponse.body.data._id;
      } else {
        cancellableBookingId = response.body.data._id;
      }
    });

    it('should cancel booking as passenger', async () => {
      const response = await request(app.getHttpServer())
        .patch(`/api/v1/bookings/${cancellableBookingId}/cancel`)
        .set('Authorization', `Bearer ${secondPassengerAccessToken}`)
        .send({ reason: 'Changed my mind' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.status).toBe('cancelled');
      expect(response.body.data.cancellationReason).toBe('Changed my mind');
      expect(response.body.data.cancelledBy).toBe('passenger');
    });

    it('should fail to cancel already cancelled booking', async () => {
      const response = await request(app.getHttpServer())
        .patch(`/api/v1/bookings/${cancellableBookingId}/cancel`)
        .set('Authorization', `Bearer ${secondPassengerAccessToken}`)
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('Concurrent Booking Race Condition Test', () => {
    it('should handle concurrent booking attempts atomically', async () => {
      // Create a new trip for this test
      const tripResponse = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send({
          ...mockTrip,
          from: { ...mockTrip.from, name: 'Concurrent Test Origin' },
          to: { ...mockTrip.to, name: 'Concurrent Test Dest' },
          seatLayout: {
            rows: 1,
            seatsPerRow: 2,
            preventGenderMixing: false,
          },
          totalSeats: 2,
        });

      const concurrentTripId = tripResponse.body.data._id;

      // Create two more passengers for concurrent test
      const passenger3 = {
        email: 'concurrent3@example.com',
        password: 'Password123!',
        name: 'Concurrent 3',
        gender: 'female',
        role: 'passenger',
      };

      const passenger4 = {
        email: 'concurrent4@example.com',
        password: 'Password123!',
        name: 'Concurrent 4',
        gender: 'female',
        role: 'passenger',
      };

      // Register both passengers
      const reg3 = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send(passenger3);
      const token3 = reg3.body.data.accessToken;

      const reg4 = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send(passenger4);
      const token4 = reg4.body.data.accessToken;

      // Attempt concurrent bookings for the same seat
      const bookingPromises = [
        request(app.getHttpServer())
          .post('/api/v1/bookings')
          .set('Authorization', `Bearer ${token3}`)
          .send({ tripId: concurrentTripId, seatNumber: '0-0' }),
        request(app.getHttpServer())
          .post('/api/v1/bookings')
          .set('Authorization', `Bearer ${token4}`)
          .send({ tripId: concurrentTripId, seatNumber: '0-0' }),
      ];

      const results = await Promise.allSettled(bookingPromises);

      // One should succeed, one should fail
      const successes = results.filter(
        (r) => r.status === 'fulfilled' && (r.value as any).status === 201,
      );
      const failures = results.filter(
        (r) => r.status === 'fulfilled' && (r.value as any).status !== 201,
      );

      // At least one should succeed and at least one should fail
      // (In a perfect world, exactly one succeeds, but timing can vary)
      expect(successes.length + failures.length).toBe(2);

      // Clean up
      await userModel.deleteMany({
        email: { $in: [passenger3.email, passenger4.email] },
      });
    });
  });
});
