import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Create admin user
  const adminPassword = await bcrypt.hash('admin123', 10);
  await prisma.adminUser.upsert({
    where: { email: 'admin@ridesure.zm' },
    update: {},
    create: {
      email: 'admin@ridesure.zm',
      password: adminPassword,
      name: 'RideSure Admin',
    },
  });
  console.log('Admin user created: admin@ridesure.zm / admin123');

  // Create fare configs for both towns
  await prisma.fareConfig.upsert({
    where: { town_isActive: { town: 'Mufulira', isActive: true } },
    update: {},
    create: {
      town: 'Mufulira',
      baseFare: 10.0,
      perKmRate: 5.0,
      minimumFare: 15.0,
      nightMultiplier: 1.0,
      rainMultiplier: 1.0,
    },
  });

  await prisma.fareConfig.upsert({
    where: { town_isActive: { town: 'Chililabombwe', isActive: true } },
    update: {},
    create: {
      town: 'Chililabombwe',
      baseFare: 10.0,
      perKmRate: 5.0,
      minimumFare: 15.0,
      nightMultiplier: 1.0,
      rainMultiplier: 1.0,
    },
  });
  console.log('Fare configs created for Mufulira and Chililabombwe');

  // Create test passenger
  const passenger = await prisma.user.upsert({
    where: { phone: '+260971000001' },
    update: {},
    create: {
      phone: '+260971000001',
      name: 'Test Passenger',
      role: 'PASSENGER',
    },
  });
  console.log(`Test passenger: ${passenger.phone}`);

  // Create test rider user + rider profile
  const riderUser = await prisma.user.upsert({
    where: { phone: '+260971000002' },
    update: {},
    create: {
      phone: '+260971000002',
      name: 'Test Rider',
      role: 'RIDER',
    },
  });

  await prisma.rider.upsert({
    where: { userId: riderUser.id },
    update: {},
    create: {
      userId: riderUser.id,
      status: 'APPROVED',
      totalTrips: 25,
      avgRating: 4.5,
    },
  });

  await prisma.vehicle.upsert({
    where: { riderId: (await prisma.rider.findUnique({ where: { userId: riderUser.id } }))!.id },
    update: {},
    create: {
      riderId: (await prisma.rider.findUnique({ where: { userId: riderUser.id } }))!.id,
      model: 'Honda CG125',
      color: 'Red',
      plateNumber: 'MUF 1234',
    },
  });
  console.log(`Test rider: ${riderUser.phone}`);

  // Create a test rider pending approval (to test admin onboarding flow)
  const pendingRiderUser = await prisma.user.upsert({
    where: { phone: '+260971000003' },
    update: {},
    create: {
      phone: '+260971000003',
      name: 'John Banda',
      role: 'RIDER',
    },
  });

  const pendingRider = await prisma.rider.upsert({
    where: { userId: pendingRiderUser.id },
    update: {},
    create: {
      userId: pendingRiderUser.id,
      status: 'PENDING_APPROVAL',
    },
  });

  await prisma.vehicle.upsert({
    where: { riderId: pendingRider.id },
    update: {},
    create: {
      riderId: pendingRider.id,
      model: 'Boxer BM150',
      color: 'Blue',
      plateNumber: 'MUF 5678',
    },
  });

  // Create dummy documents for the pending rider (1x1 transparent PNG placeholder)
  const placeholderPng = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    'base64',
  );

  const documentTypes = [
    'SELFIE', 'RIDER_LICENCE', 'INSURANCE_CERTIFICATE',
    'BIKE_FRONT', 'BIKE_BACK', 'BIKE_LEFT', 'BIKE_RIGHT',
  ] as const;

  for (const docType of documentTypes) {
    const extra = docType === 'INSURANCE_CERTIFICATE'
      ? {
          insurerName: 'ZSIC General Insurance',
          policyNumber: 'POL-2026-00123',
          expiryDate: new Date('2027-06-30'),
        }
      : {};

    await prisma.riderDocument.upsert({
      where: { riderId_type: { riderId: pendingRider.id, type: docType } },
      update: {},
      create: {
        riderId: pendingRider.id,
        type: docType,
        status: 'PENDING',
        filePath: `db://${pendingRider.id}/${docType}`,
        originalName: `${docType.toLowerCase()}.png`,
        mimeType: 'image/png',
        fileData: placeholderPng,
        ...extra,
      },
    });
  }
  console.log(`Pending rider: ${pendingRiderUser.phone} (PENDING_APPROVAL with 7 documents)`);

  console.log('Seed completed successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
