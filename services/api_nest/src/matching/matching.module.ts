import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { MatchingGateway } from './matching.gateway';
import { MatchingService } from './matching.service';
import { RidersModule } from '../riders/riders.module';
import { TripsModule } from '../trips/trips.module';
import { PrismaService } from '../prisma.service';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-jwt-secret',
    }),
    RidersModule,
    TripsModule,
  ],
  providers: [MatchingGateway, MatchingService, PrismaService],
  exports: [MatchingGateway],
})
export class MatchingModule {}
