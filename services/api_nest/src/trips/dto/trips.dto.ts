import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  IsEnum,
} from 'class-validator';

export class CreateTripDto {
  @ApiProperty({ enum: ['RIDE', 'DELIVERY'] })
  @IsEnum(['RIDE', 'DELIVERY'])
  type: 'RIDE' | 'DELIVERY';

  @ApiProperty({ example: -12.5432 })
  @IsNumber()
  pickupLat: number;

  @ApiProperty({ example: 28.2311 })
  @IsNumber()
  pickupLng: number;

  @ApiProperty({ example: 'Kantanshi Market' })
  @IsString()
  @IsNotEmpty()
  pickupAddress: string;

  @ApiPropertyOptional({ example: 'Near the blue gate' })
  @IsOptional()
  @IsString()
  pickupLandmark?: string;

  @ApiProperty({ example: -12.5500 })
  @IsNumber()
  destinationLat: number;

  @ApiProperty({ example: 28.2400 })
  @IsNumber()
  destinationLng: number;

  @ApiProperty({ example: 'Mufulira Civic Centre' })
  @IsString()
  @IsNotEmpty()
  destinationAddress: string;

  @ApiPropertyOptional({ example: 'Opposite the post office' })
  @IsOptional()
  @IsString()
  destinationLandmark?: string;

  // Delivery-specific
  @ApiPropertyOptional({ example: 'Small parcel' })
  @IsOptional()
  @IsString()
  packageType?: string;

  @ApiPropertyOptional({ example: 'Handle with care, contains documents' })
  @IsOptional()
  @IsString()
  packageNotes?: string;
}

export class FareEstimateDto {
  @ApiProperty({ example: -12.5432 })
  @IsNumber()
  pickupLat: number;

  @ApiProperty({ example: 28.2311 })
  @IsNumber()
  pickupLng: number;

  @ApiProperty({ example: -12.5500 })
  @IsNumber()
  destinationLat: number;

  @ApiProperty({ example: 28.2400 })
  @IsNumber()
  destinationLng: number;

  @ApiPropertyOptional({ example: 'Mufulira' })
  @IsOptional()
  @IsString()
  town?: string;
}

export class CancelTripDto {
  @ApiProperty({ example: 'Changed my mind' })
  @IsString()
  @IsNotEmpty()
  reason: string;
}

export class RateTripDto {
  @ApiProperty({ example: 5, minimum: 1, maximum: 5 })
  @IsNumber()
  score: number;

  @ApiPropertyOptional({ example: 'Great ride!' })
  @IsOptional()
  @IsString()
  comment?: string;
}
