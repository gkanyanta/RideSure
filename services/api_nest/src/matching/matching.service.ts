import { Injectable, Logger } from '@nestjs/common';
import { Server } from 'socket.io';
import { PrismaService } from '../prisma.service';
import { RidersService } from '../riders/riders.service';
import { TripsService } from '../trips/trips.service';

interface MatchingSession {
  tripId: string;
  passengerId: string;
  candidateRiderUserIds: string[];
  currentIndex: number;
  radiusKm: number;
  timer?: NodeJS.Timeout;
  resolved: boolean;
}

@Injectable()
export class MatchingService {
  private readonly logger = new Logger(MatchingService.name);
  private sessions = new Map<string, MatchingSession>();

  private readonly initialRadius: number;
  private readonly expandedRadius: number;
  private readonly broadcastCount: number;
  private readonly acceptanceWindowSec: number;

  constructor(
    private prisma: PrismaService,
    private ridersService: RidersService,
    private tripsService: TripsService,
  ) {
    this.initialRadius = parseFloat(process.env.MATCHING_INITIAL_RADIUS_KM || '3');
    this.expandedRadius = parseFloat(process.env.MATCHING_EXPANDED_RADIUS_KM || '6');
    this.broadcastCount = parseInt(process.env.MATCHING_BROADCAST_COUNT || '5', 10);
    this.acceptanceWindowSec = parseInt(process.env.MATCHING_ACCEPTANCE_WINDOW_SEC || '15', 10);
  }

  async updateRiderLocation(userId: string, lat: number, lng: number) {
    const rider = await this.prisma.rider.findUnique({ where: { userId } });
    if (rider) {
      await this.prisma.rider.update({
        where: { id: rider.id },
        data: { currentLat: lat, currentLng: lng, lastLocationAt: new Date() },
      });
    }
  }

  async startMatching(tripId: string, server: Server) {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip || trip.status !== 'REQUESTED') return;

    // Find nearby riders
    let riders = await this.ridersService.findNearbyOnlineRiders(
      trip.pickupLat, trip.pickupLng, this.initialRadius,
    );

    if (riders.length === 0) {
      // Expand radius
      riders = await this.ridersService.findNearbyOnlineRiders(
        trip.pickupLat, trip.pickupLng, this.expandedRadius,
      );
    }

    if (riders.length === 0) {
      server.to(`user:${trip.passengerId}`).emit('trip:no_riders', { tripId });
      await this.tripsService.transitionStatus(tripId, 'CANCELLED', 'SYSTEM', {
        cancelReason: 'No riders available',
      });
      return;
    }

    const candidateRiderUserIds = riders
      .slice(0, this.broadcastCount)
      .map(r => r.userId);

    const session: MatchingSession = {
      tripId,
      passengerId: trip.passengerId,
      candidateRiderUserIds,
      currentIndex: 0,
      radiusKm: this.initialRadius,
      resolved: false,
    };

