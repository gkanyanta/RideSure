import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma.service';
import { OtpService } from './otp.service';
import { JwtPayload } from './jwt.strategy';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private otpService: OtpService,
  ) {}

  async requestOtp(phone: string) {
    return this.otpService.generateAndSend(phone);
  }

  async verifyOtp(phone: string, code: string, role: 'PASSENGER' | 'RIDER', name?: string) {
    const valid = await this.otpService.verify(phone, code);
    if (!valid) throw new UnauthorizedException('Invalid or expired OTP');

    let user = await this.prisma.user.findUnique({
      where: { phone },
      include: { rider: true },
    });

    if (!user) {
      user = await this.prisma.user.create({
        data: { phone, name: name || null, role },
        include: { rider: true },
      });

      if (role === 'RIDER') {
        const rider = await this.prisma.rider.create({
          data: { userId: user.id, status: 'PENDING_DOCUMENTS' },
        });
        (user as any).rider = rider;
      }
    } else if (user.role !== role) {
      throw new BadRequestException(
        `Phone already registered as ${user.role}`,
      );
    }

    const payload: JwtPayload = { sub: user.id, role: user.role, phone: user.phone };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        role: user.role,
        riderId: user.rider?.id,
        riderStatus: user.rider?.status,
      },
    };
  }

  async adminLogin(email: string, password: string) {
    const admin = await this.prisma.adminUser.findUnique({ where: { email } });
    if (!admin) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(password, admin.password);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    const payload: JwtPayload = { sub: admin.id, role: 'ADMIN', email: admin.email };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      user: { id: admin.id, email: admin.email, name: admin.name, role: 'ADMIN' },
    };
  }
}
