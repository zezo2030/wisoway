# Rideshare Backend - NestJS + PostgreSQL Implementation Plan

## Context
The rideshare Flutter app currently depends entirely on Firebase (Auth, Firestore, Storage, FCM, Cloud Functions). The goal is to build a fully independent, production-ready backend using **NestJS + PostgreSQL** that replaces Firebase completely, adds professional features, and deploys to a VPS.

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Framework | NestJS 10.x (TypeScript) |
| Database | PostgreSQL 16 + TypeORM |
| Auth | JWT (access + refresh tokens) + Passport.js |
| OTP | Twilio SMS API |
| OAuth | Google OAuth2, Facebook OAuth |
| Real-time | WebSocket (Socket.IO via @nestjs/websockets) |
| Push Notifications | Firebase Admin SDK (FCM) server-side OR OneSignal |
| File Storage | AWS S3 (or MinIO self-hosted) + Multer |
| Email | Nodemailer + Gmail/SendGrid |
| Cache | Redis (sessions, rate limiting, real-time) |
| Queue | Bull (background jobs) |
| Docs | Swagger/OpenAPI |
| Logging | Winston + Morgan |
| Validation | class-validator + class-transformer |
| Testing | Jest + Supertest |
| Deployment | Docker + Nginx + PM2 |

---

## Project Structure