    this.sessions.set(tripId, session);
    this.offerToNext(session, server);
  }

  private async offerToNext(session: MatchingSession, server: Server) {
    if (session.resolved) return;

    if (session.currentIndex >= session.candidateRiderUserIds.length) {
      // If we were on initial radius, try expanded
      if (session.radiusKm < this.expandedRadius) {
        session.radiusKm = this.expandedRadius;
        const trip = await this.prisma.trip.findUnique({ where: { id: session.tripId } });
        if (!trip) return;

        const riders = await this.ridersService.findNearbyOnlineRiders(
          trip.pickupLat, trip.pickupLng, this.expandedRadius,
        );

        const newCandidates = riders
          .filter(r => !session.candidateRiderUserIds.includes(r.userId))
          .slice(0, this.broadcastCount)
          .map(r => r.userId);

        if (newCandidates.length > 0) {
          session.candidateRiderUserIds.push(...newCandidates);
          this.offerToNext(session, server);
          return;
        }
      }

      // No more riders
      server.to(`user:${session.passengerId}`).emit('trip:no_riders', {
        tripId: session.tripId,
      });
      this.sessions.delete(session.tripId);
      return;
    }

    const riderUserId = session.candidateRiderUserIds[session.currentIndex];

    // Get trip details for the offer
    const trip = await this.prisma.trip.findUnique({
      where: { id: session.tripId },
      include: { passenger: { select: { name: true } } },
    });

    // Mark trip as OFFERED
    await this.tripsService.transitionStatus(session.tripId, 'OFFERED', 'SYSTEM', {
      riderId: (await this.prisma.rider.findUnique({ where: { userId: riderUserId } }))?.id,
    });

    server.to(`user:${riderUserId}`).emit('trip:offer', {
      tripId: session.tripId,
      type: trip?.type,
      passengerName: trip?.passenger?.name,
      pickupAddress: trip?.pickupAddress,
      pickupLandmark: trip?.pickupLandmark,
      pickupLat: trip?.pickupLat,
      pickupLng: trip?.pickupLng,
      destinationAddress: trip?.destinationAddress,
      destinationLat: trip?.destinationLat,
      destinationLng: trip?.destinationLng,
      estimatedFareLow: trip?.estimatedFareLow,
      estimatedFareHigh: trip?.estimatedFareHigh,
      estimatedDistance: trip?.estimatedDistance,
      packageType: trip?.packageType,
      packageNotes: trip?.packageNotes,
      timeoutSec: this.acceptanceWindowSec,
    });

    server.to(`user:${session.passengerId}`).emit('trip:searching', {
      tripId: session.tripId,
      message: 'Looking for a rider...',
    });

    // Start timeout
    session.timer = setTimeout(() => {
      if (!session.resolved) {
        session.currentIndex++;
        // Reset status back to REQUESTED so we can OFFER to next
        this.tripsService.transitionStatus(session.tripId, 'REQUESTED', 'SYSTEM').catch(() => {});
        this.offerToNext(session, server);
      }
    }, this.acceptanceWindowSec * 1000);
  }

  async acceptTrip(tripId: string, riderUserId: string, server: Server) {
    const session = this.sessions.get(tripId);
    if (!session || session.resolved) return;

    const currentRiderUserId = session.candidateRiderUserIds[session.currentIndex];
    if (currentRiderUserId !== riderUserId) return; // Not the current candidate

    session.resolved = true;
    if (session.timer) clearTimeout(session.timer);
    this.sessions.delete(tripId);

    const rider = await this.prisma.rider.findUnique({
      where: { userId: riderUserId },
      include: {
        user: { select: { name: true, phone: true } },
        vehicle: true,
        documents: {
          where: { type: 'INSURANCE_CERTIFICATE', status: 'APPROVED' },
          select: { insurerName: true, expiryDate: true },
        },
      },
    });

    const trip = await this.tripsService.transitionStatus(tripId, 'ACCEPTED', riderUserId, {
      riderId: rider?.id,
    });

    // Notify passenger
    server.to(`user:${session.passengerId}`).emit('trip:accepted', {
      tripId,
      rider: {
        name: rider?.user?.name,
        phone: rider?.user?.phone,
        rating: rider?.avgRating,
        totalTrips: rider?.totalTrips,
        vehicle: rider?.vehicle,
        insurance: rider?.documents?.[0],
      },
    });

    // Confirm to rider
    server.to(`user:${riderUserId}`).emit('trip:confirmed', { tripId, trip });
  }

  async rejectOffer(tripId: string, riderUserId: string, server: Server) {
    const session = this.sessions.get(tripId);
    if (!session || session.resolved) return;

    const currentRiderUserId = session.candidateRiderUserIds[session.currentIndex];
    if (currentRiderUserId !== riderUserId) return;

    if (session.timer) clearTimeout(session.timer);

    session.currentIndex++;
    await this.tripsService.transitionStatus(tripId, 'REQUESTED', 'SYSTEM').catch(() => {});
    this.offerToNext(session, server);
  }
}
