import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { FareService } from './fare.service';
import { StorageService } from '../storage/storage.service';
import { TripStatus } from '@prisma/client';
import { v4 as uuid } from 'uuid';

const VALID_TRANSITIONS: Record<TripStatus, TripStatus[]> = {
  REQUESTED: ['OFFERED', 'CANCELLED'],
  OFFERED: ['ACCEPTED', 'REQUESTED', 'CANCELLED'],
  ACCEPTED: ['ARRIVED', 'CANCELLED'],
  ARRIVED: ['IN_PROGRESS'],
  IN_PROGRESS: ['COMPLETED'],
  COMPLETED: [],
  CANCELLED: [],
};

@Injectable()
export class TripsService {
  private readonly logger = new Logger(TripsService.name);

  constructor(
    private prisma: PrismaService,
    private fareService: FareService,
    private storage: StorageService,
  ) {}

  async createTrip(passengerId: string, data: {
    type: 'RIDE' | 'DELIVERY';
    pickupLat: number; pickupLng: number; pickupAddress: string; pickupLandmark?: string;
    destinationLat: number; destinationLng: number; destinationAddress: string; destinationLandmark?: string;
    packageType?: string; packageNotes?: string;
  }) {
    // Get fare estimate
    const fare = await this.fareService.estimate(
      data.pickupLat, data.pickupLng,
      data.destinationLat, data.destinationLng,
    );

    const shareCode = uuid().slice(0, 8).toUpperCase();

    const trip = await this.prisma.trip.create({
      data: {
        type: data.type,
        passengerId,
        pickupLat: data.pickupLat,
        pickupLng: data.pickupLng,
        pickupAddress: data.pickupAddress,
        pickupLandmark: data.pickupLandmark,
        destinationLat: data.destinationLat,
        destinationLng: data.destinationLng,
        destinationAddress: data.destinationAddress,
        destinationLandmark: data.destinationLandmark,
        estimatedDistance: fare.distance,
        estimatedFareLow: fare.estimatedFareLow,
        estimatedFareHigh: fare.estimatedFareHigh,
        packageType: data.packageType,
        packageNotes: data.packageNotes,
        shareCode,
        status: 'REQUESTED',
      },
    });

    await this.logEvent(trip.id, 'TRIP_REQUESTED', { fare });

    return { trip, fareEstimate: fare };
  }

  async transitionStatus(
    tripId: string,
    newStatus: TripStatus,
    actorId: string,
    extras?: { riderId?: string; cancelReason?: string; actualFare?: number },
  ) {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');

    const allowed = VALID_TRANSITIONS[trip.status];
    if (!allowed.includes(newStatus)) {
      throw new BadRequestException(
        `Cannot transition from ${trip.status} to ${newStatus}`,
      );
    }

    const updateData: any = { status: newStatus };
    const now = new Date();

    switch (newStatus) {
      case 'OFFERED':
        updateData.riderId = extras?.riderId;
        break;
      case 'ACCEPTED':
        updateData.acceptedAt = now;
        updateData.riderId = extras?.riderId || trip.riderId;
        break;
      case 'ARRIVED':
        updateData.arrivedAt = now;
        break;
      case 'IN_PROGRESS':
        updateData.startedAt = now;
        break;
      case 'COMPLETED':
        updateData.completedAt = now;
        updateData.actualFare = extras?.actualFare || trip.estimatedFareHigh;
        // Update rider stats
        if (trip.riderId) {
          await this.prisma.rider.update({
            where: { id: trip.riderId },
            data: { totalTrips: { increment: 1 } },
          });
        }
        break;
      case 'CANCELLED':
        updateData.cancelledAt = now;
        updateData.cancelledBy = actorId;
        updateData.cancelReason = extras?.cancelReason || 'No reason provided';
        break;
    }

    const updated = await this.prisma.trip.update({
      where: { id: tripId },
      data: updateData,
      include: {
        rider: { include: { user: { select: { name: true, phone: true } }, vehicle: true } },
        passenger: { select: { id: true, name: true, phone: true } },
      },
    });

    await this.logEvent(tripId, `STATUS_${newStatus}`, { actorId, ...extras });

    return updated;
  }

