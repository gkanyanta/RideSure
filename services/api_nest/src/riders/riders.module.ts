import { Module } from '@nestjs/common';
import { RidersController } from './riders.controller';
import { RidersService } from './riders.service';
import { PrismaService } from '../prisma.service';

@Module({
  controllers: [RidersController],
  providers: [RidersService, PrismaService],
  exports: [RidersService],
})
export class RidersModule {}