```
rideshare-backend/
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   ├── config/
│   │   ├── database.config.ts
│   │   ├── jwt.config.ts
│   │   ├── s3.config.ts
│   │   ├── redis.config.ts
│   │   ├── twilio.config.ts
│   │   └── app.config.ts
│   │
│   ├── common/
│   │   ├── decorators/
│   │   │   ├── current-user.decorator.ts
│   │   │   ├── roles.decorator.ts
│   │   │   └── public.decorator.ts
│   │   ├── guards/
│   │   │   ├── jwt-auth.guard.ts
│   │   │   ├── roles.guard.ts
│   │   │   └── ws-auth.guard.ts
│   │   ├── interceptors/
│   │   │   ├── transform.interceptor.ts
│   │   │   └── logging.interceptor.ts
│   │   ├── filters/
│   │   │   └── http-exception.filter.ts
│   │   ├── pipes/
│   │   │   └── validation.pipe.ts
│   │   ├── dto/
│   │   │   └── pagination.dto.ts
│   │   └── interfaces/
│   │       └── paginated-result.interface.ts
│   │
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── auth.module.ts
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   ├── strategies/
│   │   │   │   ├── jwt.strategy.ts
│   │   │   │   ├── jwt-refresh.strategy.ts
│   │   │   │   ├── google.strategy.ts
│   │   │   │   └── facebook.strategy.ts
│   │   │   ├── dto/
│   │   │   │   ├── sign-up.dto.ts
│   │   │   │   ├── sign-in.dto.ts
│   │   │   │   ├── send-otp.dto.ts
│   │   │   │   ├── verify-otp.dto.ts
│   │   │   │   ├── social-login.dto.ts
│   │   │   │   └── refresh-token.dto.ts
│   │   │   └── guards/
│   │   │       ├── google-auth.guard.ts
│   │   │       └── facebook-auth.guard.ts
│   │   │
│   │   ├── users/
│   │   │   ├── users.module.ts
│   │   │   ├── users.controller.ts
│   │   │   ├── users.service.ts
│   │   │   ├── entities/
│   │   │   │   └── user.entity.ts
│   │   │   └── dto/
│   │   │       ├── create-user.dto.ts
│   │   │       ├── update-user.dto.ts
│   │   │       └── update-profile.dto.ts
│   │   │
│   │   ├── vehicles/
│   │   │   ├── vehicles.module.ts
│   │   │   ├── vehicles.controller.ts
│   │   │   ├── vehicles.service.ts
│   │   │   ├── entities/
│   │   │   │   └── vehicle.entity.ts
│   │   │   └── dto/
│   │   │       ├── create-vehicle.dto.ts
│   │   │       └── update-vehicle.dto.ts
│   │   │
│   │   ├── trips/
│   │   │   ├── trips.module.ts
│   │   │   ├── trips.controller.ts
│   │   │   ├── trips.service.ts
│   │   │   ├── entities/
│   │   │   │   ├── trip.entity.ts
│   │   │   │   └── seat.entity.ts
│   │   │   ├── dto/
│   │   │   │   ├── create-trip.dto.ts
│   │   │   │   ├── update-trip.dto.ts
│   │   │   │   └── search-trips.dto.ts
│   │   │   └── trips.gateway.ts
│   │   │
│   │   ├── bookings/
│   │   │   ├── bookings.module.ts
│   │   │   ├── bookings.controller.ts
│   │   │   ├── bookings.service.ts
│   │   │   ├── entities/
│   │   │   │   └── booking.entity.ts
│   │   │   └── dto/
│   │   │       ├── create-booking.dto.ts
│   │   │       └── cancel-booking.dto.ts
│   │   │
│   │   ├── payments/
│   │   │   ├── payments.module.ts
│   │   │   ├── payments.controller.ts
│   │   │   ├── payments.service.ts
│   │   │   ├── stripe.service.ts
│   │   │   ├── entities/
│   │   │   │   └── payment.entity.ts
│   │   │   └── dto/
│   │   │       ├── create-payment.dto.ts
│   │   │       └── update-payment-status.dto.ts
│   │   │
│   │   ├── chat/
│   │   │   ├── chat.module.ts
│   │   │   ├── chat.controller.ts
│   │   │   ├── chat.service.ts
│   │   │   ├── chat.gateway.ts
│   │   │   ├── entities/
│   │   │   │   ├── chat-room.entity.ts
│   │   │   │   └── message.entity.ts
│   │   │   └── dto/
│   │   │       ├── send-message.dto.ts
│   │   │       └── create-chat-room.dto.ts
│   │   │
│   │   ├── ratings/
│   │   │   ├── ratings.module.ts
│   │   │   ├── ratings.controller.ts
│   │   │   ├── ratings.service.ts
│   │   │   ├── entities/
│   │   │   │   └── rating.entity.ts
│   │   │   └── dto/
│   │   │       └── create-rating.dto.ts
│   │   │
│   │   ├── notifications/
│   │   │   ├── notifications.module.ts
│   │   │   ├── notifications.controller.ts
│   │   │   ├── notifications.service.ts
│   │   │   ├── notifications.gateway.ts
│   │   │   ├── entities/
│   │   │   │   └── notification.entity.ts
│   │   │   └── dto/
│   │   │       └── create-notification.dto.ts
│   │   │
│   │   ├── uploads/
│   │   │   ├── uploads.module.ts
│   │   │   ├── uploads.controller.ts
│   │   │   └── uploads.service.ts
│   │   │
│   │   ├── locations/
│   │   │   ├── locations.module.ts
│   │   │   ├── locations.controller.ts
│   │   │   └── locations.service.ts
│   │   │
│   │   ├── admin/
│   │   │   ├── admin.module.ts
│   │   │   ├── admin.controller.ts
│   │   │   ├── admin.service.ts
│   │   │   └── dto/
│   │   │       └── admin-query.dto.ts
│   │   │
│   │   └── health/
│   │       ├── health.module.ts
│   │       └── health.controller.ts
│   │
│   └── jobs/
│       ├── jobs.module.ts
│       ├── trip-expiration.job.ts
│       └── notification-cleanup.job.ts
│
├── test/
│   ├── app.e2e-spec.ts
│   └── modules/
│       ├── auth.e2e-spec.ts
│       ├── trips.e2e-spec.ts
│       └── bookings.e2e-spec.ts
│
├── database/
│   ├── migrations/
│   ├── seeds/
│   │   ├── admin.seed.ts
│   │   └── countries.seed.ts
│   └── data-source.ts
│
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   └── nginx/
│       └── nginx.conf
│
├── .env.example
├── .env
├── package.json
├── tsconfig.json
├── nest-cli.json
└── README.md
```

