import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import request from 'supertest';
import { UserEntity } from '../../src/database/entities/user.entity';
import { UsersModule } from '../../src/modules/users/users.module';
import { AuditModule } from '../../src/common/audit/audit.module';
import * as bcrypt from 'bcrypt';

describe('PATCH /users/me city field (Contract)', () => {
  let app: INestApplication;
  let userId: string;

  const testDbConfig = {
    type: 'postgres' as const,
    host: process.env.POSTGRES_HOST || 'localhost',
    port: parseInt(process.env.POSTGRES_PORT || '5432'),
    username: process.env.POSTGRES_USER || 'postgres',
    password: process.env.POSTGRES_PASSWORD || 'postgres',
    database: process.env.POSTGRES_TEST_DB || 'rideshare_test',
    entities: [UserEntity],
    synchronize: true,
    dropSchema: true,
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot(testDbConfig),
        TypeOrmModule.forFeature([UserEntity]),
        AuditModule,
        UsersModule,
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    await app.init();

    const userRepo = app.get('UserEntityRepository');
    const user = userRepo.create({
      email: 'city-test@example.com',
      name: 'City Test User',
      passwordHash: await bcrypt.hash('Password123', 12),
      role: 'passenger',
      isActive: true,
    });
    const saved = await userRepo.save(user);
    userId = saved.id;
  });

  afterAll(async () => {
    await app.close();
  });

  describe('1. PATCH /users/me with city → 200', () => {
    it('should update city and not expose fcmToken', async () => {
      const res = await request(app.getHttpServer())
        .patch('/users/me')
        .set('Authorization', `Bearer mock-token-${userId}`)
        .send({ city: 'Amman' });

      expect(res.status).toBe(200);
      expect(res.body.city).toBe('Amman');
      expect(res.body).not.toHaveProperty('fcmToken');
      expect(res.body).not.toHaveProperty('token');
    });
  });

  describe('2. PATCH /users/me with whitespace city → null', () => {
    it('should normalize whitespace-only city to null', async () => {
      const res = await request(app.getHttpServer())
        .patch('/users/me')
        .set('Authorization', `Bearer mock-token-${userId}`)
        .send({ city: '   ' });

      expect(res.status).toBe(200);
      expect(res.body.city).toBeNull();
    });
  });

  describe('3. PATCH /users/me with over-length city → 400', () => {
    it('should reject city longer than 64 chars', async () => {
      const res = await request(app.getHttpServer())
        .patch('/users/me')
        .set('Authorization', `Bearer mock-token-${userId}`)
        .send({ city: 'a'.repeat(65) });

      expect(res.status).toBe(400);
    });
  });

  describe('4. PATCH /users/me without auth → 401', () => {
    it('should reject unauthenticated requests', async () => {
      const res = await request(app.getHttpServer())
        .patch('/users/me')
        .send({ city: 'Irbid' });

      expect(res.status).toBe(401);
    });
  });

  describe('5. GET /users/me with city=null → includes null city', () => {
    it('should return city as null when not set', async () => {
      const userRepo = app.get('UserEntityRepository');
      await userRepo.update(userId, { city: null } as any);

      const res = await request(app.getHttpServer())
        .get('/users/me')
        .set('Authorization', `Bearer mock-token-${userId}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('city');
      expect(res.body.city).toBeNull();
    });
  });

  describe('6. GET /users/me response excludes fcmToken and token', () => {
    it('should never expose fcmToken or token fields', async () => {
      const res = await request(app.getHttpServer())
        .get('/users/me')
        .set('Authorization', `Bearer mock-token-${userId}`);

      expect(res.status).toBe(200);
      expect(res.body).not.toHaveProperty('fcmToken');
      expect(res.body).not.toHaveProperty('token');
    });
  });
});
