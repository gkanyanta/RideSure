import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiConsumes } from '@nestjs/swagger';
import { TripStatus } from '@prisma/client';
import { TripsService } from './trips.service';
import { FareService } from './fare.service';
import {
  CreateTripDto,
  FareEstimateDto,
  CancelTripDto,
  RateTripDto,
} from './dto/trips.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';

@ApiTags('trips')
@ApiBearerAuth()
@Controller('trips')
export class TripsController {
  constructor(
    private tripsService: TripsService,
    private fareService: FareService,
  ) {}

  @Post('estimate')
  @UseGuards(RolesGuard)
  @Roles('PASSENGER')
  @ApiOperation({ summary: 'Get fare estimate' })
  async getFareEstimate(@Body() dto: FareEstimateDto) {
    return this.fareService.estimate(
      dto.pickupLat, dto.pickupLng,
      dto.destinationLat, dto.destinationLng,
      dto.town,
    );
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles('PASSENGER')
  @ApiOperation({ summary: 'Request a ride or delivery' })
  async createTrip(@CurrentUser() user: any, @Body() dto: CreateTripDto) {
    return this.tripsService.createTrip(user.id, dto);
  }

  @Get('my')
  @UseGuards(RolesGuard)
  @Roles('PASSENGER')
  @ApiOperation({ summary: 'Get passenger trip history' })
  async getMyTrips(@CurrentUser() user: any) {
    return this.tripsService.getPassengerTrips(user.id);
  }

  @Get('rider/my')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @ApiOperation({ summary: 'Get rider trip history' })
  async getRiderTrips(@CurrentUser() user: any) {
    return this.tripsService.getRiderTrips(user.riderId);
  }

  @Get('share/:shareCode')
  @Public()
  @ApiOperation({ summary: 'Get trip status by share code (public)' })
  async getTripByShareCode(@Param('shareCode') shareCode: string) {
    return this.tripsService.getTripByShareCode(shareCode);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get trip details' })
  async getTrip(@Param('id') id: string) {
    return this.tripsService.getTrip(id);
  }

  @Patch(':id/cancel')
  @ApiOperation({ summary: 'Cancel a trip' })
  async cancelTrip(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() dto: CancelTripDto,
  ) {
    return this.tripsService.transitionStatus(id, 'CANCELLED', user.id, {
      cancelReason: dto.reason,
    });
  }

  @Patch(':id/arrived')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @ApiOperation({ summary: 'Rider marks arrived at pickup' })
  async markArrived(@Param('id') id: string, @CurrentUser() user: any) {
    return this.tripsService.transitionStatus(id, 'ARRIVED', user.id);
  }

  @Patch(':id/start')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @ApiOperation({ summary: 'Rider starts the trip' })
  async startTrip(@Param('id') id: string, @CurrentUser() user: any) {
    return this.tripsService.transitionStatus(id, 'IN_PROGRESS', user.id);
  }

  @Patch(':id/complete')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @ApiOperation({ summary: 'Rider completes the trip' })
  async completeTrip(@Param('id') id: string, @CurrentUser() user: any) {
    return this.tripsService.transitionStatus(id, 'COMPLETED', user.id);
  }

  @Post(':id/rate')
  @UseGuards(RolesGuard)
  @Roles('PASSENGER')
  @ApiOperation({ summary: 'Rate a completed trip' })
  async rateTrip(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() dto: RateTripDto,
  ) {
    return this.tripsService.rateTrip(id, user.id, dto.score, dto.comment);
  }

  @Post(':id/delivery-photo/:phase')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @UseInterceptors(FileInterceptor('photo', { limits: { fileSize: 5 * 1024 * 1024 } }))
  @ApiOperation({ summary: 'Upload delivery proof photo (pickup or dropoff)' })
  @ApiConsumes('multipart/form-data')
  async uploadDeliveryPhoto(
    @Param('id') id: string,
    @Param('phase') phase: 'pickup' | 'dropoff',
    @CurrentUser() user: any,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.tripsService.uploadDeliveryPhoto(id, user.riderId, phase, file);
  }

  @Post(':id/sos')
  @ApiOperation({ summary: 'Trigger SOS for a trip' })
  async triggerSos(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body('description') description: string,
  ) {
    return this.tripsService.reportIncident(id, user.id, description || 'SOS triggered', 'CRITICAL');
  }

  // Admin endpoints
  @Get('admin/list')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'List all trips (admin)' })
  async listTrips(
    @Query('status') status?: TripStatus,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.tripsService.listTrips(
      status,
      parseInt(page || '1', 10),
      parseInt(limit || '20', 10),
    );
  }

  @Get('admin/incidents')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'List all incidents (admin)' })
  async listIncidents() {
    return this.tripsService.listIncidents();
  }
}