---

## Database Schema (PostgreSQL + TypeORM)

### Table: `users`
```sql
id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
email           VARCHAR(255) UNIQUE
password_hash   VARCHAR(255)                    -- nullable for social login
phone_number    VARCHAR(20) UNIQUE
name            VARCHAR(100) NOT NULL
gender          VARCHAR(10) CHECK (gender IN ('male', 'female'))
role            VARCHAR(20) DEFAULT 'passenger' CHECK (role IN ('passenger', 'driver', 'admin'))
photo_url       VARCHAR(500)
provider        VARCHAR(20) DEFAULT 'email'     -- email, google, facebook, phone
provider_id     VARCHAR(255)                    -- social login provider ID
rating          DECIMAL(3,2) DEFAULT 0
total_ratings   INTEGER DEFAULT 0
is_phone_verified  BOOLEAN DEFAULT false
is_email_verified  BOOLEAN DEFAULT false
is_active       BOOLEAN DEFAULT true
fcm_token       VARCHAR(500)
refresh_token   VARCHAR(500)
created_at      TIMESTAMP DEFAULT NOW()
updated_at      TIMESTAMP DEFAULT NOW()

INDEXES: idx_users_email, idx_users_phone, idx_users_role
```

### Table: `otp_codes`
```sql
id              UUID PRIMARY KEY
phone_number    VARCHAR(20) NOT NULL
code            VARCHAR(6) NOT NULL
expires_at      TIMESTAMP NOT NULL
is_used         BOOLEAN DEFAULT false
created_at      TIMESTAMP DEFAULT NOW()

INDEX: idx_otp_phone_code
```

### Table: `vehicles`
```sql
id                      UUID PRIMARY KEY
driver_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
vehicle_type            VARCHAR(20) NOT NULL
plate_number            VARCHAR(20) NOT NULL
model                   VARCHAR(100) NOT NULL
seats                   INTEGER NOT NULL
license_image_url       VARCHAR(500)
vehicle_license_image_url VARCHAR(500)
is_verified             BOOLEAN DEFAULT false
created_at              TIMESTAMP DEFAULT NOW()
updated_at              TIMESTAMP DEFAULT NOW()

UNIQUE: uniq_vehicle_driver (driver_id)
INDEX: idx_vehicles_driver
```

### Table: `trips`
```sql
id                      UUID PRIMARY KEY
driver_id               UUID NOT NULL REFERENCES users(id)
driver_name             VARCHAR(100)
from_name               VARCHAR(255)
from_latitude           DECIMAL(10,7)
from_longitude          DECIMAL(10,7)
from_address            VARCHAR(500)
to_name                 VARCHAR(255)
to_latitude             DECIMAL(10,7)
to_longitude            DECIMAL(10,7)
to_address              VARCHAR(500)
departure_time          TIMESTAMP NOT NULL
price                   DECIMAL(10,2) NOT NULL
currency                VARCHAR(5) DEFAULT 'EGP'
total_seats             INTEGER NOT NULL
available_seats         INTEGER NOT NULL
seat_layout             JSONB NOT NULL           -- {rows, seatsPerRow, preventGenderMixing}
status                  VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','hidden','completed','cancelled','expired'))
communication_fee_status VARCHAR(20) DEFAULT 'not_paid'
car_image_url           VARCHAR(500)
is_visible              BOOLEAN DEFAULT true
created_at              TIMESTAMP DEFAULT NOW()
updated_at              TIMESTAMP DEFAULT NOW()

INDEXES: idx_trips_driver, idx_trips_status, idx_trips_departure, idx_trips_status_visible_seats
```

