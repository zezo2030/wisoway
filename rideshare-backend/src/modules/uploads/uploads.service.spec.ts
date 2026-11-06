import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as fs from 'fs';
import * as path from 'path';
import { UploadsService } from './uploads.service';

describe('UploadsService.deleteFile', () => {
  const service = new UploadsService({
    get: () => undefined,
  } as unknown as ConfigService);

  it('refuses a key that escapes the uploads folder', async () => {
    await expect(
      service.deleteFile('../package.json', 'admin'),
    ).rejects.toThrow(BadRequestException);
    expect(fs.existsSync(path.join(process.cwd(), 'package.json'))).toBe(true);
  });

  it('deletes a file inside the uploads folder', async () => {
    const folder = path.join(process.cwd(), 'uploads', 'spec');
    const file = path.join(folder, 'delete-me.txt');
    fs.mkdirSync(folder, { recursive: true });
    fs.writeFileSync(file, 'x');

    await service.deleteFile('spec/delete-me.txt', 'admin');

    expect(fs.existsSync(file)).toBe(false);
    fs.rmSync(folder, { recursive: true, force: true });
  });
});
