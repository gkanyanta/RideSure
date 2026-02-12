import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma.service';

@Injectable()
export class InsuranceExpiryJob {
  private readonly logger = new Logger(InsuranceExpiryJob.name);

  constructor(private prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_6AM)
  async checkExpiredInsurance() {
    this.logger.log('Running insurance expiry check...');

    const now = new Date();

    // Find all approved riders with expired insurance
    const expiredDocs = await this.prisma.riderDocument.findMany({
      where: {
        type: 'INSURANCE_CERTIFICATE',
        status: 'APPROVED',
        expiryDate: { lt: now },
      },
      include: {
        rider: { select: { id: true, status: true, userId: true } },
      },
    });

    let suspendedCount = 0;
    for (const doc of expiredDocs) {
      if (doc.rider.status === 'APPROVED') {
        await this.prisma.rider.update({
          where: { id: doc.rider.id },
          data: { status: 'SUSPENDED', isOnline: false },
        });
        suspendedCount++;
        this.logger.warn(`Suspended rider ${doc.rider.id} — insurance expired`);
      }
    }

    this.logger.log(`Insurance check complete. Suspended ${suspendedCount} rider(s).`);
  }
}