### Table: `seats`
```sql
id              UUID PRIMARY KEY
trip_id         UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE
seat_number     VARCHAR(10) NOT NULL            -- "0-0", "0-1", "1-0", etc.
user_id         UUID REFERENCES users(id)
user_name       VARCHAR(100)
gender          VARCHAR(10)
booked_at       TIMESTAMP
status          VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available','booked','locked'))

UNIQUE: uniq_seat_trip_number (trip_id, seat_number)
INDEX: idx_seats_trip, idx_seats_user
```

### Table: `bookings`
```sql
id                          UUID PRIMARY KEY
trip_id                     UUID NOT NULL REFERENCES trips(id)
user_id                     UUID NOT NULL REFERENCES users(id)
seat_number                 VARCHAR(10) NOT NULL
status                      VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','confirmed','cancelled','completed'))
has_driver_paid_to_contact  BOOLEAN DEFAULT false
share_phone_with_driver     BOOLEAN DEFAULT false
cancellation_reason         TEXT
cancelled_at                TIMESTAMP
cancelled_by                VARCHAR(20)           -- 'passenger', 'driver', 'system'
created_at                  TIMESTAMP DEFAULT NOW()
updated_at                  TIMESTAMP DEFAULT NOW()

UNIQUE: uniq_booking_user_trip (user_id, trip_id)
INDEXES: idx_bookings_trip, idx_bookings_user, idx_bookings_status
```

### Table: `payments`
```sql
id                  UUID PRIMARY KEY
trip_id             UUID REFERENCES trips(id)
booking_id          UUID REFERENCES bookings(id)
user_id             UUID NOT NULL REFERENCES users(id)
amount              DECIMAL(10,2) NOT NULL
currency            VARCHAR(5) DEFAULT 'EGP'
method              VARCHAR(20) NOT NULL CHECK (method IN ('stripe','paymob','manual','communication_fee'))
status              VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','refunded'))
payment_type        VARCHAR(30) DEFAULT 'trip'   -- 'trip', 'communication_fee'
-- Manual payment fields
proof_image_url     VARCHAR(500)
wallet_number       VARCHAR(20)
-- Online payment fields
transaction_id      VARCHAR(255)
payment_gateway_ref VARCHAR(255)
admin_note          TEXT
created_at          TIMESTAMP DEFAULT NOW()
updated_at          TIMESTAMP DEFAULT NOW()

INDEXES: idx_payments_user, idx_payments_trip, idx_payments_booking, idx_payments_status
```

### Table: `chat_rooms`
```sql
id                  UUID PRIMARY KEY
trip_id             UUID NOT NULL REFERENCES trips(id)
last_message        TEXT
last_message_time   TIMESTAMP
last_message_sender_id UUID
created_at          TIMESTAMP DEFAULT NOW()

INDEX: idx_chat_rooms_trip
```

### Table: `chat_participants`
```sql
id              UUID PRIMARY KEY
chat_room_id    UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE
user_id         UUID NOT NULL REFERENCES users(id)
joined_at       TIMESTAMP DEFAULT NOW()

UNIQUE: uniq_participant (chat_room_id, user_id)
```

### Table: `messages`
```sql
id              UUID PRIMARY KEY
chat_room_id    UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE
sender_id       UUID NOT NULL REFERENCES users(id)
sender_name     VARCHAR(100)
text            TEXT NOT NULL
created_at      TIMESTAMP DEFAULT NOW()

INDEX: idx_messages_chat_room, idx_messages_created
```

### Table: `ratings`
```sql
id              UUID PRIMARY KEY
from_user_id    UUID NOT NULL REFERENCES users(id)
to_user_id      UUID NOT NULL REFERENCES users(id)
trip_id         UUID NOT NULL REFERENCES trips(id)
rating          INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5)
comment         TEXT
user_role       VARCHAR(20)     -- role of the rater
rated_role      VARCHAR(20)     -- role of the rated user
created_at      TIMESTAMP DEFAULT NOW()

UNIQUE: uniq_rating_per_trip (from_user_id, trip_id)
INDEXES: idx_ratings_to_user, idx_ratings_trip
```

