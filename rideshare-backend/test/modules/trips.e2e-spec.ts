import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { MongooseModule } from '@nestjs/mongoose';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { getModelToken } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import * as bcrypt from 'bcrypt';

// Mock modules that will be created
import { VehiclesModule } from '../../src/modules/vehicles/vehicles.module';
import { TripsModule } from '../../src/modules/trips/trips.module';
import { AuthModule } from '../../src/modules/auth/auth.module';
import { UsersModule } from '../../src/modules/users/users.module';
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

describe('Trips E2E', () => {
  let app: INestApplication;
  let userModel: Model<UserDocument>;
  let vehicleModel: Model<VehicleDocument>;
  let tripModel: Model<TripDocument>;

  let driverAccessToken: string;
  let passengerAccessToken: string;
  let driverId: string;
  let passengerId: string;
  let vehicleId: string;
  let tripId: string;

  const mockDriver = {
    email: 'driver@example.com',
    password: 'Password123!',
    name: 'Driver User',
    gender: 'male',
    role: 'driver',
  };

  const mockPassenger = {
    email: 'passenger@example.com',
    password: 'Password123!',
    name: 'Passenger User',
    gender: 'female',
    role: 'passenger',
  };

  const mockVehicle = {
    vehicleType: 'sedan',
    plateNumber: 'ABC123',
    model: 'Toyota Camry',
    seats: 4,
  };

  const mockTrip = {
    from: {
      name: 'Cairo',
      latitude: 30.0444,
      longitude: 31.2357,
      address: 'Cairo, Egypt',
    },
    to: {
      name: 'Alexandria',
      latitude: 31.2001,
      longitude: 29.9187,
      address: 'Alexandria, Egypt',
    },
    departureTime: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    price: 100,
    currency: 'EGP',
    totalSeats: 4,
    seatLayout: {
      rows: 2,
      seatsPerRow: 2,
      preventGenderMixing: false,
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
        PassportModule,
        AuthModule,
        UsersModule,
        VehiclesModule,
        TripsModule,
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }),
    );
    await app.init();

    userModel = app.get<Model<UserDocument>>(getModelToken(User.name));
    vehicleModel = app.get<Model<VehicleDocument>>(getModelToken(Vehicle.name));
    tripModel = app.get<Model<TripDocument>>(getModelToken(Trip.name));
  });

  beforeEach(async () => {
    // Clean up database
    await tripModel.deleteMany({});
    await vehicleModel.deleteMany({});
    await userModel.deleteMany({});

    // Create driver user
    const hashedPassword = await bcrypt.hash(mockDriver.password, 12);
    const driver = await userModel.create({
      ...mockDriver,
      passwordHash: hashedPassword,
      isPhoneVerified: true,
      isEmailVerified: true,
    });
    driverId = driver._id.toString();

    // Create passenger user
    const hashedPassengerPassword = await bcrypt.hash(
      mockPassenger.password,
      12,
    );
    const passenger = await userModel.create({
      ...mockPassenger,
      passwordHash: hashedPassengerPassword,
      isPhoneVerified: true,
      isEmailVerified: true,
    });
    passengerId = passenger._id.toString();

    // Login as driver
    const driverLoginResponse = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({
        email: mockDriver.email,
        password: mockDriver.password,
      });
    driverAccessToken = driverLoginResponse.body.data.accessToken;

    // Login as passenger
    const passengerLoginResponse = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({
        email: mockPassenger.email,
        password: mockPassenger.password,
      });
    passengerAccessToken = passengerLoginResponse.body.data.accessToken;

    // Create vehicle for driver
    const vehicleResponse = await request(app.getHttpServer())
      .post('/api/v1/vehicles')
      .set('Authorization', `Bearer ${driverAccessToken}`)
      .send(mockVehicle);
    vehicleId = vehicleResponse.body.data._id;
  });

  afterAll(async () => {
    await tripModel.deleteMany({});
    await vehicleModel.deleteMany({});
    await userModel.deleteMany({});
    await app.close();
  });

  describe('POST /api/v1/trips - Create trip', () => {
    it('should create a trip successfully', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('_id');
      expect(response.body.data.driverId).toBe(driverId);
      expect(response.body.data.from.name).toBe(mockTrip.from.name);
      expect(response.body.data.to.name).toBe(mockTrip.to.name);
      expect(response.body.data.price).toBe(mockTrip.price);
      expect(response.body.data.totalSeats).toBe(mockTrip.totalSeats);
      expect(response.body.data.availableSeats).toBe(mockTrip.totalSeats);
      expect(response.body.data.status).toBe('active');
      expect(response.body.data.seats).toHaveLength(4);
      expect(response.body.data.seats[0].status).toBe('available');

      tripId = response.body.data._id;
    });

    it('should fail with past departure time', async () => {
      const pastTrip = {
        ...mockTrip,
        departureTime: new Date(Date.now() - 1000).toISOString(),
      };

      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(pastTrip);

      expect(response.status).toBe(400);
    });

    it('should fail for non-driver role', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .send(mockTrip);

      expect(response.status).toBe(403);
    });

    it('should fail without authentication', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .send(mockTrip);

      expect(response.status).toBe(401);
    });
  });

  describe('GET /api/v1/trips/:id - Get trip by ID', () => {
    beforeEach(async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);
      tripId = response.body.data._id;
    });

    it('should get trip by ID', async () => {
      const response = await request(app.getHttpServer())
        .get(`/api/v1/trips/${tripId}`)
        .set('Authorization', `Bearer ${passengerAccessToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data._id).toBe(tripId);
      expect(response.body.data.seats).toBeDefined();
    });

    it('should return 404 for non-existent trip', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/trips/507f1f77bcf86cd799439011')
        .set('Authorization', `Bearer ${passengerAccessToken}`);

      expect(response.status).toBe(404);
    });
  });

  describe('PATCH /api/v1/trips/:id - Update trip', () => {
    beforeEach(async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);
      tripId = response.body.data._id;
    });

    it('should update trip successfully', async () => {
      const updateData = {
        price: 150,
        departureTime: new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString(),
      };

      const response = await request(app.getHttpServer())
        .patch(`/api/v1/trips/${tripId}`)
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(updateData);

      expect(response.status).toBe(200);
      expect(response.body.data.price).toBe(150);
    });

    it('should fail for non-owner', async () => {
      const response = await request(app.getHttpServer())
        .patch(`/api/v1/trips/${tripId}`)
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .send({ price: 150 });

      expect(response.status).toBe(403);
    });
  });

  describe('PATCH /api/v1/trips/:id/complete - Complete trip', () => {
    beforeEach(async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);
      tripId = response.body.data._id;
    });

    it('should complete trip successfully', async () => {
      const response = await request(app.getHttpServer())
        .patch(`/api/v1/trips/${tripId}/complete`)
        .set('Authorization', `Bearer ${driverAccessToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.status).toBe('completed');
    });
  });

  describe('GET /api/v1/trips/:id/seats - Get trip seats', () => {
    beforeEach(async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);
      tripId = response.body.data._id;
    });

    it('should get trip seats', async () => {
      const response = await request(app.getHttpServer())
        .get(`/api/v1/trips/${tripId}/seats`)
        .set('Authorization', `Bearer ${passengerAccessToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('seatLayout');
      expect(response.body.data).toHaveProperty('seats');
      expect(response.body.data.seats).toHaveLength(4);
    });
  });

  describe('GET /api/v1/trips/my - Get driver trips', () => {
    beforeEach(async () => {
      await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);
    });

    it('should get driver trips', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/trips/my')
        .set('Authorization', `Bearer ${driverAccessToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveLength(1);
      expect(response.body.data[0].driverId).toBe(driverId);
    });
  });

  describe('PATCH /api/v1/trips/:id/hide - Hide trip', () => {
    beforeEach(async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);
      tripId = response.body.data._id;
    });

    it('should hide trip successfully', async () => {
      const response = await request(app.getHttpServer())
        .patch(`/api/v1/trips/${tripId}/hide`)
        .set('Authorization', `Bearer ${driverAccessToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.isVisible).toBe(false);
      expect(response.body.data.status).toBe('hidden');
    });
  });

  describe('PATCH /api/v1/trips/:id/show - Show trip', () => {
    beforeEach(async () => {
      const createResponse = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);
      tripId = createResponse.body.data._id;

      await request(app.getHttpServer())
        .patch(`/api/v1/trips/${tripId}/hide`)
        .set('Authorization', `Bearer ${driverAccessToken}`);
    });

    it('should show trip successfully', async () => {
      const response = await request(app.getHttpServer())
        .patch(`/api/v1/trips/${tripId}/show`)
        .set('Authorization', `Bearer ${driverAccessToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.isVisible).toBe(true);
      expect(response.body.data.status).toBe('active');
    });
  });

  describe('DELETE /api/v1/trips/:id - Cancel trip', () => {
    beforeEach(async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);
      tripId = response.body.data._id;
    });

    it('should cancel trip successfully', async () => {
      const response = await request(app.getHttpServer())
        .delete(`/api/v1/trips/${tripId}`)
        .set('Authorization', `Bearer ${driverAccessToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.status).toBe('cancelled');
    });
  });

  describe('GET /api/v1/trips - Search trips', () => {
    beforeEach(async () => {
      await request(app.getHttpServer())
        .post('/api/v1/trips')
        .set('Authorization', `Bearer ${driverAccessToken}`)
        .send(mockTrip);
    });

    it('should search trips with filters', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/trips')
        .set('Authorization', `Bearer ${passengerAccessToken}`)
        .query({
          fromLatitude: 30.0444,
          fromLongitude: 31.2357,
          minPrice: 50,
          maxPrice: 150,
        });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toBeInstanceOf(Array);
      expect(response.body.meta).toHaveProperty('total');
      expect(response.body.meta).toHaveProperty('totalPages');
    });
  });
});
