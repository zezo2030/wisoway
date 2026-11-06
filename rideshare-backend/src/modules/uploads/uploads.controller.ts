import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Res,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  UnauthorizedException,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { ConfigService } from '@nestjs/config';
import * as jwt from 'jsonwebtoken';
import { DRIVER_REGISTRATION_TOKEN_PURPOSE } from '../auth/dto/register-driver.dto';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiConsumes,
} from '@nestjs/swagger';
import { UploadsService } from './uploads.service';
import { PrivateDocumentsService } from './private-documents.service';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';

@ApiTags('Uploads')
@Controller('uploads')
export class UploadsController {
  constructor(
    private readonly uploadsService: UploadsService,
    private readonly privateDocuments: PrivateDocumentsService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Upload an image during deferred driver registration, before any account
   * exists. Authorized by the short-lived registration token (from
   * /auth/driver/verify-phone) instead of a session access token.
   */
  @Post('registration')
  @Public()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload a driver-registration image (pre-account)' })
  @ApiResponse({ status: HttpStatus.OK, description: 'File uploaded' })
  @ApiResponse({
    status: HttpStatus.UNAUTHORIZED,
    description: 'Missing or invalid registration token',
  })
  async uploadRegistrationImage(
    @Body('registrationToken') registrationToken: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    this.assertValidRegistrationToken(registrationToken);

    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    return this.uploadsService.uploadFile(
      file,
      'driver-registration',
      ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
      10 * 1024 * 1024, // 10MB
    );
  }

  /** A driver document uploaded during registration, kept private. */
  @Post('registration/documents')
  @Public()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload a private driver document (pre-account)' })
  @ApiResponse({ status: HttpStatus.OK, description: 'File stored' })
  async uploadRegistrationDocument(
    @Body('registrationToken') registrationToken: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    this.assertValidRegistrationToken(registrationToken);
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    return this.privateDocuments.store(file);
  }

  /** A document or payment receipt from a signed-in account, kept private. */
  @Post('documents')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload a private document or payment receipt' })
  @ApiResponse({ status: HttpStatus.OK, description: 'File stored' })
  async uploadDocument(@UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    return this.privateDocuments.store(file);
  }

  /**
   * Opens a private document. Public because images load without an auth
   * header; the signature is what authorizes it, and only owners and admins
   * are ever handed one.
   */
  @Get('documents/:expires/:signature/:name')
  @Public()
  @ApiOperation({ summary: 'Open a private document by signed link' })
  @ApiResponse({ status: HttpStatus.OK, description: 'The document' })
  @ApiResponse({
    status: HttpStatus.NOT_FOUND,
    description: 'Unknown, tampered or expired link',
  })
  openDocument(
    @Param('expires') expires: string,
    @Param('signature') signature: string,
    @Param('name') name: string,
    @Res() res: Response,
  ) {
    const { filePath, contentType, expiresAt } = this.privateDocuments.resolve(
      expires,
      signature,
      name,
    );
    const maxAgeSeconds = Math.floor((expiresAt - Date.now()) / 1000);
    res.set({
      'Content-Type': contentType,
      'Content-Disposition': 'inline',
      'Cache-Control': `private, max-age=${maxAgeSeconds}`,
      // The dashboard may sit on another origin; helmet defaults to same-origin.
      'Cross-Origin-Resource-Policy': 'cross-origin',
      'Referrer-Policy': 'no-referrer',
    });
    res.sendFile(filePath);
  }

  private assertValidRegistrationToken(token: string): void {
    if (!token) {
      throw new UnauthorizedException('Registration token is required');
    }
    const secret = this.configService.get<string>('JWT_ACCESS_SECRET');
    if (!secret) {
      throw new UnauthorizedException('Server auth is not configured');
    }
    let decoded: jwt.JwtPayload | string;
    try {
      decoded = jwt.verify(token, secret);
    } catch {
      throw new UnauthorizedException(
        'Registration session expired. Please verify your phone again.',
      );
    }
    if (
      typeof decoded !== 'object' ||
      decoded.purpose !== DRIVER_REGISTRATION_TOKEN_PURPOSE
    ) {
      throw new UnauthorizedException('Invalid registration token');
    }
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload any file (general endpoint)' })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'File uploaded successfully',
  })
  async uploadGeneral(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    return this.uploadsService.uploadFile(
      file,
      'general',
      ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
      10 * 1024 * 1024, // 10MB
    );
  }

  @Post('profile-image')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload profile image' })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'File uploaded successfully',
  })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'Invalid file type or file too large',
  })
  async uploadProfileImage(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    return this.uploadsService.uploadFile(
      file,
      'profile-images',
      ['image/jpeg', 'image/png', 'image/webp'],
      5 * 1024 * 1024, // 5MB
    );
  }

  @Post('license')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload driver license' })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'File uploaded successfully',
  })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'Invalid file type or file too large',
  })
  @ApiResponse({
    status: HttpStatus.FORBIDDEN,
    description: 'User is not a driver',
  })
  async uploadLicense(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    return this.uploadsService.uploadFile(
      file,
      'licenses',
      ['image/jpeg', 'image/png', 'application/pdf'],
      10 * 1024 * 1024, // 10MB
    );
  }

  @Post('vehicle-license')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload vehicle license' })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'File uploaded successfully',
  })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'Invalid file type or file too large',
  })
  @ApiResponse({
    status: HttpStatus.FORBIDDEN,
    description: 'User is not a driver',
  })
  async uploadVehicleLicense(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    return this.uploadsService.uploadFile(
      file,
      'vehicle-licenses',
      ['image/jpeg', 'image/png', 'application/pdf'],
      10 * 1024 * 1024, // 10MB
    );
  }

  @Post('car-image')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.DRIVER)
  @ApiBearerAuth()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload car image' })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'File uploaded successfully',
  })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'Invalid file type or file too large',
  })
  @ApiResponse({
    status: HttpStatus.FORBIDDEN,
    description: 'User is not a driver',
  })
  async uploadCarImage(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    return this.uploadsService.uploadFile(
      file,
      'car-images',
      ['image/jpeg', 'image/png', 'image/webp'],
      10 * 1024 * 1024, // 10MB
    );
  }

  @Post('payment-proof')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload payment proof' })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'File uploaded successfully',
  })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'Invalid file type or file too large',
  })
  async uploadPaymentProof(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    return this.uploadsService.uploadFile(
      file,
      'payment-proofs',
      ['image/jpeg', 'image/png'],
      5 * 1024 * 1024, // 5MB
    );
  }

  @Delete(':key')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete file by key' })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'File deleted successfully',
  })
  @ApiResponse({ status: HttpStatus.FORBIDDEN, description: 'Not file owner' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'File not found' })
  async deleteFile(
    @CurrentUser('id') userId: string,
    @Param('key') key: string,
  ) {
    return this.uploadsService.deleteFile(key, userId);
  }
}