### Table: `notifications`
```sql
id              UUID PRIMARY KEY
user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
type            VARCHAR(50) NOT NULL
title           VARCHAR(255) NOT NULL
body            TEXT
data            JSONB
is_read         BOOLEAN DEFAULT false
created_at      TIMESTAMP DEFAULT NOW()

INDEXES: idx_notifications_user, idx_notifications_user_read
```

### Table: `communication_fees`
```sql
id              UUID PRIMARY KEY
country_code    VARCHAR(5) NOT NULL UNIQUE
fee_amount      DECIMAL(10,2) NOT NULL
currency        VARCHAR(5) NOT NULL
is_active       BOOLEAN DEFAULT true

-- Seed data: EG=50EGP, JO=2JOD, SA=10SAR, AE=25AED, QA=25QAR
```

---

## API Endpoints

### Auth Module (`/api/v1/auth`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/register` | Email/password registration | Public |
| POST | `/login` | Email/password login | Public |
| POST | `/send-otp` | Send OTP to phone | Public |
| POST | `/verify-otp` | Verify OTP code | Public |
| POST | `/google` | Google OAuth login | Public |
| POST | `/facebook` | Facebook OAuth login | Public |
| POST | `/refresh` | Refresh access token | Refresh Token |
| POST | `/logout` | Invalidate refresh token | JWT |
| POST | `/forgot-password` | Send password reset email | Public |
| POST | `/reset-password` | Reset password with token | Public |
| PATCH | `/link-phone` | Link phone to account | JWT |
| DELETE | `/delete-account` | Delete user account | JWT |

### Users Module (`/api/v1/users`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/me` | Get current user profile | JWT |
| PATCH | `/me` | Update profile | JWT |
| PATCH | `/me/role` | Update role (passenger/driver) | JWT |
| PATCH | `/me/fcm-token` | Update FCM token | JWT |
| GET | `/:id` | Get user public profile | JWT |
| GET | `/:id/stats` | Get user statistics | JWT |

### Vehicles Module (`/api/v1/vehicles`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/` | Add vehicle (driver) | JWT + Driver |
| GET | `/my` | Get driver's vehicle | JWT + Driver |
| PATCH | `/:id` | Update vehicle | JWT + Driver |
| DELETE | `/:id` | Delete vehicle | JWT + Driver |

### Trips Module (`/api/v1/trips`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/` | Create trip | JWT + Driver |
| GET | `/` | Search trips (with filters) | JWT |
| GET | `/my` | Get driver's trips | JWT + Driver |
| GET | `/:id` | Get trip details | JWT |
| PATCH | `/:id` | Update trip | JWT + Driver |
| PATCH | `/:id/hide` | Hide trip | JWT + Driver |
| PATCH | `/:id/show` | Show trip | JWT + Driver |
| PATCH | `/:id/complete` | Complete trip | JWT + Driver |
| DELETE | `/:id` | Delete trip | JWT + Driver |
| GET | `/:id/seats` | Get seat layout | JWT |

### Bookings Module (`/api/v1/bookings`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/` | Create booking | JWT + Passenger |
| GET | `/my` | Get user's bookings | JWT |
| GET | `/trip/:tripId` | Get trip bookings | JWT + Driver |
| GET | `/:id` | Get booking details | JWT |
| PATCH | `/:id/confirm` | Confirm booking | JWT + Driver |
| PATCH | `/:id/cancel` | Cancel booking | JWT |

