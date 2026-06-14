import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import request from 'supertest';
import { DeviceTokenEntity } from '../../src/database/entities/device-token.entity';
import { UserEntity } from '../../src/database/entities/user.entity';
import { NotificationsModule } from '../../src/modules/notifications/notifications.module';
import { UsersModule } from '../../src/modules/users/users.module';
import { AuditModule } from '../../src/common/audit/audit.module';
import * as bcrypt from 'bcrypt';

describe('POST /notifications/devices (Contract)', () => {
  let app: INestApplication;
  let userToken: string;
  let otherUserToken: string;
  let userId: string;
  let otherUserId: string;

  const testDbConfig = {
    type: 'postgres' as const,
    host: process.env.POSTGRES_HOST || 'localhost',
    port: parseInt(process.env.POSTGRES_PORT || '5432'),
    username: process.env.POSTGRES_USER || 'postgres',
    password: process.env.POSTGRES_PASSWORD || 'postgres',
    database: process.env.POSTGRES_TEST_DB || 'rideshare_test',
    entities: [UserEntity, DeviceTokenEntity],
    synchronize: true,
    dropSchema: true,
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot(testDbConfig),
        TypeOrmModule.forFeature([UserEntity, DeviceTokenEntity]),
        AuditModule,
        UsersModule,
        NotificationsModule,
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    await app.init();

    const userRepo = app.get('UserEntityRepository');
    const user = userRepo.create({
      email: 'device-test@example.com',
      name: 'Test User',
      passwordHash: await bcrypt.hash('Password123', 12),
      role: 'passenger',
      isActive: true,
    });
    const savedUser = await userRepo.save(user);
    userId = savedUser.id;

    const otherUser = userRepo.create({
      email: 'other-device@example.com',
      name: 'Other User',
      passwordHash: await bcrypt.hash('Password123', 12),
      role: 'passenger',
      isActive: true,
    });
    const savedOther = await userRepo.save(otherUser);
    otherUserId = savedOther.id;

    // Mock JWT tokens - in real tests you'd use the auth service
    // For contract tests we bypass auth or inject a mock guard
  });

  afterAll(async () => {
    await app.close();
  });

  describe('1. POST /notifications/devices — new token → 201', () => {
    it('should register a new device token', async () => {
      // This test will FAIL until the endpoint is implemented
      const res = await request(app.getHttpServer())
        .post('/notifications/devices')
        .set('Authorization', `Bearer mock-token-${userId}`)
        .send({
          token: 'newFCMToken123',
          platform: 'android',
          appVersion: '1.18.3',
        });

      expect([201, 200]).toContain(res.status);
      expect(res.body).not.toHaveProperty('token');
      expect(res.body.registered).toBe(true);
      expect(res.body).toHaveProperty('platform');
      expect(res.body).toHaveProperty('lastSeenAt');
    });
  });

  describe('2. POST /notifications/devices — refresh existing → 200', () => {
    it('should refresh an existing token for same user', async () => {
      const res = await request(app.getHttpServer())
        .post('/notifications/devices')
        .set('Authorization', `Bearer mock-token-${userId}`)
        .send({
          token: 'newFCMToken123',
          platform: 'android',
        });

      expect(res.status).toBe(200);
      expect(res.body).not.toHaveProperty('token');
    });
  });

  describe('3. POST /notifications/devices — handoff to new user', () => {
    it('should reassign token to new user when handed off', async () => {
      const res = await request(app.getHttpServer())
        .post('/notifications/devices')
        .set('Authorization', `Bearer mock-token-${otherUserId}`)
        .send({
          token: 'newFCMToken123',
          platform: 'ios',
        });

      expect([200, 201]).toContain(res.status);
    });
  });

  describe('4. POST /notifications/devices — no auth → 401', () => {
    it('should reject unauthenticated requests', async () => {
      const res = await request(app.getHttpServer())
        .post('/notifications/devices')
        .send({ token: 'abc', platform: 'android' });

      expect(res.status).toBe(401);
    });
  });

  describe('5. POST /notifications/devices — invalid platform → 400', () => {
    it('should reject invalid platform', async () => {
      const res = await request(app.getHttpServer())
        .post('/notifications/devices')
        .set('Authorization', `Bearer mock-token-${userId}`)
        .send({ token: 'validToken', platform: 'windows' });

      expect(res.status).toBe(400);
    });
  });

  describe('6. DELETE /notifications/devices/:token — own token → 204', () => {
    it('should deactivate own device token', async () => {
      const res = await request(app.getHttpServer())
        .delete('/notifications/devices/newFCMToken123')
        .set('Authorization', `Bearer mock-token-${otherUserId}`);

      expect(res.status).toBe(204);
    });
  });

  describe('7. DELETE /notifications/devices/:token — foreign token → 404', () => {
    it('should return 404 for another users token', async () => {
      // First register a token for otherUser
      await request(app.getHttpServer())
        .post('/notifications/devices')
        .set('Authorization', `Bearer mock-token-${otherUserId}`)
        .send({ token: 'otherUserToken', platform: 'android' });

      const res = await request(app.getHttpServer())
        .delete('/notifications/devices/otherUserToken')
        .set('Authorization', `Bearer mock-token-${userId}`);

      expect(res.status).toBe(404);
    });
  });

  describe('8. Rate limit — 31 requests in one minute → 429', () => {
    it('should rate limit after 30 requests', async () => {
      let lastStatus = 0;
      for (let i = 0; i < 31; i++) {
        const res = await request(app.getHttpServer())
          .post('/notifications/devices')
          .set('Authorization', `Bearer mock-token-${userId}`)
          .send({ token: `ratelimit-token-${i}`, platform: 'android' });
        lastStatus = res.status;
      }
      expect(lastStatus).toBe(429);
    });
  });
});
