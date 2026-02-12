import { Controller, Post, Body } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import {
  RequestOtpDto,
  VerifyOtpDto,
  AdminLoginDto,
  AuthResponse,
} from './dto/auth.dto';
import { Public } from '../common/decorators/public.decorator';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Public()
  @Post('otp/request')
  @ApiOperation({ summary: 'Request OTP code sent to phone' })
  @ApiResponse({ status: 201, description: 'OTP sent' })
  async requestOtp(@Body() dto: RequestOtpDto) {
    return this.authService.requestOtp(dto.phone);
  }

  @Public()
  @Post('otp/verify')
  @ApiOperation({ summary: 'Verify OTP and get JWT token' })
  @ApiResponse({ status: 201, type: AuthResponse })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto.phone, dto.code, dto.role, dto.name);
  }

  @Public()
  @Post('admin/login')
  @ApiOperation({ summary: 'Admin login with email/password' })
  @ApiResponse({ status: 201, type: AuthResponse })
  async adminLogin(@Body() dto: AdminLoginDto) {
    return this.authService.adminLogin(dto.email, dto.password);
  }
}
