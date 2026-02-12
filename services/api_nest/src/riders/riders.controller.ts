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
import { StorageService } from '../storage/storage.service';
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
import * as fs from 'fs';

@ApiTags('riders')
@ApiBearerAuth()
@Controller('riders')
export class RidersController {
  constructor(
    private ridersService: RidersService,
    private storage: StorageService,
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
  @ApiOperation({ summary: 'Upload a document (NRC, SELFIE, RIDER_LICENCE, INSURANCE_CERTIFICATE)' })
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

    const validTypes: DocumentType[] = ['NRC', 'SELFIE', 'RIDER_LICENCE', 'INSURANCE_CERTIFICATE'];
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
  @ApiOperation({ summary: 'Download a document file (auth required)' })
  async getDocumentFile(@Param('docId') docId: string, @Res() res: Response) {
    const doc = await this.ridersService['prisma'].riderDocument.findUnique({
      where: { id: docId },
    });
    if (!doc) return res.status(404).json({ message: 'Document not found' });

    const filePath = this.storage.getPath(doc.filePath);
    if (!fs.existsSync(filePath)) return res.status(404).json({ message: 'File not found' });

    res.setHeader('Content-Type', doc.mimeType);
    res.setHeader('Content-Disposition', `inline; filename="${doc.originalName}"`);
    fs.createReadStream(filePath).pipe(res);
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

  @Get('admin/pending')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Get riders pending approval' })
  async getPendingApprovals() {
    return this.ridersService.getPendingApprovals();
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

  @Get('admin/list')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'List all riders with optional status filter' })
  async listRiders(@Query('status') status?: RiderStatus) {
    return this.ridersService.listRiders(status);
  }
}