### Payments Module (`/api/v1/payments`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/` | Create payment | JWT |
| POST | `/communication-fee` | Pay communication fee | JWT + Driver |
| GET | `/my` | Get payment history | JWT |
| GET | `/:id` | Get payment details | JWT |
| PATCH | `/:id/approve` | Approve payment | JWT + Admin |
| PATCH | `/:id/reject` | Reject payment | JWT + Admin |
| POST | `/stripe/create-intent` | Stripe payment intent | JWT |
| POST | `/stripe/webhook` | Stripe webhook | Public (verified) |

### Chat Module (`/api/v1/chat`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/rooms` | Get user's chat rooms | JWT |
| GET | `/rooms/:tripId` | Get/create chat room | JWT |
| GET | `/rooms/:id/messages` | Get messages (paginated) | JWT |
| POST | `/rooms/:id/messages` | Send message (REST fallback) | JWT |

**WebSocket Gateway** (`ws://host/chat`):
- `joinRoom` - Join a chat room
- `leaveRoom` - Leave a chat room
- `sendMessage` - Send real-time message
- `typing` - Typing indicator
- `newMessage` - Receive new messages

### Ratings Module (`/api/v1/ratings`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/` | Create rating | JWT |
| GET | `/user/:userId` | Get user's ratings | JWT |
| GET | `/trip/:tripId` | Get trip ratings | JWT |
| GET | `/my` | Get ratings I gave | JWT |

### Notifications Module (`/api/v1/notifications`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/` | Get notifications (paginated) | JWT |
| GET | `/unread-count` | Get unread count | JWT |
| PATCH | `/:id/read` | Mark as read | JWT |
| PATCH | `/read-all` | Mark all as read | JWT |
| DELETE | `/:id` | Delete notification | JWT |

**WebSocket Gateway** (`ws://host/notifications`):
- `subscribe` - Subscribe to notifications
- `newNotification` - Receive real-time notification

### Uploads Module (`/api/v1/uploads`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/profile-image` | Upload profile picture | JWT |
| POST | `/license` | Upload driver license | JWT + Driver |
| POST | `/vehicle-license` | Upload vehicle license | JWT + Driver |
| POST | `/car-image` | Upload car image | JWT + Driver |
| POST | `/payment-proof` | Upload payment proof | JWT |
| DELETE | `/:key` | Delete uploaded file | JWT |

### Locations Module (`/api/v1/locations`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/geocode` | Address to coordinates | JWT |
| GET | `/reverse-geocode` | Coordinates to address | JWT |
| GET | `/distance` | Calculate distance | JWT |

### Admin Module (`/api/v1/admin`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/dashboard/stats` | Overall statistics | JWT + Admin |
| GET | `/users` | List all users (paginated) | JWT + Admin |
| PATCH | `/users/:id/role` | Change user role | JWT + Admin |
| PATCH | `/users/:id/ban` | Ban/unban user | JWT + Admin |
| GET | `/trips` | List all trips | JWT + Admin |
| GET | `/payments/pending` | Pending payments | JWT + Admin |
| GET | `/payments` | All payments | JWT + Admin |
| PATCH | `/vehicles/:id/verify` | Verify vehicle | JWT + Admin |
| GET | `/reports` | Generate reports | JWT + Admin |

### Health Module (`/api/v1/health`)
| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/` | Health check | Public |
| GET | `/db` | Database health | Public |

---

## Key Implementation Details

### JWT Authentication Flow
```
1. User registers/logs in -> receives {accessToken (15min), refreshToken (7days)}
2. accessToken used in Authorization: Bearer header for all requests
3. On 401 -> client calls /auth/refresh with refreshToken
4. refreshToken stored hashed in DB (users.refresh_token)
5. Logout -> nullify refresh_token in DB
```

### Phone OTP Flow
```
1. POST /auth/send-otp {phoneNumber} -> Twilio sends SMS, OTP stored in otp_codes table (5min expiry)
2. POST /auth/verify-otp {phoneNumber, code} -> Verify & return JWT tokens
3. If user exists -> login, if new -> create user with role selection needed
```

### Seat Booking Flow (Transactional)
```
1. Passenger selects seat -> POST /bookings {tripId, seatNumber}
2. Backend wraps in PostgreSQL TRANSACTION:
   a. Check seat is available (SELECT FOR UPDATE)
   b. Check gender compatibility if preventGenderMixing enabled
   c. Create booking (status: pending)
   d. Update seat (status: booked, user info)
   e. Decrement trip.available_seats
