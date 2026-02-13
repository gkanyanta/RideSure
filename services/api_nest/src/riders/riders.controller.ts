import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Body,
  Param,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Res,
  Query,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { Response } from 'express';
import { DocumentType, RiderStatus } from '@prisma/client';
import { RidersService } from './riders.service';
import {
  CreateVehicleDto,
  UpdateLocationDto,
  GoOnlineDto,
  UploadInsuranceDto,
  AdminReviewDto,
} from './dto/riders.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { PrismaService } from '../prisma.service';

@ApiTags('riders')
@ApiBearerAuth()
@Controller('riders')
export class RidersController {
  constructor(
    private ridersService: RidersService,
    private prisma: PrismaService,
  ) {}

  @Get('profile')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @ApiOperation({ summary: 'Get current rider profile' })
  async getProfile(@CurrentUser() user: any) {
    return this.ridersService.getProfile(user.riderId);
  }

  @Post('vehicle')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @ApiOperation({ summary: 'Create or update vehicle info' })
  async createVehicle(@CurrentUser() user: any, @Body() dto: CreateVehicleDto) {
    return this.ridersService.createVehicle(user.riderId, dto);
  }

  @Post('documents/:type')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  @ApiOperation({ summary: 'Upload a document (SELFIE, RIDER_LICENCE, INSURANCE_CERTIFICATE, BIKE_FRONT, BIKE_BACK, BIKE_LEFT, BIKE_RIGHT)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        insurerName: { type: 'string' },
        policyNumber: { type: 'string' },
        expiryDate: { type: 'string' },
      },
    },
  })
  async uploadDocument(
    @CurrentUser() user: any,
    @Param('type') type: DocumentType,
    @UploadedFile() file: Express.Multer.File,
    @Body() body: any,
  ) {
    if (!file) throw new Error('File is required');

    const validTypes: DocumentType[] = [
      'SELFIE', 'RIDER_LICENCE', 'INSURANCE_CERTIFICATE',
      'BIKE_FRONT', 'BIKE_BACK', 'BIKE_LEFT', 'BIKE_RIGHT',
    ];
    if (!validTypes.includes(type)) throw new Error(`Invalid document type. Must be one of: ${validTypes.join(', ')}`);

    let insuranceData;
    if (type === 'INSURANCE_CERTIFICATE') {
      insuranceData = {
        insurerName: body.insurerName,
        policyNumber: body.policyNumber,
        expiryDate: body.expiryDate,
      };
    }

    return this.ridersService.uploadDocument(user.riderId, type, file, insuranceData);
  }

  @Get('documents/:docId/file')
  @Public()
  @ApiOperation({ summary: 'Download a document file (token via query param or header)' })
  async getDocumentFile(
    @Param('docId') docId: string,
    @Query('token') token: string,
    @Res() res: Response,
  ) {
    // Validate token from query param if no auth header was provided
    // (allows <img src="...?token=xxx"> to work in browser)
    if (token) {
      try {
        const jwt = require('jsonwebtoken');
        const payload = jwt.verify(token, process.env.JWT_SECRET || 'dev-jwt-secret');
        if (payload.role !== 'ADMIN' && payload.role !== 'RIDER') {
          return res.status(403).json({ message: 'Forbidden' });
        }
      } catch {
        return res.status(401).json({ message: 'Invalid token' });
      }
    }

    const doc = await this.prisma.riderDocument.findUnique({
      where: { id: docId },
    });
    if (!doc) return res.status(404).json({ message: 'Document not found' });
    if (!doc.fileData) return res.status(404).json({ message: 'File not found' });

    res.setHeader('Content-Type', doc.mimeType);
    res.setHeader('Content-Disposition', `inline; filename="${doc.originalName}"`);
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.send(doc.fileData);
  }

  @Put('location')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @ApiOperation({ summary: 'Update rider location' })
  async updateLocation(@CurrentUser() user: any, @Body() dto: UpdateLocationDto) {
    return this.ridersService.updateLocation(user.riderId, dto.lat, dto.lng);
  }

  @Put('online')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @ApiOperation({ summary: 'Go online or offline' })
  async setOnlineStatus(@CurrentUser() user: any, @Body() dto: GoOnlineDto) {
    return this.ridersService.setOnlineStatus(user.riderId, dto.online);
  }

  @Get('insurance-warning')
  @UseGuards(RolesGuard)
  @Roles('RIDER')
  @ApiOperation({ summary: 'Get insurance expiry warning' })
  async getInsuranceWarning(@CurrentUser() user: any) {
    return this.ridersService.getInsuranceWarning(user.riderId);
  }

  // --- Admin endpoints ---
  // NOTE: Static routes (pending, list) MUST be before :riderId wildcard

  @Get('admin/pending')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Get riders pending approval' })
  async getPendingApprovals() {
    return this.ridersService.getPendingApprovals();
  }

  @Get('admin/list')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'List all riders with optional status filter' })
  async listRiders(@Query('status') status?: RiderStatus) {
    return this.ridersService.listRiders(status);
  }

  @Get('admin/:riderId')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Get a single rider with full profile and documents' })
  async getRiderById(@Param('riderId') riderId: string) {
    return this.ridersService.getRiderById(riderId);
  }

  @Patch('admin/:riderId/review')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Approve or reject a rider' })
  async reviewRider(
    @Param('riderId') riderId: string,
    @CurrentUser() admin: any,
    @Body() dto: AdminReviewDto,
  ) {
    return this.ridersService.reviewRider(riderId, dto.action, admin.id, dto.reason);
  }
}
