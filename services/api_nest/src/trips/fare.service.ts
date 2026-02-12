import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

export interface FareEstimate {
  distance: number;
  baseFare: number;
  perKmRate: number;
  estimatedFare: number;
  estimatedFareLow: number;
  estimatedFareHigh: number;
  town: string;
}

@Injectable()
export class FareService {
  constructor(private prisma: PrismaService) {}

  async estimate(
    pickupLat: number,
    pickupLng: number,
    destLat: number,
    destLng: number,
    town?: string,
  ): Promise<FareEstimate> {
    const distance = this.calculateDistance(pickupLat, pickupLng, destLat, destLng);

    // Determine town from coordinates (simple: Mufulira vs Chililabombwe by latitude)
    const resolvedTown = town || this.resolveTown(pickupLat);

    const config = await this.prisma.fareConfig.findFirst({
      where: { town: resolvedTown, isActive: true },
    });

    const baseFare = config?.baseFare ?? 10;
    const perKmRate = config?.perKmRate ?? 5;
    const minimumFare = config?.minimumFare ?? 15;

    let fare = baseFare + distance * perKmRate;
    fare = Math.max(fare, minimumFare);
    fare = Math.round(fare * 100) / 100;

    return {
      distance: Math.round(distance * 100) / 100,
      baseFare,
      perKmRate,
      estimatedFare: fare,
      estimatedFareLow: Math.round(fare * 0.9 * 100) / 100,
      estimatedFareHigh: Math.round(fare * 1.1 * 100) / 100,
      town: resolvedTown,
    };
  }

  calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
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

  private resolveTown(lat: number): string {
    // Chililabombwe is further south (~-12.37), Mufulira (~-12.54)
    return lat > -12.45 ? 'Chililabombwe' : 'Mufulira';
  }
}
