import { NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as fs from 'fs';
import * as path from 'path';
import {
  PRIVATE_DOCUMENTS_DIR,
  PrivateDocumentsService,
} from './private-documents.service';

describe('PrivateDocumentsService', () => {
  const config = {
    get: (key: string) =>
      ({
        JWT_ACCESS_SECRET: 'test-secret',
        SERVER_BASE_URL: 'https://api.test',
      })[key],
  } as unknown as ConfigService;
  let service: PrivateDocumentsService;
  let stored: string;

  const upload = (mimetype: string, originalname = 'photo.jpg') =>
    service.store({
      mimetype,
      originalname,
      size: 3,
      buffer: Buffer.from('abc'),
    } as Express.Multer.File);

  const remove = (reference: string) =>
    fs.rmSync(path.join(PRIVATE_DOCUMENTS_DIR, reference.split(':')[1]), {
      force: true,
    });

  const linkParts = (link: string) => {
    const [expires, signature, name] = link.split('/').slice(-3);
    return { expires, signature, name };
  };

  const signedParts = () =>
    linkParts(
      service.presentVehicle({ nationalIdImageUrl: stored })
        .nationalIdImageUrl as string,
    );

  beforeEach(async () => {
    service = new PrivateDocumentsService(config);
    stored = (await upload('image/jpeg')).url;
  });

  afterEach(() => {
    remove(stored);
    jest.useRealTimers();
  });

  it('stores a reference, not a working link', () => {
    expect(stored).toMatch(/^private-document:[0-9a-f-]{36}\.jpg$/);
  });

  it('takes the extension from the content type, not the file name', async () => {
    const { url } = await upload('image/png', 'evil.html');
    expect(url).toMatch(/\.png$/);
    remove(url);
  });

  it('refuses file types that are not documents', async () => {
    await expect(upload('text/html')).rejects.toThrow('Invalid file type');
  });

  it('signs private documents and leaves the rest of the vehicle alone', () => {
    const vehicle = {
      nationalIdImageUrl: stored,
      licenseImageUrl: null,
      insuranceImageUrl: 'https://old/uploads/general/a.jpg',
      carImageUrl: 'https://old/uploads/general/car.jpg',
    };

    const presented = service.presentVehicle(vehicle);

    expect(presented.nationalIdImageUrl).toContain(
      'https://api.test/api/v1/uploads/documents/',
    );
    // Clients decide between image and PDF from the end of the URL.
    expect(presented.nationalIdImageUrl).toMatch(/\.jpg$/);
    expect(presented.licenseImageUrl).toBeNull();
    expect(presented.insuranceImageUrl).toBe(vehicle.insuranceImageUrl);
    expect(presented.carImageUrl).toBe(vehicle.carImageUrl);
    // The caller's entity must stay safe to save.
    expect(vehicle.nationalIdImageUrl).toBe(stored);
  });

  it('signs a payment receipt without touching the stored payment', () => {
    const payment = { id: 'p1', proofImageUrl: stored };

    const presented = service.presentPayment(payment);

    expect(presented.proofImageUrl).toContain('/uploads/documents/');
    expect(presented.id).toBe('p1');
    expect(payment.proofImageUrl).toBe(stored);
  });

  it('leaves a payment without a receipt alone', () => {
    expect(service.presentPayment({ id: 'p1' })).toEqual({ id: 'p1' });
    expect(
      service.presentPayment({ id: 'p1', proofImageUrl: null }).proofImageUrl,
    ).toBeNull();
  });

  it('never signs a tampered reference', () => {
    const presented = service.presentVehicle({
      nationalIdImageUrl: 'private-document:../../.env',
    });
    expect(presented.nationalIdImageUrl).toBeNull();
  });

  it('opens a valid link', () => {
    const { expires, signature, name } = signedParts();

    const resolved = service.resolve(expires, signature, name);

    expect(resolved.contentType).toBe('image/jpeg');
    expect(fs.readFileSync(resolved.filePath, 'utf8')).toBe('abc');
  });

  it('rejects a changed signature', () => {
    const { expires, name } = signedParts();
    expect(() => service.resolve(expires, 'f'.repeat(64), name)).toThrow(
      NotFoundException,
    );
  });

  it('rejects a stretched expiry', () => {
    const { expires, signature, name } = signedParts();
    expect(() =>
      service.resolve(`${Number(expires) + 1}`, signature, name),
    ).toThrow(NotFoundException);
  });

  it('rejects a path traversal', () => {
    const { expires, signature } = signedParts();
    expect(() => service.resolve(expires, signature, '../../.env')).toThrow(
      NotFoundException,
    );
  });

  it('rejects a link past its expiry', () => {
    const { expires, signature, name } = signedParts();

    jest.useFakeTimers({ now: Number(expires) + 1 });

    expect(() => service.resolve(expires, signature, name)).toThrow(
      NotFoundException,
    );
  });

  it('rejects a link signed with another secret', () => {
    const other = new PrivateDocumentsService({
      get: (key: string) =>
        key === 'JWT_ACCESS_SECRET' ? 'other-secret' : undefined,
    } as unknown as ConfigService);
    const { expires, signature, name } = linkParts(
      other.presentVehicle({ nationalIdImageUrl: stored })
        .nationalIdImageUrl as string,
    );

    expect(() => service.resolve(expires, signature, name)).toThrow(
      NotFoundException,
    );
  });
});
