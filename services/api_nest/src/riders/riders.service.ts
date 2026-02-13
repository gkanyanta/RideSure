import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { DocumentType, RiderStatus } from '@prisma/client';

@Injectable()
export class RidersService {
  private readonly logger = new Logger(RidersService.name);

  constructor(
    private prisma: PrismaService,
  ) {}

  async getProfile(riderId: string) {
    const rider = await this.prisma.rider.findUnique({
      where: { id: riderId },
      include: {
        user: { select: { id: true, phone: true, name: true } },
        documents: {
          select: {
            id: true, type: true, status: true, insurerName: true,
            policyNumber: true, expiryDate: true, rejectionReason: true,
            createdAt: true,
          },
        },
        vehicle: true,
      },
    });
    if (!rider) throw new NotFoundException('Rider not found');
    return rider;
  }

  async createVehicle(riderId: string, data: { model: string; color?: string; make?: string; plateNumber: string }) {
    const existing = await this.prisma.vehicle.findUnique({ where: { riderId } });
    if (existing) {
      return this.prisma.vehicle.update({ where: { riderId }, data });
    }
    return this.prisma.vehicle.create({ data: { riderId, ...data } });
  }

  async uploadDocument(
    riderId: string,
    type: DocumentType,
    file: Express.Multer.File,
    insuranceData?: { insurerName: string; policyNumber: string; expiryDate: string },
  ) {
    const data: any = {
      riderId,
      type,
      filePath: `db://${riderId}/${type}`,
      originalName: file.originalname,
      mimeType: file.mimetype,
      fileData: file.buffer,
      status: 'PENDING',
    };

    if (type === DocumentType.INSURANCE_CERTIFICATE && insuranceData) {
      data.insurerName = insuranceData.insurerName;
      data.policyNumber = insuranceData.policyNumber;
      data.expiryDate = new Date(insuranceData.expiryDate);
    }

    const doc = await this.prisma.riderDocument.upsert({
      where: { riderId_type: { riderId, type } },
      update: { ...data, status: 'PENDING', rejectionReason: null },
      create: data,
    });

    // Check if all required docs are uploaded
    await this.checkAndUpdateStatus(riderId);

    // Return without fileData (don't send raw bytes back)
    const { fileData, ...result } = doc;
    return result;
  }

  private async checkAndUpdateStatus(riderId: string) {
    const docs = await this.prisma.riderDocument.findMany({
      where: { riderId },
    });

    const requiredTypes: DocumentType[] = [
      'SELFIE', 'RIDER_LICENCE', 'INSURANCE_CERTIFICATE',
      'BIKE_FRONT', 'BIKE_BACK', 'BIKE_LEFT', 'BIKE_RIGHT',
    ];
    const uploadedTypes = docs.map(d => d.type);
    const allUploaded = requiredTypes.every(t => uploadedTypes.includes(t));

    if (allUploaded) {
      const rider = await this.prisma.rider.findUnique({ where: { id: riderId } });
      if (rider?.status === 'PENDING_DOCUMENTS') {
        await this.prisma.rider.update({
          where: { id: riderId },
          data: { status: 'PENDING_APPROVAL' },
        });
      }
    }
  }

  async updateLocation(riderId: string, lat: number, lng: number) {
    return this.prisma.rider.update({
      where: { id: riderId },
      data: { currentLat: lat, currentLng: lng, lastLocationAt: new Date() },
    });
  }

  async setOnlineStatus(riderId: string, online: boolean) {
    const rider = await this.prisma.rider.findUnique({ where: { id: riderId } });
    if (!rider) throw new NotFoundException('Rider not found');

    if (online && rider.status !== 'APPROVED') {
      throw new ForbiddenException(
        `Cannot go online. Status: ${rider.status}. Must be APPROVED.`,
      );
    }

    // Check insurance expiry before going online
    if (online) {
      const insurance = await this.prisma.riderDocument.findFirst({
        where: { riderId, type: 'INSURANCE_CERTIFICATE' },
      });
      if (insurance?.expiryDate && insurance.expiryDate < new Date()) {
        await this.prisma.rider.update({
          where: { id: riderId },
          data: { status: 'SUSPENDED', isOnline: false },
        });
        throw new ForbiddenException('Insurance has expired. Your account is suspended.');
      }
    }

    return this.prisma.rider.update({
      where: { id: riderId },
      data: { isOnline: online },
    });
  }

