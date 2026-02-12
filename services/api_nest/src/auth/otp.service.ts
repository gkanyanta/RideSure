import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

export interface OtpProvider {
  send(phone: string, code: string): Promise<boolean>;
}

/** Mock OTP provider for development — logs codes to console */
class MockOtpProvider implements OtpProvider {
  private readonly logger = new Logger('MockOTP');

  async send(phone: string, code: string): Promise<boolean> {
    this.logger.log(`OTP for ${phone}: ${code}`);
    return true;
  }
}

@Injectable()
export class OtpService {
  private readonly provider: OtpProvider;
  private readonly expiryMinutes: number;

  constructor(private prisma: PrismaService) {
    this.provider = new MockOtpProvider();
    this.expiryMinutes = parseInt(process.env.OTP_EXPIRY_MINUTES || '5', 10);
  }

  async generateAndSend(phone: string): Promise<{ sent: boolean }> {
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + this.expiryMinutes * 60 * 1000);

    await this.prisma.otpCode.create({
      data: { phone, code, expiresAt },
    });

    const sent = await this.provider.send(phone, code);
    return { sent };
  }

  async verify(phone: string, code: string): Promise<boolean> {
    const otp = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        code,
        used: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) return false;

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { used: true },
    });

    return true;
  }
}
