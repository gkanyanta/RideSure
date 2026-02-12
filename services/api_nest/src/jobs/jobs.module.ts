import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { InsuranceExpiryJob } from './insurance-expiry.job';
import { PrismaService } from '../prisma.service';

@Module({
  imports: [ScheduleModule.forRoot()],
  providers: [InsuranceExpiryJob, PrismaService],
})
export class JobsModule {}