3. Notify driver via WebSocket + push notification
```

### Communication Fee System
```
1. Driver wants to contact passenger -> POST /payments/communication-fee
2. Payment created (type: communication_fee)
3. After payment approved -> booking.has_driver_paid_to_contact = true
4. Chat access enabled between driver and passenger
```

### Real-time Architecture
```
WebSocket Namespaces:
  /chat           -> Real-time messaging (per chat room)
  /trips          -> Live trip updates (seat changes, status)
  /notifications  -> Push notifications delivery

All WebSocket connections authenticated via JWT in handshake
Redis used as Socket.IO adapter for horizontal scaling
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
**Goal**: Project setup, database, auth working end-to-end

- [ ] Initialize NestJS project with TypeScript
- [ ] Configure TypeORM + PostgreSQL connection
- [ ] Set up environment configuration (@nestjs/config)
- [ ] Create all database entities and migrations
- [ ] Implement Auth module (email/password + JWT)
- [ ] Implement Phone OTP with Twilio
- [ ] Implement Google & Facebook OAuth
- [ ] Set up role-based access control (guards, decorators)
- [ ] Global validation pipe, exception filters, response interceptor
- [ ] Swagger documentation setup
- [ ] Docker + docker-compose (app + postgres + redis)

**Deliverable**: Auth system fully functional, database schema deployed

---

### Phase 2: Core Business Logic (Week 3-4)
**Goal**: Trips, bookings, seats, vehicles

- [ ] Users module (profile CRUD, stats)
- [ ] Vehicles module (CRUD for drivers)
- [ ] Trips module (CRUD with seat layout)
- [ ] Seats management (dynamic layout, gender-aware booking)
- [ ] Bookings module (create, confirm, cancel with transactions)
- [ ] Locations module (Google Maps geocoding integration)
- [ ] File uploads module (S3 integration with Multer)
- [ ] Search & filter trips (by location, time, price, status)
- [ ] Pagination for all list endpoints

**Deliverable**: Core ride-sharing flow working (create trip -> search -> book seat)

---

### Phase 3: Payments & Communication (Week 5-6)
**Goal**: Payment processing, chat, ratings

- [ ] Payments module (manual + Stripe integration)
- [ ] Communication fee system
- [ ] Chat module with WebSocket gateway (Socket.IO)
- [ ] Real-time messaging (join room, send, receive)
- [ ] Ratings module (create, average calculation)
- [ ] Update user rating on new review

**Deliverable**: Full booking flow with payment, chat, and ratings

---

### Phase 4: Notifications & Background Jobs (Week 7)
**Goal**: Push notifications, real-time updates, scheduled tasks

- [ ] Notifications module + WebSocket gateway
- [ ] FCM push notification integration (server-side Firebase Admin SDK)
- [ ] Notification events (booking, payment, trip status changes)
- [ ] Bull queue for async notification sending
- [ ] Cron job: expire past trips automatically
- [ ] Cron job: cleanup old notifications (30+ days)
- [ ] Trip updates WebSocket gateway

**Deliverable**: Full notification system + background processing

---

### Phase 5: Admin & Production Hardening (Week 8)
**Goal**: Admin panel API, security, performance, deployment