  async getTrip(tripId: string) {
    const trip = await this.prisma.trip.findUnique({
      where: { id: tripId },
      include: {
        rider: {
          include: {
            user: { select: { name: true, phone: true } },
            vehicle: true,
            documents: {
              where: { type: 'INSURANCE_CERTIFICATE', status: 'APPROVED' },
              select: { insurerName: true, expiryDate: true },
            },
          },
        },
        passenger: { select: { id: true, name: true, phone: true } },
        events: { orderBy: { createdAt: 'desc' }, take: 20 },
        rating: true,
      },
    });
    if (!trip) throw new NotFoundException('Trip not found');
    return trip;
  }

  async getTripByShareCode(shareCode: string) {
    const trip = await this.prisma.trip.findUnique({
      where: { shareCode },
      include: {
        rider: {
          include: {
            user: { select: { name: true } },
            vehicle: true,
          },
        },
        events: { orderBy: { createdAt: 'desc' }, take: 5 },
      },
    });
    if (!trip) throw new NotFoundException('Trip not found');
    return {
      id: trip.id,
      type: trip.type,
      status: trip.status,
      pickupAddress: trip.pickupAddress,
      destinationAddress: trip.destinationAddress,
      riderName: trip.rider?.user?.name,
      vehicleModel: trip.rider?.vehicle?.model,
      vehiclePlate: trip.rider?.vehicle?.plateNumber,
      riderLat: trip.rider?.currentLat,
      riderLng: trip.rider?.currentLng,
    };
  }

  async getPassengerTrips(passengerId: string) {
    return this.prisma.trip.findMany({
      where: { passengerId },
      include: {
        rider: {
          include: {
            user: { select: { name: true } },
            vehicle: { select: { model: true, plateNumber: true } },
          },
        },
        rating: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getRiderTrips(riderId: string) {
    return this.prisma.trip.findMany({
      where: { riderId },
      include: {
        passenger: { select: { name: true, phone: true } },
        rating: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async rateTrip(tripId: string, passengerId: string, score: number, comment?: string) {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.status !== 'COMPLETED') throw new BadRequestException('Can only rate completed trips');
    if (trip.passengerId !== passengerId) throw new ForbiddenException('Not your trip');
    if (!trip.riderId) throw new BadRequestException('No rider assigned');

    if (score < 1 || score > 5) throw new BadRequestException('Score must be 1-5');

    const rating = await this.prisma.rating.create({
      data: { tripId, passengerId, riderId: trip.riderId, score, comment },
    });

    // Update rider average
    const agg = await this.prisma.rating.aggregate({
      where: { riderId: trip.riderId },
      _avg: { score: true },
    });
    await this.prisma.rider.update({
      where: { id: trip.riderId },
      data: { avgRating: agg._avg.score || 0 },
    });

    return rating;
  }

  async uploadDeliveryPhoto(
    tripId: string,
    riderId: string,
    phase: 'pickup' | 'dropoff',
    file: Express.Multer.File,
  ) {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.riderId !== riderId) throw new ForbiddenException('Not your trip');
    if (trip.type !== 'DELIVERY') throw new BadRequestException('Not a delivery trip');

    const filePath = await this.storage.save(file, `delivery/${tripId}`);
    const field = phase === 'pickup' ? 'pickupPhotoPath' : 'dropoffPhotoPath';

    return this.prisma.trip.update({
      where: { id: tripId },
      data: { [field]: filePath },
    });
  }

  // SOS / Incidents
  async reportIncident(
    tripId: string | null,
    reporterId: string,
    description: string,
    severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL' = 'HIGH',
  ) {
    const incident = await this.prisma.incident.create({
      data: {
        tripId,
        reporterId,
        description,
        severity,
      },
    });

    if (tripId) {
      await this.logEvent(tripId, 'SOS_TRIGGERED', { incidentId: incident.id });
    }

    return incident;
  }

  async listIncidents() {
    return this.prisma.incident.findMany({
      include: {
        reporter: { select: { name: true, phone: true } },
        trip: { select: { id: true, status: true, type: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // Admin trip listing
  async listTrips(status?: TripStatus, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [trips, total] = await Promise.all([
      this.prisma.trip.findMany({
        where: status ? { status } : undefined,
        include: {
          passenger: { select: { name: true, phone: true } },
          rider: { include: { user: { select: { name: true } } } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.trip.count({ where: status ? { status } : undefined }),
    ]);
    return { trips, total, page, limit };
  }

  private async logEvent(tripId: string, event: string, data?: any) {
    await this.prisma.tripEvent.create({
      data: { tripId, event, data: data || {} },
    });
  }
}