  async getInsuranceWarning(riderId: string): Promise<{ daysRemaining: number | null; warning: string | null }> {
    const insurance = await this.prisma.riderDocument.findFirst({
      where: { riderId, type: 'INSURANCE_CERTIFICATE', status: 'APPROVED' },
    });

    if (!insurance?.expiryDate) return { daysRemaining: null, warning: null };

    const now = new Date();
    const diff = insurance.expiryDate.getTime() - now.getTime();
    const days = Math.ceil(diff / (1000 * 60 * 60 * 24));

    if (days <= 0) return { daysRemaining: 0, warning: 'Insurance has EXPIRED! Your account will be suspended.' };
    if (days <= 1) return { daysRemaining: days, warning: 'Insurance expires TOMORROW!' };
    if (days <= 3) return { daysRemaining: days, warning: `Insurance expires in ${days} days!` };
    if (days <= 7) return { daysRemaining: days, warning: `Insurance expires in ${days} days. Renew soon.` };

    return { daysRemaining: days, warning: null };
  }

  // -- Admin methods --

  async getPendingApprovals() {
    return this.prisma.rider.findMany({
      where: { status: 'PENDING_APPROVAL' },
      include: {
        user: { select: { id: true, phone: true, name: true } },
        documents: true,
        vehicle: true,
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async reviewRider(riderId: string, action: 'APPROVED' | 'REJECTED', adminId: string, reason?: string) {
    const rider = await this.prisma.rider.findUnique({
      where: { id: riderId },
      include: { documents: true },
    });
    if (!rider) throw new NotFoundException('Rider not found');

    if (action === 'APPROVED') {
      // Verify all docs exist
      const requiredTypes: DocumentType[] = [
        'SELFIE', 'RIDER_LICENCE', 'INSURANCE_CERTIFICATE',
        'BIKE_FRONT', 'BIKE_BACK', 'BIKE_LEFT', 'BIKE_RIGHT',
      ];
      const uploadedTypes = rider.documents.map(d => d.type);
      const missing = requiredTypes.filter(t => !uploadedTypes.includes(t));
      if (missing.length > 0) {
        throw new BadRequestException(`Missing documents: ${missing.join(', ')}`);
      }

      await this.prisma.$transaction([
        this.prisma.rider.update({
          where: { id: riderId },
          data: { status: 'APPROVED', rejectionReason: null },
        }),
        this.prisma.riderDocument.updateMany({
          where: { riderId, status: 'PENDING' },
          data: { status: 'APPROVED', reviewedAt: new Date(), reviewedBy: adminId },
        }),
      ]);
    } else {
      await this.prisma.rider.update({
        where: { id: riderId },
        data: { status: 'REJECTED', rejectionReason: reason || 'Documents not satisfactory' },
      });
    }

    return this.getProfile(riderId);
  }

  async listRiders(status?: RiderStatus) {
    return this.prisma.rider.findMany({
      where: status ? { status } : undefined,
      include: {
        user: { select: { id: true, phone: true, name: true } },
        vehicle: true,
        documents: {
          where: { type: 'INSURANCE_CERTIFICATE' },
          select: { expiryDate: true, status: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findNearbyOnlineRiders(lat: number, lng: number, radiusKm: number) {
    // Simple distance calculation using Haversine approximation
    // For MVP, use bounding box then filter
    const latDelta = radiusKm / 111.0;
    const lngDelta = radiusKm / (111.0 * Math.cos((lat * Math.PI) / 180));

    const riders = await this.prisma.rider.findMany({
      where: {
        isOnline: true,
        status: 'APPROVED',
        currentLat: { gte: lat - latDelta, lte: lat + latDelta },
        currentLng: { gte: lng - lngDelta, lte: lng + lngDelta },
      },
      include: {
        user: { select: { name: true, phone: true } },
        vehicle: true,
      },
    });

    // Calculate actual distance and sort
    return riders
      .map(rider => ({
        ...rider,
        distance: this.haversineDistance(
          lat, lng,
          rider.currentLat!, rider.currentLng!,
        ),
      }))
      .filter(r => r.distance <= radiusKm)
      .sort((a, b) => a.distance - b.distance);
  }

  private haversineDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLng / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
}
