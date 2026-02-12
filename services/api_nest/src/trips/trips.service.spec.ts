import { Test, TestingModule } from '@nestjs/testing';
import { TripsService } from './trips.service';
import { FareService } from './fare.service';
import { PrismaService } from '../prisma.service';
import { StorageService } from '../storage/storage.service';
import { BadRequestException } from '@nestjs/common';

describe('TripsService - state transitions', () => {
  let service: TripsService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      trip: {
        findUnique: jest.fn(),
        update: jest.fn(),
        create: jest.fn(),
      },
      tripEvent: {
        create: jest.fn(),
      },
      rider: {
        update: jest.fn(),
      },
      rating: {
        create: jest.fn(),
        aggregate: jest.fn(),
      },
    };

    const fareService = {
      estimate: jest.fn().mockResolvedValue({
        distance: 3.5,
        baseFare: 10,
        perKmRate: 5,
        estimatedFare: 27.5,
        estimatedFareLow: 24.75,
        estimatedFareHigh: 30.25,
        town: 'Mufulira',
      }),
    };

    const storageService = {
      save: jest.fn().mockResolvedValue('path/to/file'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TripsService,
        { provide: PrismaService, useValue: prisma },
        { provide: FareService, useValue: fareService },
        { provide: StorageService, useValue: storageService },
      ],
    }).compile();

    service = module.get<TripsService>(TripsService);
  });

  const mockTrip = (status: string) => ({
    id: 'trip-1',
    status,
    passengerId: 'p-1',
    riderId: 'r-1',
    estimatedFareHigh: 30.25,
  });

  describe('valid transitions', () => {
    it('REQUESTED → OFFERED', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('REQUESTED'));
      prisma.trip.update.mockResolvedValue({ ...mockTrip('OFFERED'), status: 'OFFERED' });

      const result = await service.transitionStatus('trip-1', 'OFFERED', 'system', { riderId: 'r-1' });
      expect(result.status).toBe('OFFERED');
    });

    it('OFFERED → ACCEPTED', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('OFFERED'));
      prisma.trip.update.mockResolvedValue({ ...mockTrip('ACCEPTED'), status: 'ACCEPTED' });

      const result = await service.transitionStatus('trip-1', 'ACCEPTED', 'r-1');
      expect(result.status).toBe('ACCEPTED');
    });

    it('ACCEPTED → ARRIVED', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('ACCEPTED'));
      prisma.trip.update.mockResolvedValue({ ...mockTrip('ARRIVED'), status: 'ARRIVED' });

      const result = await service.transitionStatus('trip-1', 'ARRIVED', 'r-1');
      expect(result.status).toBe('ARRIVED');
    });

    it('ARRIVED → IN_PROGRESS', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('ARRIVED'));
      prisma.trip.update.mockResolvedValue({ ...mockTrip('IN_PROGRESS'), status: 'IN_PROGRESS' });

      const result = await service.transitionStatus('trip-1', 'IN_PROGRESS', 'r-1');
      expect(result.status).toBe('IN_PROGRESS');
    });

    it('IN_PROGRESS → COMPLETED', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('IN_PROGRESS'));
      prisma.trip.update.mockResolvedValue({ ...mockTrip('COMPLETED'), status: 'COMPLETED' });
      prisma.rider.update.mockResolvedValue({});

      const result = await service.transitionStatus('trip-1', 'COMPLETED', 'r-1');
      expect(result.status).toBe('COMPLETED');
    });

    it('REQUESTED → CANCELLED', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('REQUESTED'));
      prisma.trip.update.mockResolvedValue({ ...mockTrip('CANCELLED'), status: 'CANCELLED' });

      const result = await service.transitionStatus('trip-1', 'CANCELLED', 'p-1', {
        cancelReason: 'Changed mind',
      });
      expect(result.status).toBe('CANCELLED');
    });

    it('ACCEPTED → CANCELLED', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('ACCEPTED'));
      prisma.trip.update.mockResolvedValue({ ...mockTrip('CANCELLED'), status: 'CANCELLED' });

      const result = await service.transitionStatus('trip-1', 'CANCELLED', 'p-1', {
        cancelReason: 'Emergency',
      });
      expect(result.status).toBe('CANCELLED');
    });
  });

  describe('invalid transitions', () => {
    it('REQUESTED → COMPLETED should throw', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('REQUESTED'));

      await expect(
        service.transitionStatus('trip-1', 'COMPLETED', 'r-1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('COMPLETED → CANCELLED should throw', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('COMPLETED'));

      await expect(
        service.transitionStatus('trip-1', 'CANCELLED', 'p-1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('CANCELLED → REQUESTED should throw', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('CANCELLED'));

      await expect(
        service.transitionStatus('trip-1', 'REQUESTED', 'p-1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('ARRIVED → ACCEPTED should throw', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('ARRIVED'));

      await expect(
        service.transitionStatus('trip-1', 'ACCEPTED', 'r-1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('IN_PROGRESS → ARRIVED should throw', async () => {
      prisma.trip.findUnique.mockResolvedValue(mockTrip('IN_PROGRESS'));

      await expect(
        service.transitionStatus('trip-1', 'ARRIVED', 'r-1'),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
