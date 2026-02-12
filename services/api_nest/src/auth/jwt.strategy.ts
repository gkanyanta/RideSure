import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../prisma.service';

export interface JwtPayload {
  sub: string;
  role: 'PASSENGER' | 'RIDER' | 'ADMIN';
  phone?: string;
  email?: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET || 'dev-jwt-secret',
    });
  }

  async validate(payload: JwtPayload) {
    if (payload.role === 'ADMIN') {
      const admin = await this.prisma.adminUser.findUnique({
        where: { id: payload.sub },
      });
      if (!admin || !admin.isActive) throw new UnauthorizedException();
      return { id: admin.id, email: admin.email, name: admin.name, role: 'ADMIN' };
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: { rider: true },
    });
    if (!user || !user.isActive) throw new UnauthorizedException();

    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      role: user.role,
      riderId: user.rider?.id,
    };
  }
}
