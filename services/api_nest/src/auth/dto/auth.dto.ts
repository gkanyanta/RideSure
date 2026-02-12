import { ApiProperty } from '@nestjs/swagger';
import {
  IsString,
  IsNotEmpty,
  IsEnum,
  IsOptional,
  Matches,
} from 'class-validator';

export class RequestOtpDto {
  @ApiProperty({ example: '+260971000001' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^\+260\d{9}$/, { message: 'Phone must be Zambian format: +260XXXXXXXXX' })
  phone: string;
}

export class VerifyOtpDto {
  @ApiProperty({ example: '+260971000001' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @IsNotEmpty()
  code: string;

  @ApiProperty({ enum: ['PASSENGER', 'RIDER'], example: 'PASSENGER' })
  @IsEnum(['PASSENGER', 'RIDER'])
  role: 'PASSENGER' | 'RIDER';

  @ApiProperty({ required: false, example: 'John Banda' })
  @IsOptional()
  @IsString()
  name?: string;
}

export class AdminLoginDto {
  @ApiProperty({ example: 'admin@ridesure.zm' })
  @IsString()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ example: 'admin123' })
  @IsString()
  @IsNotEmpty()
  password: string;
}

export class AuthResponse {
  @ApiProperty()
  accessToken: string;

  @ApiProperty()
  user: any;
}
