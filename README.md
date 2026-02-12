# RideSure - Motorcycle Ride & Delivery Platform

MVP motorcycle ride-hailing and delivery platform for Mufulira and Chililabombwe, Zambia.

## Architecture

```
/apps
  /passenger_flutter   - Passenger Android app (Flutter)
  /rider_flutter       - Rider Android app (Flutter)
  /admin_next          - Admin web dashboard (Next.js + Tailwind)
/services
  /api_nest            - Backend API (NestJS + Prisma + PostgreSQL + Socket.IO)
/infra
  docker-compose.yml   - Local dev infrastructure
```

## Quick Start

### Prerequisites
- Node.js 20+
- PostgreSQL 15+
- Flutter SDK 3.x (for mobile apps)

### 1. Database Setup

```bash
# Create database and user
sudo -u postgres psql -c "CREATE USER ridesure WITH PASSWORD 'ridesure_pass' CREATEDB;"
sudo -u postgres psql -c "CREATE DATABASE ridesure OWNER ridesure;"
```

Or with Docker:
```bash
cd infra && docker compose up -d postgres
```

### 2. Backend API

```bash
cd services/api_nest

# Install dependencies
npm install

# Push schema to database
npx prisma db push

# Seed database (admin user, fare configs, test data)
npx prisma seed

# Start dev server
npm run start:dev
```

API runs at `http://localhost:3000`
Swagger docs at `http://localhost:3000/api/docs`

**Seed data:**
- Admin: `admin@ridesure.zm` / `admin123`
- Test passenger: `+260971000001`
- Test rider: `+260971000002` (pre-approved)
- Fare configs for Mufulira and Chililabombwe

### 3. Admin Dashboard

```bash
cd apps/admin_next
npm install
npm run dev
```

Dashboard runs at `http://localhost:3001`

### 4. Flutter Apps

```bash
# Rider app
cd apps/rider_flutter
flutter pub get
flutter run

# Passenger app
cd apps/passenger_flutter
flutter pub get
flutter run
```

### Environment Variables

Backend (`services/api_nest/.env`):
```
DATABASE_URL=postgresql://ridesure:ridesure_pass@localhost:5432/ridesure?schema=public
JWT_SECRET=your-secret-key
JWT_EXPIRATION=7d
OTP_EXPIRY_MINUTES=5
UPLOAD_DIR=../../uploads
PORT=3000
MATCHING_INITIAL_RADIUS_KM=3
MATCHING_EXPANDED_RADIUS_KM=6
MATCHING_BROADCAST_COUNT=5
MATCHING_ACCEPTANCE_WINDOW_SEC=15
```

Admin (`apps/admin_next/.env.local`):
```
NEXT_PUBLIC_API_URL=http://localhost:3000/api
```

## API Endpoints

### Auth
- `POST /api/auth/otp/request` - Request OTP
- `POST /api/auth/otp/verify` - Verify OTP and get JWT
- `POST /api/auth/admin/login` - Admin login

### Riders
- `GET /api/riders/profile` - Get rider profile
- `POST /api/riders/vehicle` - Create/update vehicle
- `POST /api/riders/documents/:type` - Upload document (NRC, SELFIE, RIDER_LICENCE, INSURANCE_CERTIFICATE)
- `PUT /api/riders/location` - Update location
- `PUT /api/riders/online` - Go online/offline
- `GET /api/riders/insurance-warning` - Get insurance expiry warning
- `GET /api/riders/admin/pending` - Admin: pending approvals
- `PATCH /api/riders/admin/:id/review` - Admin: approve/reject rider
- `GET /api/riders/admin/list` - Admin: list all riders

### Trips
- `POST /api/trips/estimate` - Get fare estimate
- `POST /api/trips` - Request ride or delivery
- `GET /api/trips/my` - Passenger trip history
- `GET /api/trips/rider/my` - Rider trip history
- `GET /api/trips/:id` - Trip details
- `GET /api/trips/share/:code` - Public trip status by share code
- `PATCH /api/trips/:id/cancel` - Cancel trip
- `PATCH /api/trips/:id/arrived` - Rider arrived at pickup
- `PATCH /api/trips/:id/start` - Start trip
- `PATCH /api/trips/:id/complete` - Complete trip
- `POST /api/trips/:id/rate` - Rate trip
- `POST /api/trips/:id/delivery-photo/:phase` - Upload delivery proof photo
- `POST /api/trips/:id/sos` - Trigger SOS
- `GET /api/trips/admin/list` - Admin: list trips
- `GET /api/trips/admin/incidents` - Admin: list incidents

### WebSocket Events (Socket.IO, namespace: /ws)

**Client → Server:**
- `rider:location` - `{ lat, lng }`
- `trip:request` - `{ tripId }`
- `trip:accept` - `{ tripId }`
- `trip:reject` - `{ tripId }`

**Server → Client:**
- `trip:offer` - Job offer to rider
- `trip:searching` - Searching for riders
- `trip:accepted` - Rider accepted trip
- `trip:confirmed` - Confirmation to rider
- `trip:no_riders` - No riders available

## Trip Lifecycle

```
REQUESTED → OFFERED → ACCEPTED → ARRIVED → IN_PROGRESS → COMPLETED
                 ↑          ↓
                 └── REQUESTED (timeout/reject)

CANCELLED possible from: REQUESTED, OFFERED, ACCEPTED
```

## Key Features

- **OTP Authentication** - Phone-based auth (mock OTP in dev)
- **Insurance-Anchored Verification** - Rider must upload insurance; auto-suspend on expiry
- **Realtime Matching** - Sequential broadcast to nearest riders with 15s acceptance window
- **Two Job Types** - Ride (passenger) and Delivery (with photo proof)
- **Trip Sharing** - Shareable trip code with public status endpoint
- **SOS Safety** - Emergency button logs incident
- **Cash-Only MVP** - All trips digitally logged, paid in cash
- **Daily Insurance Check** - Cron job auto-suspends riders with expired insurance

## Running Tests

```bash
cd services/api_nest
npm test
```

## Tech Stack

- **Mobile**: Flutter (Android-first)
- **Backend**: NestJS + TypeScript + Prisma + PostgreSQL
- **Realtime**: Socket.IO
- **Admin**: Next.js + Tailwind CSS
- **Infrastructure**: Docker Compose
