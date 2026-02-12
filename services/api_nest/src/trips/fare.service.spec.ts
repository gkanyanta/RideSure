import { Test, TestingModule } from '@nestjs/testing';
import { FareService } from './fare.service';
import { PrismaService } from '../prisma.service';

describe('FareService', () => {
  let service: FareService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      fareConfig: {
        findFirst: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FareService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<FareService>(FareService);
  });

  describe('calculateDistance', () => {
    it('should return 0 for same coordinates', () => {
      const distance = service.calculateDistance(-12.54, 28.23, -12.54, 28.23);
      expect(distance).toBeCloseTo(0, 1);
    });

    it('should calculate correct distance between known points', () => {
      // Mufulira center to Kantanshi (~3km approx)
      const distance = service.calculateDistance(
        -12.5432, 28.2311,
        -12.5200, 28.2400,
      );
      expect(distance).toBeGreaterThan(2);
      expect(distance).toBeLessThan(4);
    });

    it('should be symmetric', () => {
      const d1 = service.calculateDistance(-12.54, 28.23, -12.55, 28.24);
      const d2 = service.calculateDistance(-12.55, 28.24, -12.54, 28.23);
      expect(d1).toBeCloseTo(d2, 5);
    });
  });

  describe('estimate', () => {
    it('should apply minimum fare for very short distances', async () => {
      prisma.fareConfig.findFirst.mockResolvedValue({
        baseFare: 10,
        perKmRate: 5,
        minimumFare: 15,
      });

      const result = await service.estimate(-12.5432, 28.2311, -12.5435, 28.2315);
      expect(result.estimatedFare).toBeGreaterThanOrEqual(15);
    });

    it('should calculate fare = base + distance * rate for longer trips', async () => {
      prisma.fareConfig.findFirst.mockResolvedValue({
        baseFare: 10,
        perKmRate: 5,
        minimumFare: 15,
      });

      // ~2.7km trip
      const result = await service.estimate(-12.5432, 28.2311, -12.5200, 28.2400);
      const expected = 10 + result.distance * 5;
      expect(result.estimatedFare).toBeCloseTo(expected, 1);
    });

    it('should return ±10% range', async () => {
      prisma.fareConfig.findFirst.mockResolvedValue({
        baseFare: 10,
        perKmRate: 5,
        minimumFare: 15,
      });

      const result = await service.estimate(-12.5432, 28.2311, -12.5200, 28.2400);
      expect(result.estimatedFareLow).toBeCloseTo(result.estimatedFare * 0.9, 1);
      expect(result.estimatedFareHigh).toBeCloseTo(result.estimatedFare * 1.1, 1);
    });

    it('should use default values when no config exists', async () => {
      prisma.fareConfig.findFirst.mockResolvedValue(null);

      const result = await service.estimate(-12.5432, 28.2311, -12.5200, 28.2400);
      expect(result.baseFare).toBe(10);
      expect(result.perKmRate).toBe(5);
    });

    it('should resolve Mufulira for southern coordinates', async () => {
      prisma.fareConfig.findFirst.mockResolvedValue({
        baseFare: 10, perKmRate: 5, minimumFare: 15,
      });

      const result = await service.estimate(-12.5432, 28.2311, -12.5500, 28.2400);
      expect(result.town).toBe('Mufulira');
    });

    it('should resolve Chililabombwe for northern coordinates', async () => {
      prisma.fareConfig.findFirst.mockResolvedValue({
        baseFare: 10, perKmRate: 5, minimumFare: 15,
      });

      const result = await service.estimate(-12.3700, 28.1500, -12.3800, 28.1600);
      expect(result.town).toBe('Chililabombwe');
    });
  });
});
