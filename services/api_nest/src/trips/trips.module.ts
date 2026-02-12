import { Module } from '@nestjs/common';
import { TripsController } from './trips.controller';
import { TripsService } from './trips.service';
import { FareService } from './fare.service';
import { PrismaService } from '../prisma.service';

@Module({
  controllers: [TripsController],
  providers: [TripsService, FareService, PrismaService],
  exports: [TripsService, FareService],
})
export class TripsModule {}