- [ ] Admin module (dashboard stats, user management, payment approval)
- [ ] Rate limiting (@nestjs/throttler)
- [ ] Request logging (Winston + Morgan)
- [ ] Health checks (@nestjs/terminus)
- [ ] Database seeding (admin user, communication fees)
- [ ] Email service (SendGrid/Nodemailer) for verification & receipts
- [ ] Unit tests for services (Jest)
- [ ] E2E tests for critical flows (auth, booking)
- [ ] Nginx reverse proxy configuration
- [ ] SSL/TLS with Let's Encrypt
- [ ] PM2 ecosystem configuration
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Production docker-compose with Redis, PostgreSQL, app

**Deliverable**: Production-ready, secure, deployed backend

---

### Phase 6: Flutter App Migration (Week 9-10)
**Goal**: Update Flutter app to use custom backend instead of Firebase

- [ ] Create API client service (Dio/http)
- [ ] Replace Firebase Auth with JWT auth flow
- [ ] Replace Firestore queries with REST API calls
- [ ] Replace Firebase Storage with S3 upload endpoints
- [ ] Replace FCM direct integration with backend-driven notifications
- [ ] Update real-time features to use WebSocket (Socket.IO client)
- [ ] Update all BLoC/Provider to use new API
- [ ] Test all flows end-to-end

**Deliverable**: Flutter app fully migrated to custom backend

---

## Docker Compose Setup (Production)

```yaml
services:
  app:
    build: .
    ports: ["3000:3000"]
    depends_on: [postgres, redis]
    env_file: .env

  postgres:
    image: postgres:16-alpine
    volumes: [postgres_data:/var/lib/postgresql/data]
    environment:
      POSTGRES_DB: rideshare
      POSTGRES_USER: rideshare_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}

  redis:
    image: redis:7-alpine
    volumes: [redis_data:/data]

  nginx:
    image: nginx:alpine
    ports: ["80:80", "443:443"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./certbot/conf:/etc/letsencrypt
    depends_on: [app]
```

---

## Environment Variables (.env)

```env
# App
PORT=3000
NODE_ENV=production
API_PREFIX=api/v1

# Database
DB_HOST=postgres
DB_PORT=5432
DB_NAME=rideshare
DB_USER=rideshare_user
DB_PASSWORD=<secure_password>

# JWT
JWT_SECRET=<random_secret_key>
JWT_EXPIRES_IN=15m
JWT_REFRESH_SECRET=<random_refresh_secret>
JWT_REFRESH_EXPIRES_IN=7d

# Twilio (OTP)
TWILIO_ACCOUNT_SID=<sid>
TWILIO_AUTH_TOKEN=<token>
TWILIO_PHONE_NUMBER=<phone>

# Google OAuth
GOOGLE_CLIENT_ID=<client_id>
GOOGLE_CLIENT_SECRET=<client_secret>

# Facebook OAuth
FACEBOOK_APP_ID=<app_id>
FACEBOOK_APP_SECRET=<app_secret>

# AWS S3
AWS_ACCESS_KEY_ID=<key>
AWS_SECRET_ACCESS_KEY=<secret>
AWS_S3_BUCKET=rideshare-uploads
AWS_REGION=me-south-1

# Stripe
STRIPE_SECRET_KEY=<key>
STRIPE_WEBHOOK_SECRET=<secret>

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# FCM (or OneSignal)
FCM_SERVER_KEY=<key>

# Email
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=<email>
SMTP_PASSWORD=<password>

# Google Maps
GOOGLE_MAPS_API_KEY=<key>
```

---

## Verification & Testing Plan

1. **Auth**: Register -> Login -> Get Profile -> Refresh Token -> Logout
2. **Driver Flow**: Add Vehicle -> Create Trip -> View Bookings -> Confirm -> Complete
3. **Passenger Flow**: Search Trips -> Select Seat -> Book -> Pay -> Rate
4. **Chat**: Create Room -> Send Message (WebSocket) -> Receive in Real-time
5. **Admin**: Login as Admin -> View Stats -> Approve Payments -> Manage Users
6. **Load Test**: Artillery or k6 for concurrent booking stress test
7. **Run**: `npm test` (unit) + `npm run test:e2e` (integration)
