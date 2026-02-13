import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const Twilio = require('twilio');

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

/** Twilio OTP provider — tries WhatsApp first, falls back to SMS */
class TwilioOtpProvider implements OtpProvider {
  private readonly logger = new Logger('TwilioOTP');
  private readonly client: any;
  private readonly smsFrom: string;
  private readonly whatsappFrom: string | undefined;

  constructor() {
    this.client = Twilio(
      process.env.TWILIO_ACCOUNT_SID!,
      process.env.TWILIO_AUTH_TOKEN!,
    );
    this.smsFrom = process.env.TWILIO_PHONE_NUMBER!;
    this.whatsappFrom = process.env.TWILIO_WHATSAPP_NUMBER;
  }

  async send(phone: string, code: string): Promise<boolean> {
    const body = `Your RideSure verification code is: ${code}`;

    // Try WhatsApp first if configured
    if (this.whatsappFrom) {
      try {
        await this.client.messages.create({
          body,
          from: `whatsapp:${this.whatsappFrom}`,
          to: `whatsapp:${phone}`,
        });
        this.logger.log(`WhatsApp OTP sent to ${phone}`);
        return true;
      } catch (err) {
        this.logger.warn(
          `WhatsApp failed for ${phone}, falling back to SMS: ${err.message}`,
        );
      }
    }

    // Fall back to SMS
    try {
      await this.client.messages.create({
        body,
        from: this.smsFrom,
        to: phone,
      });
      this.logger.log(`SMS OTP sent to ${phone}`);
      return true;
    } catch (err) {
      this.logger.error(`SMS failed for ${phone}: ${err.message}`);
      return false;
    }
  }
}

@Injectable()
export class OtpService {
  private readonly provider: OtpProvider;
  private readonly expiryMinutes: number;

  constructor(private prisma: PrismaService) {
    this.provider = process.env.TWILIO_ACCOUNT_SID
      ? new TwilioOtpProvider()
      : new MockOtpProvider();
    this.expiryMinutes = parseInt(process.env.OTP_EXPIRY_MINUTES || '5', 10);
  }

  async generateAndSend(phone: string): Promise<{ sent: boolean }> {
    const code = process.env.NODE_ENV === 'production'
      ? Math.floor(100000 + Math.random() * 900000).toString()
      : '123456';
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
