import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v4 as uuidv4 } from 'uuid';
import * as path from 'path';
import * as fs from 'fs';
import * as fsPromises from 'fs/promises';

@Injectable()
export class UploadsService {
  private readonly localUploadPath: string;
  private readonly serverBaseUrl: string;

  constructor(private configService: ConfigService) {
    this.serverBaseUrl =
      this.configService.get<string>('SERVER_BASE_URL') ||
      `http://localhost:${this.configService.get('PORT') || 3003}`;
    this.localUploadPath = path.join(process.cwd(), 'uploads');

    // Local storage only (no external providers).
    if (!fs.existsSync(this.localUploadPath)) {
      fs.mkdirSync(this.localUploadPath, { recursive: true });
    }
    console.log('📁 Upload mode: LOCAL STORAGE');
    console.log(`   Files will be saved to: ${this.localUploadPath}`);
  }

  async uploadFile(
    file: Express.Multer.File,
    folder: string,
    allowedMimeTypes: string[],
    maxSizeInBytes: number,
  ): Promise<{ url: string; key: string }> {
    // Validate file type
    if (!allowedMimeTypes.includes(file.mimetype)) {
      throw new BadRequestException(
        `Invalid file type. Allowed types: ${allowedMimeTypes.join(', ')}`,
      );
    }

    // Validate file size
    if (file.size > maxSizeInBytes) {
      const maxSizeMB = maxSizeInBytes / (1024 * 1024);
      throw new BadRequestException(
        `File size exceeds maximum allowed size of ${maxSizeMB}MB`,
      );
    }

    // Generate unique filename
    const fileExtension = path.extname(file.originalname);
    const fileName = `${uuidv4()}${fileExtension}`;
    const key = `${folder}/${fileName}`;

    return this.uploadToLocal(file, folder, fileName, key);
  }

  private async uploadToLocal(
    file: Express.Multer.File,
    folder: string,
    fileName: string,
    key: string,
  ): Promise<{ url: string; key: string }> {
    try {
      if (!file.buffer) {
        throw new Error(
          'File buffer is empty — Multer must use memory storage for local uploads',
        );
      }

      const folderPath = path.join(this.localUploadPath, folder);
      if (!fs.existsSync(folderPath)) {
        fs.mkdirSync(folderPath, { recursive: true });
      }

      const filePath = path.join(folderPath, fileName);
      await fsPromises.writeFile(filePath, file.buffer);

      const url = `${this.serverBaseUrl}/uploads/${key}`;
      console.log(`✅ File saved locally: ${filePath}`);
      console.log(`   URL: ${url}`);

      return { url, key };
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      console.error('Local upload error:', error);
      throw new BadRequestException(`Failed to save file locally: ${reason}`);
    }
  }

  async deleteFile(key: string, userId: string): Promise<{ message: string }> {
    try {
      const filePath = path.join(this.localUploadPath, key);
      if (fs.existsSync(filePath)) {
        await fsPromises.unlink(filePath);
      }
      return { message: 'File deleted' };
    } catch (error) {
      throw new BadRequestException('Failed to delete file');
    }
  }

  validateFileType(mimetype: string, allowedTypes: string[]): boolean {
    return allowedTypes.includes(mimetype);
  }

  getFileUrl(key: string): string {
    return `${this.serverBaseUrl}/uploads/${key}`;
  }
}
