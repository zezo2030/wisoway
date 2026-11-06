import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomUUID, timingSafeEqual } from 'crypto';
import * as fs from 'fs';
import * as fsPromises from 'fs/promises';
import * as path from 'path';

/** Outside `uploads/`, so the static file server can never reach it. */
export const PRIVATE_DOCUMENTS_DIR = path.join(
  process.cwd(),
  'private-documents',
);

/** Marks a stored value as a private file rather than a public URL. */
export const PRIVATE_DOCUMENT_PREFIX = 'private-document:';

export const CONTENT_TYPE_BY_EXTENSION: Record<string, string> = {
  jpg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  pdf: 'application/pdf',
};

const EXTENSION_BY_CONTENT_TYPE = Object.fromEntries(
  Object.entries(CONTENT_TYPE_BY_EXTENSION).map(([ext, type]) => [type, ext]),
);

const MAX_SIZE_BYTES = 10 * 1024 * 1024;
const NAME_PATTERN = /^[0-9a-f-]{36}\.(jpg|png|webp|pdf)$/;
const LINK_BUCKET_MS = 60 * 60 * 1000;

const SENSITIVE_VEHICLE_FIELDS = [
  'nationalIdImageUrl',
  'licenseImageUrl',
  'vehicleLicenseImageUrl',
  'insuranceImageUrl',
] as const;

type SensitiveVehicleFields = Partial<
  Record<(typeof SENSITIVE_VEHICLE_FIELDS)[number], string | null>
>;

/**
 * Driver identity documents and payment receipts. Files live outside the
 * public uploads folder and the database keeps a `private-document:` reference,
 * never a working link. `Image.network` and `<img>` send no auth header, so
 * owners and admins get a short-lived signed link instead: call
 * `presentVehicle` / `presentPayment` on every response that goes to one of
 * them, and on nothing else.
 */
@Injectable()
export class PrivateDocumentsService {
  private readonly serverBaseUrl: string;
  private readonly apiPrefix: string;

  constructor(private readonly configService: ConfigService) {
    this.serverBaseUrl =
      this.configService.get<string>('SERVER_BASE_URL') ||
      `http://localhost:${this.configService.get('PORT') || 3003}`;
    this.apiPrefix = this.configService.get<string>('API_PREFIX') || 'api/v1';
    fs.mkdirSync(PRIVATE_DOCUMENTS_DIR, { recursive: true });
  }

  async store(file: Express.Multer.File): Promise<{ url: string }> {
    const extension = EXTENSION_BY_CONTENT_TYPE[file.mimetype];
    if (!extension) {
      throw new BadRequestException(
        `Invalid file type. Allowed types: ${Object.keys(EXTENSION_BY_CONTENT_TYPE).join(', ')}`,
      );
    }
    if (file.size > MAX_SIZE_BYTES) {
      throw new BadRequestException('File size exceeds maximum allowed size');
    }

    const name = `${randomUUID()}.${extension}`;
    await fsPromises.writeFile(
      path.join(PRIVATE_DOCUMENTS_DIR, name),
      file.buffer,
    );
    return { url: `${PRIVATE_DOCUMENT_PREFIX}${name}` };
  }

  /** A copy of `vehicle` whose private documents are viewable for a while. */
  presentVehicle<T extends SensitiveVehicleFields>(vehicle: T): T;
  presentVehicle<T extends SensitiveVehicleFields>(vehicle: T | null): T | null;
  presentVehicle<T extends SensitiveVehicleFields>(
    vehicle: T | null,
  ): T | null {
    if (!vehicle) return null;
    const presented = { ...vehicle };
    for (const field of SENSITIVE_VEHICLE_FIELDS) {
      if (field in vehicle) {
        presented[field] = this.linkFor(vehicle[field]) as T[typeof field];
      }
    }
    return presented;
  }

  /** A copy of `payment` whose receipt is viewable for a while. */
  presentPayment<T extends object>(payment: T): T {
    const { proofImageUrl } = payment as { proofImageUrl?: string | null };
    if (proofImageUrl === undefined) return payment;
    return { ...payment, proofImageUrl: this.linkFor(proofImageUrl) };
  }

  /**
   * Resolves a signed link to the file on disk and its content type. Every
   * failure is the same 404, so a probe learns nothing about which part failed.
   */
  resolve(
    expires: string,
    signature: string,
    name: string,
  ): { filePath: string; contentType: string; expiresAt: number } {
    const expiresAt = Number(expires);
    const valid =
      NAME_PATTERN.test(name) &&
      Number.isSafeInteger(expiresAt) &&
      expiresAt > Date.now() &&
      this.matches(signature, this.sign(name, expiresAt));
    const filePath = path.join(PRIVATE_DOCUMENTS_DIR, name);
    if (!valid || !fs.existsSync(filePath)) {
      throw new NotFoundException('Document not found');
    }
    return {
      filePath,
      contentType: CONTENT_TYPE_BY_EXTENSION[path.extname(name).slice(1)],
      expiresAt,
    };
  }

  private linkFor(value: string | null | undefined): string | null {
    if (!value) return null;
    // Files not yet moved here keep their old public link.
    if (!value.startsWith(PRIVATE_DOCUMENT_PREFIX)) return value;

    const name = value.slice(PRIVATE_DOCUMENT_PREFIX.length);
    if (!NAME_PATTERN.test(name)) return null;

    // Valid for one to two hours. Rounding keeps the link stable between
    // refetches, so an open page doesn't reload the same image.
    const expiresAt =
      (Math.ceil(Date.now() / LINK_BUCKET_MS) + 1) * LINK_BUCKET_MS;
    const signature = this.sign(name, expiresAt);
    return `${this.serverBaseUrl}/${this.apiPrefix}/uploads/documents/${expiresAt}/${signature}/${name}`;
  }

  private sign(name: string, expiresAt: number): string {
    const secret = this.configService.get<string>('JWT_ACCESS_SECRET');
    if (!secret) throw new Error('JWT_ACCESS_SECRET is not configured');
    return createHmac('sha256', secret)
      .update(`${PRIVATE_DOCUMENT_PREFIX}${name}:${expiresAt}`)
      .digest('hex');
  }

  private matches(actual: string, expected: string): boolean {
    const a = Buffer.from(actual);
    const b = Buffer.from(expected);
    return a.length === b.length && timingSafeEqual(a, b);
  }
}
