import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  IsDateString,
  IsEnum,
  IsBoolean,
} from 'class-validator';

export class UpdateRiderProfileDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  name?: string;
}

export class CreateVehicleDto {
  @ApiProperty({ example: 'Honda CG125' })
  @IsString()
  @IsNotEmpty()
  model: string;

  @ApiPropertyOptional({ example: 'Red' })
  @IsOptional()
  @IsString()
  color?: string;

  @ApiPropertyOptional({ example: 'Honda' })
  @IsOptional()
  @IsString()
  make?: string;

  @ApiProperty({ example: 'MUF 1234' })
  @IsString()
  @IsNotEmpty()
  plateNumber: string;
}

export class UploadInsuranceDto {
  @ApiProperty({ example: 'ZSIC Insurance' })
  @IsString()
  @IsNotEmpty()
  insurerName: string;

  @ApiProperty({ example: 'POL-2024-00123' })
  @IsString()
  @IsNotEmpty()
  policyNumber: string;

  @ApiProperty({ example: '2025-06-30' })
  @IsDateString()
  expiryDate: string;
}

export class UpdateLocationDto {
  @ApiProperty({ example: -12.5432 })
  @IsNumber()
  lat: number;

  @ApiProperty({ example: 28.2311 })
  @IsNumber()
  lng: number;
}

export class GoOnlineDto {
  @ApiProperty()
  @IsBoolean()
  online: boolean;
}

export class AdminReviewDto {
  @ApiProperty({ enum: ['APPROVED', 'REJECTED'] })
  @IsEnum(['APPROVED', 'REJECTED'])
  action: 'APPROVED' | 'REJECTED';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  reason?: string;
}
